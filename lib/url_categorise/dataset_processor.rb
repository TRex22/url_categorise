require 'httparty'
require 'csv'
require 'digest'
require 'fileutils'
require 'net/http'
require 'timeout'
require 'zip'
require 'json'

module UrlCategorise
  class DatasetProcessor
    include HTTParty

    KAGGLE_BASE_URL = 'https://www.kaggle.com/api/v1'
    DEFAULT_DOWNLOAD_PATH = './downloads'
    DEFAULT_CACHE_PATH = './cache'
    DEFAULT_TIMEOUT = 30
    DEFAULT_CREDENTIALS_FILE = File.expand_path('~/.kaggle/kaggle.json')

    attr_reader :username, :api_key, :download_path, :cache_path, :timeout, :kaggle_enabled

    def initialize(username: nil, api_key: nil, credentials_file: nil, download_path: nil, cache_path: nil,
                   timeout: nil, enable_kaggle: true)
      @kaggle_enabled = enable_kaggle

      if @kaggle_enabled
        load_credentials(username, api_key, credentials_file)
        warn_if_kaggle_credentials_missing
      else
        @username = nil
        @api_key = nil
      end

      @download_path = download_path || DEFAULT_DOWNLOAD_PATH
      @cache_path = cache_path || DEFAULT_CACHE_PATH
      @timeout = timeout || DEFAULT_TIMEOUT

      ensure_directories_exist
      setup_httparty_options if kaggle_credentials_available?
    end

    def process_kaggle_dataset(dataset_owner, dataset_name, options = {})
      unless @kaggle_enabled
        raise Error, 'Kaggle functionality is disabled. Set enable_kaggle: true to use Kaggle datasets.'
      end

      dataset_path = "#{dataset_owner}/#{dataset_name}"

      # Check cache first if requested - no credentials needed for cached data
      if options[:use_cache]
        cached_data = load_from_cache(generate_cache_key(dataset_path, :kaggle))
        return cached_data if cached_data
      end

      # Check if we already have extracted files - no credentials needed
      extracted_dir = get_extracted_dir(dataset_path)
      if options[:use_cache] && Dir.exist?(extracted_dir) && !Dir.empty?(extracted_dir)
        return handle_existing_dataset(extracted_dir, options)
      end

      # If credentials not available, return nil gracefully for cache mode
      unless kaggle_credentials_available?
        if options[:use_cache]
          puts "Warning: Kaggle dataset '#{dataset_path}' not cached and no credentials available" if ENV['DEBUG']
          return nil
        else
          raise Error, 'Kaggle credentials required for downloading new datasets. ' \
                       'Set KAGGLE_USERNAME/KAGGLE_KEY environment variables, provide credentials explicitly, ' \
                       'or place kaggle.json file in ~/.kaggle/ directory.'
        end
      end

      # Download from Kaggle API
      response = authenticated_request(:get, "/datasets/download/#{dataset_path}")

      raise Error, "Failed to download Kaggle dataset: #{response.message}" unless response.success?

      # Process the downloaded data
      result = process_dataset_response(response.body, dataset_path, :kaggle, options)

      # Cache if requested
      cache_processed_data(generate_cache_key(dataset_path, :kaggle), result) if options[:use_cache] && result

      result
    end

    def process_csv_dataset(url, options = {})
      cache_key = generate_cache_key(url, :csv)

      # Check cache first if requested
      if options[:use_cache]
        cached_data = load_from_cache(cache_key)
        return cached_data if cached_data
      end

      # Download CSV directly
      response = HTTParty.get(url, timeout: @timeout, follow_redirects: true)

      raise Error, "Failed to download CSV dataset: #{response.message}" unless response.success?

      # Parse CSV content
      result = parse_csv_content(response.body, options)

      # Cache if requested
      cache_processed_data(cache_key, result) if options[:use_cache] && result

      result
    end

    def generate_dataset_hash(data)
      content = case data
                when Hash
                  data.to_json
                when Array
                  data.to_json
                when String
                  data
                else
                  data.to_s
                end

      Digest::SHA256.hexdigest(content)
    end

    def integrate_dataset_into_categorization(dataset, category_mappings = {})
      categorized_data = {}

      case dataset
      when Hash
        # Single dataset with multiple files
        dataset.each do |file_name, data|
          process_dataset_file(data, file_name, category_mappings, categorized_data)
        end
      when Array
        # Single file dataset
        process_dataset_file(dataset, 'default', category_mappings, categorized_data)
      else
        raise Error, "Unsupported dataset format: #{dataset.class}"
      end

      # Add metadata
      categorized_data[:_metadata] = {
        processed_at: Time.now,
        data_hash: generate_dataset_hash(dataset),
        total_entries: count_total_entries(dataset)
      }

      categorized_data
    end

    private

    def kaggle_credentials_available?
      valid_credential?(@username) && valid_credential?(@api_key)
    end

    def warn_if_kaggle_credentials_missing
      return if kaggle_credentials_available?

      warn 'Warning: Kaggle credentials not found. Kaggle datasets will only work if they are already cached. ' \
           'To download new Kaggle datasets, set KAGGLE_USERNAME/KAGGLE_KEY environment variables, ' \
           'provide credentials explicitly, or place kaggle.json file in ~/.kaggle/ directory.'
    end

    def valid_credential?(credential)
      credential && !credential.to_s.strip.empty?
    end

    def load_credentials(username, api_key, credentials_file)
      # Try provided credentials file first
      if credentials_file && File.exist?(credentials_file)
        credentials = load_credentials_from_file(credentials_file)
        @username = username || credentials['username']
        @api_key = api_key || credentials['key']
      # Try default kaggle.json file if no explicit credentials
      elsif !username && !api_key && File.exist?(DEFAULT_CREDENTIALS_FILE)
        credentials = load_credentials_from_file(DEFAULT_CREDENTIALS_FILE)
        @username = credentials['username']
        @api_key = credentials['key']
      else
        # Fall back to environment variables
        @username = username || ENV['KAGGLE_USERNAME']
        @api_key = api_key || ENV['KAGGLE_KEY']
      end
    end

    def load_credentials_from_file(file_path)
      content = File.read(file_path)
      JSON.parse(content)
    rescue JSON::ParserError => e
      raise Error, "Invalid credentials file format: #{e.message}"
    rescue StandardError => e
      raise Error, "Failed to read credentials file: #{e.message}"
    end

    def ensure_directories_exist
      FileUtils.mkdir_p(@download_path) unless Dir.exist?(@download_path)
      FileUtils.mkdir_p(@cache_path) unless Dir.exist?(@cache_path)
    end

    def setup_httparty_options
      self.class.base_uri KAGGLE_BASE_URL
      self.class.default_options.merge!({
                                          headers: {
                                            'User-Agent' => 'url_categorise-ruby-client'
                                          },
                                          timeout: @timeout,
                                          basic_auth: {
                                            username: @username,
                                            password: @api_key
                                          }
                                        })
    end

    def authenticated_request(method, endpoint, options = {})
      self.class.send(method, endpoint, options)
    rescue Timeout::Error, Net::ReadTimeout, Net::OpenTimeout
      raise Error, 'Request timed out'
    rescue StandardError => e
      raise Error, "Request failed: #{e.message}"
    end

    def process_dataset_response(content, dataset_path, source_type, options)
      if source_type == :kaggle
        # Kaggle returns ZIP files
        zip_file = save_zip_file(dataset_path, content)
        extracted_dir = get_extracted_dir(dataset_path)
        extract_zip_file(zip_file, extracted_dir)
        File.delete(zip_file) if File.exist?(zip_file)
        handle_extracted_dataset(extracted_dir, options)
      else
        # Direct content processing
        parse_csv_content(content, options)
      end
    end

    def get_extracted_dir(dataset_path)
      dir_name = dataset_path.gsub('/', '_').gsub(/[^a-zA-Z0-9_-]/, '_')
      File.join(@download_path, dir_name)
    end

    def save_zip_file(dataset_path, content)
      filename = "#{dataset_path.gsub('/', '_')}_#{Time.now.to_i}.zip"
      file_path = File.join(@download_path, filename)

      File.open(file_path, 'wb') do |file|
        file.write(content)
      end

      file_path
    end

    def extract_zip_file(zip_file_path, extract_to_dir)
      FileUtils.mkdir_p(extract_to_dir)

      Zip::File.open(zip_file_path) do |zip_file|
        zip_file.each do |entry|
          extract_path = File.join(extract_to_dir, entry.name)

          if entry.directory?
            FileUtils.mkdir_p(extract_path)
          else
            parent_dir = File.dirname(extract_path)
            FileUtils.mkdir_p(parent_dir) unless Dir.exist?(parent_dir)

            File.open(extract_path, 'wb') do |f|
              f.write entry.get_input_stream.read
            end
          end
        end
      end
    rescue Zip::Error => e
      raise Error, "Failed to extract zip file: #{e.message}"
    end

    def handle_existing_dataset(extracted_dir, _options)
      csv_files = find_csv_files(extracted_dir)
      return parse_csv_files_to_hash(csv_files) unless csv_files.empty?

      extracted_dir
    end

    def handle_extracted_dataset(extracted_dir, _options)
      csv_files = find_csv_files(extracted_dir)
      return parse_csv_files_to_hash(csv_files) unless csv_files.empty?

      extracted_dir
    end

    def find_csv_files(directory)
      Dir.glob(File.join(directory, '**', '*.csv'))
    end

    def parse_csv_files_to_hash(csv_files)
      result = {}

      csv_files.each do |csv_file|
        file_name = File.basename(csv_file, '.csv')
        result[file_name] = parse_csv_file(csv_file)
      end

      # If there's only one CSV file, return its data directly
      result.length == 1 ? result.values.first : result
    end

    def parse_csv_file(file_path)
      raise Error, "File does not exist: #{file_path}" unless File.exist?(file_path)

      data = []
      CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
        data << row.to_hash
      end

      data
    rescue CSV::MalformedCSVError => e
      raise Error, "Failed to parse CSV file: #{e.message}"
    end

    def parse_csv_content(content, _options = {})
      data = []
      CSV.parse(content, headers: true, liberal_parsing: true) do |row|
        data << row.to_hash
      end

      data
    rescue CSV::MalformedCSVError => e
      raise Error, "Failed to parse CSV content: #{e.message}"
    end

    def generate_cache_key(identifier, source_type)
      sanitized = identifier.gsub(/[^a-zA-Z0-9_-]/, '_')
      "#{source_type}_#{sanitized}_processed.json"
    end

    def load_from_cache(cache_key)
      cache_file_path = File.join(@cache_path, cache_key)
      return nil unless File.exist?(cache_file_path)

      content = File.read(cache_file_path)
      JSON.parse(content)
    rescue JSON::ParserError
      nil # Invalid cache, will re-process
    rescue StandardError
      nil # Cache read error, will re-process
    end

    def cache_processed_data(cache_key, data)
      cache_file_path = File.join(@cache_path, cache_key)
      File.write(cache_file_path, JSON.pretty_generate(data))
    rescue StandardError
      # Cache write failed, continue without caching
    end

    def process_dataset_file(data, file_name, category_mappings, categorized_data)
      return unless data.is_a?(Array) && !data.empty?

      # If explicit column mappings are provided, use them for all rows
      if category_mappings[:url_column] && category_mappings[:category_column]
        url_col = category_mappings[:url_column]
        category_col = category_mappings[:category_column]

        data.each do |row|
          url = row[url_col]&.strip
          next unless url && !url.empty?

          # Extract domain from URL
          domain = extract_domain(url)
          next unless domain

          # Determine category
          category = determine_category(row, category_col, category_mappings, file_name)

          # Add to categorized data
          categorized_data[category] ||= []
          categorized_data[category] << domain unless categorized_data[category].include?(domain)
        end
      else
        # Auto-detect columns for each row (handles mixed column structures)
        data.each do |row|
          url_columns = detect_url_columns(row)
          category_columns = detect_category_columns(row)

          # Use detected columns for this specific row
          url_col = url_columns.first
          category_col = category_columns.first

          next unless url_col # Must have URL column

          url = row[url_col]&.strip
          next unless url && !url.empty?

          # Extract domain from URL
          domain = extract_domain(url)
          next unless domain

          # Determine category
          category = determine_category(row, category_col, category_mappings, file_name)

          # Add to categorized data
          categorized_data[category] ||= []
          categorized_data[category] << domain unless categorized_data[category].include?(domain)
        end
      end
    end

    def detect_url_columns(sample_row)
      url_indicators = %w[url domain website site link address]
      sample_row.keys.select do |key|
        key_lower = key.to_s.downcase
        url_indicators.any? { |indicator| key_lower.include?(indicator) }
      end
    end

    def detect_category_columns(sample_row)
      category_indicators = %w[category class type classification label]
      sample_row.keys.select do |key|
        key_lower = key.to_s.downcase
        category_indicators.any? { |indicator| key_lower.include?(indicator) }
      end
    end

    def extract_domain(url)
      # Handle both full URLs and domain-only entries
      return nil if url.nil? || url.empty?

      # Add protocol if missing
      url = "http://#{url}" unless url.match?(%r{\A\w+://})

      uri = URI.parse(url)
      domain = uri.host&.downcase
      domain = domain.gsub(/\Awww\./, '') if domain # Remove www prefix
      domain
    rescue URI::InvalidURIError
      # If URI parsing fails, try to extract domain manually
      cleaned = url.gsub(%r{\A\w+://}, '').gsub(%r{/.*\z}, '').downcase
      cleaned = cleaned.gsub(/\Awww\./, '')
      cleaned.empty? ? nil : cleaned
    end

    def determine_category(row, category_col, category_mappings, file_name)
      # Use explicit category column if available
      if category_col && row[category_col]
        category = row[category_col].to_s.strip.downcase
        return map_category_name(category, category_mappings)
      end

      # Use file name as category if no category column
      map_category_name(file_name, category_mappings)
    end

    def map_category_name(original_name, category_mappings)
      # Use provided mapping or sanitize the name
      mapped = category_mappings[:category_map]&.[](original_name)
      return mapped if mapped

      # Sanitize and format category name
      sanitized = original_name.to_s.downcase
                               .gsub(/[^a-z0-9_]/, '_')
                               .gsub(/_+/, '_')
                               .gsub(/\A_|_\z/, '')

      sanitized.empty? ? 'dataset_category' : sanitized
    end

    def count_total_entries(dataset)
      case dataset
      when Hash
        dataset.values.map { |v| v.is_a?(Array) ? v.length : 1 }.sum
      when Array
        dataset.length
      else
        1
      end
    end
  end
end
