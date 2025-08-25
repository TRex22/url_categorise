require 'set'

module UrlCategorise
  class Client < ApiPattern::Client
    include ::UrlCategorise::Constants

    def self.compatible_api_version
      'v2'
    end

    def self.api_version
      'v2 2025-08-23'
    end

    attr_reader :host_urls, :hosts, :cache_dir, :force_download, :dns_servers, :metadata, :request_timeout,
                :dataset_processor, :dataset_categories

    def initialize(host_urls: DEFAULT_HOST_URLS, cache_dir: nil, force_download: false,
                   dns_servers: ['1.1.1.1', '1.0.0.1'], request_timeout: 10, dataset_config: {})
      @host_urls = host_urls
      @cache_dir = cache_dir
      @force_download = force_download
      @dns_servers = dns_servers
      @request_timeout = request_timeout
      @metadata = {}
      @dataset_categories = Set.new # Track which categories come from datasets

      # Initialize dataset processor if config provided
      @dataset_processor = initialize_dataset_processor(dataset_config) unless dataset_config.empty?

      @hosts = fetch_and_build_host_lists
    end

    def categorise(url)
      host = (URI.parse(url).host || url).downcase
      host = host.gsub('www.', '')

      @hosts.keys.select do |category|
        @hosts[category].any? do |blocked_host|
          host == blocked_host || host.end_with?(".#{blocked_host}")
        end
      end
    end

    def categorise_ip(ip_address)
      @hosts.keys.select do |category|
        @hosts[category].include?(ip_address)
      end
    end

    def resolve_and_categorise(domain)
      categories = categorise(domain)

      begin
        resolver = Resolv::DNS.new(nameserver: @dns_servers)
        ip_addresses = resolver.getaddresses(domain).map(&:to_s)

        ip_addresses.each do |ip|
          categories.concat(categorise_ip(ip))
        end
      rescue StandardError
        # DNS resolution failed, return domain categories only
      end

      categories.uniq
    end

    def count_of_hosts
      @hosts.keys.map do |category|
        @hosts[category].size
      end.sum
    end

    def count_of_categories
      @hosts.keys.size
    end

    def size_of_data
      hash_size_in_mb(@hosts)
    end

    def check_all_lists
      puts 'Checking all lists in constants...'

      unreachable_lists = {}
      missing_categories = []
      successful_lists = {}

      @host_urls.each do |category, urls|
        puts "\nChecking category: #{category}"

        if urls.empty?
          missing_categories << category
          puts '  ❌ No URLs defined for category'
          next
        end

        unreachable_lists[category] = []
        successful_lists[category] = []

        urls.each do |url|
          # Skip symbol references (combined categories)
          if url.is_a?(Symbol)
            puts "  ➡️  References other category: #{url}"
            next
          end

          unless url_valid?(url)
            unreachable_lists[category] << { url: url, error: 'Invalid URL format' }
            puts "  ❌ Invalid URL format: #{url}"
            next
          end

          print "  🔍 Testing #{url}... "

          begin
            response = HTTParty.head(url, timeout: @request_timeout, follow_redirects: true)

            case response.code
            when 200
              puts '✅ OK'
              successful_lists[category] << url
            when 301, 302, 307, 308
              puts "↗️  Redirect (#{response.code})"
              puts "      Redirects to: #{response.headers['location']}" if response.headers['location']
              successful_lists[category] << url
            when 404
              puts '❌ Not Found (404)'
              unreachable_lists[category] << { url: url, error: '404 Not Found' }
            when 403
              puts '❌ Forbidden (403)'
              unreachable_lists[category] << { url: url, error: '403 Forbidden' }
            when 500..599
              puts "❌ Server Error (#{response.code})"
              unreachable_lists[category] << { url: url, error: "Server Error #{response.code}" }
            else
              puts "⚠️  Unexpected response (#{response.code})"
              unreachable_lists[category] << { url: url, error: "HTTP #{response.code}" }
            end
          rescue Timeout::Error
            puts '❌ Timeout'
            unreachable_lists[category] << { url: url, error: 'Request timeout' }
          rescue SocketError => e
            puts '❌ DNS/Network Error'
            unreachable_lists[category] << { url: url, error: "DNS/Network: #{e.message}" }
          rescue HTTParty::Error, Net::HTTPError => e
            puts '❌ HTTP Error'
            unreachable_lists[category] << { url: url, error: "HTTP Error: #{e.message}" }
          rescue StandardError => e
            puts "❌ Error: #{e.class}"
            unreachable_lists[category] << { url: url, error: "#{e.class}: #{e.message}" }
          end

          # Small delay to be respectful to servers
          sleep(0.1)
        end

        # Remove empty arrays
        unreachable_lists.delete(category) if unreachable_lists[category].empty?
        successful_lists.delete(category) if successful_lists[category].empty?
      end

      # Generate summary report
      puts "\n" + '=' * 80
      puts 'LIST HEALTH REPORT'
      puts '=' * 80

      puts "\n📊 SUMMARY:"
      total_categories = @host_urls.keys.length
      categories_with_issues = unreachable_lists.keys.length + missing_categories.length
      categories_healthy = total_categories - categories_with_issues

      puts "  Total categories: #{total_categories}"
      puts "  Healthy categories: #{categories_healthy}"
      puts "  Categories with issues: #{categories_with_issues}"

      if missing_categories.any?
        puts "\n❌ CATEGORIES WITH NO URLS (#{missing_categories.length}):"
        missing_categories.each do |category|
          puts "  - #{category}"
        end
      end

      if unreachable_lists.any?
        puts "\n❌ UNREACHABLE LISTS:"
        unreachable_lists.each do |category, failed_urls|
          puts "\n  #{category.upcase} (#{failed_urls.length} failed):"
          failed_urls.each do |failure|
            puts "    ❌ #{failure[:url]}"
            puts "       Error: #{failure[:error]}"
          end
        end
      end

      puts "\n✅ WORKING CATEGORIES (#{successful_lists.keys.length}):"
      successful_lists.keys.sort.each do |category|
        url_count = successful_lists[category].length
        puts "  - #{category} (#{url_count} URL#{'s' if url_count != 1})"
      end

      puts "\n" + '=' * 80

      # Return structured data for programmatic use
      {
        summary: {
          total_categories: total_categories,
          healthy_categories: categories_healthy,
          categories_with_issues: categories_with_issues
        },
        missing_categories: missing_categories,
        unreachable_lists: unreachable_lists,
        successful_lists: successful_lists
      }
    end

    def load_kaggle_dataset(dataset_owner, dataset_name, options = {})
      raise Error, 'Dataset processor not configured' unless @dataset_processor

      default_options = { use_cache: true, integrate_data: true }
      merged_options = default_options.merge(options)

      dataset = @dataset_processor.process_kaggle_dataset(dataset_owner, dataset_name, merged_options)

      if merged_options[:integrate_data]
        integrate_dataset(dataset, merged_options[:category_mappings] || {})
      else
        dataset
      end
    end

    def load_csv_dataset(url, options = {})
      raise Error, 'Dataset processor not configured' unless @dataset_processor

      default_options = { use_cache: true, integrate_data: true }
      merged_options = default_options.merge(options)

      dataset = @dataset_processor.process_csv_dataset(url, merged_options)

      if merged_options[:integrate_data]
        integrate_dataset(dataset, merged_options[:category_mappings] || {})
      else
        dataset
      end
    end

    def dataset_metadata
      return {} unless @dataset_processor

      @dataset_metadata || {}
    end

    def reload_with_datasets
      # Store dataset categories before reload (only those that were added via integrate_dataset)
      dataset_category_data = {}
      if @hosts
        @dataset_categories.each do |category|
          dataset_category_data[category] = @hosts[category].dup if @hosts[category]
        end
      end

      @hosts = fetch_and_build_host_lists

      # Restore dataset categories
      dataset_category_data.each do |category, domains|
        @hosts[category] ||= []
        @hosts[category].concat(domains).uniq!
      end

      self
    end

    private

    def initialize_dataset_processor(config)
      processor_config = {
        download_path: config[:download_path] || @cache_dir&.+(File::SEPARATOR + 'downloads'),
        cache_path: config[:cache_path] || @cache_dir&.+(File::SEPARATOR + 'datasets'),
        timeout: config[:timeout] || @request_timeout,
        enable_kaggle: config.fetch(:enable_kaggle, true) # Default to true for backwards compatibility
      }

      # Add Kaggle credentials if provided and Kaggle is enabled
      if config[:kaggle] && processor_config[:enable_kaggle]
        kaggle_config = config[:kaggle]
        processor_config.merge!({
                                  username: kaggle_config[:username],
                                  api_key: kaggle_config[:api_key],
                                  credentials_file: kaggle_config[:credentials_file]
                                })
      end

      DatasetProcessor.new(**processor_config)
    rescue Error => e
      # Dataset processor failed to initialize, but client can still work without it
      puts "Warning: Dataset processor initialization failed: #{e.message}" if ENV['DEBUG']
      nil
    end

    def integrate_dataset(dataset, category_mappings)
      return dataset unless @dataset_processor

      categorized_data = @dataset_processor.integrate_dataset_into_categorization(dataset, category_mappings)

      # Store metadata
      @dataset_metadata ||= {}
      @dataset_metadata[categorized_data[:_metadata][:data_hash]] = categorized_data[:_metadata]

      # Remove metadata from the working data
      categorized_data.delete(:_metadata)

      # Merge with existing host data
      categorized_data.each do |category, domains|
        next if category.to_s.start_with?('_') # Skip internal keys

        # Convert category to symbol for consistency
        category_sym = category.to_sym
        @hosts[category_sym] ||= []
        @hosts[category_sym].concat(domains).uniq!

        # Track this as a dataset category
        @dataset_categories.add(category_sym)
      end

      dataset
    end

    def hash_size_in_mb(hash)
      size = 0

      hash.each do |_key, value|
        size += value.join.length
      end

      (size / ONE_MEGABYTE).round(2)
    end

    def fetch_and_build_host_lists
      @hosts = {}

      host_urls.keys.each do |category|
        @hosts[category] = build_host_data(host_urls[category])
      end

      sub_category_values = categories_with_keys
      sub_category_values.keys.each do |category|
        original_value = @hosts[category] || []

        extra_category_values = sub_category_values[category].map do |sub_category|
          @hosts[sub_category] || []
        end.flatten

        original_value.concat(extra_category_values)
        @hosts[category] = original_value.uniq.compact
      end

      @hosts
    end

    def build_host_data(urls)
      all_hosts = []

      urls.each do |url|
        next unless url_valid?(url)

        hosts_data = nil

        hosts_data = read_from_cache(url) if @cache_dir && !@force_download

        if hosts_data.nil?
          hosts_data = download_and_parse_list(url)
          save_to_cache(url, hosts_data) if @cache_dir
        end

        all_hosts.concat(hosts_data) if hosts_data
      end

      all_hosts.compact.sort.uniq
    end

    def download_and_parse_list(url)
      raw_data = HTTParty.get(url, timeout: @request_timeout)
      return [] if raw_data.body.nil? || raw_data.body.empty?

      # Store metadata
      etag = raw_data.headers['etag']
      last_modified = raw_data.headers['last-modified']
      @metadata[url] = {
        last_updated: Time.now,
        etag: etag,
        last_modified: last_modified,
        content_hash: Digest::SHA256.hexdigest(raw_data.body),
        status: 'success'
      }

      parse_list_content(raw_data.body, detect_list_format(raw_data.body))
    rescue HTTParty::Error, Net::HTTPError, SocketError, Timeout::Error, URI::InvalidURIError, StandardError => e
      # Log the error but continue with other lists
      @metadata[url] = {
        last_updated: Time.now,
        error: e.message,
        status: 'failed'
      }
      []
    end

    def parse_list_content(content, format)
      lines = content.split("\n").reject { |line| line.empty? || line.strip.start_with?('#') }

      case format
      when :hosts
        lines.map do |line|
          parts = line.split(' ')
          # Extract domain from hosts format: "0.0.0.0 domain.com" -> "domain.com"
          parts.length >= 2 ? parts[1].strip : nil
        end.compact.reject(&:empty?)
      when :plain
        lines.map(&:strip)
      when :dnsmasq
        lines.map do |line|
          match = line.match(%r{address=/(.+?)/})
          match ? match[1] : nil
        end.compact
      when :ublock
        lines.map { |line| line.gsub(/^\|\|/, '').gsub(/[$\^].*$/, '').strip }.reject(&:empty?)
      else
        lines.map(&:strip)
      end
    end

    def detect_list_format(content)
      # Skip comments and empty lines, then look at first 20 non-comment lines
      sample_lines = content.split("\n")
                            .reject { |line| line.empty? || line.strip.start_with?('#') }
                            .first(20)

      return :hosts if sample_lines.any? { |line| line.match(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\s+/) }
      return :dnsmasq if sample_lines.any? { |line| line.include?('address=/') }
      return :ublock if sample_lines.any? { |line| line.match(/^\|\|/) }

      :plain
    end

    def cache_file_path(url)
      return nil unless @cache_dir

      FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
      filename = Digest::MD5.hexdigest(url) + '.cache'
      File.join(@cache_dir, filename)
    end

    def read_from_cache(url)
      cache_file = cache_file_path(url)
      return nil unless cache_file && File.exist?(cache_file)

      cache_data = Marshal.load(File.read(cache_file))

      # Check if we should update based on hash or time
      return nil if should_update_cache?(url, cache_data)

      cache_data[:hosts]
    rescue StandardError
      nil
    end

    def save_to_cache(url, hosts_data)
      cache_file = cache_file_path(url)
      return unless cache_file

      cache_data = {
        hosts: hosts_data,
        metadata: @metadata[url],
        cached_at: Time.now
      }

      File.write(cache_file, Marshal.dump(cache_data))
    rescue StandardError
      # Cache save failed, continue without caching
    end

    def should_update_cache?(url, cache_data)
      return true if @force_download
      return true unless cache_data[:metadata]

      # Update if cache is older than 24 hours
      cache_age = Time.now - cache_data[:cached_at]
      return true if cache_age > 24 * 60 * 60

      # Check if remote content has changed
      begin
        head_response = HTTParty.head(url, timeout: @request_timeout)
        remote_etag = head_response.headers['etag']
        remote_last_modified = head_response.headers['last-modified']

        cached_metadata = cache_data[:metadata]

        return true if remote_etag && cached_metadata[:etag] && remote_etag != cached_metadata[:etag]
        if remote_last_modified && cached_metadata[:last_modified] && remote_last_modified != cached_metadata[:last_modified]
          return true
        end
      rescue HTTParty::Error, Net::HTTPError, SocketError, Timeout::Error, URI::InvalidURIError, StandardError
        # If HEAD request fails, assume we should update
        return true
      end

      false
    end

    def categories_with_keys
      keyed_categories = {}

      host_urls.keys.each do |category|
        category_values = host_urls[category].select do |url|
          url.is_a?(Symbol)
        end

        keyed_categories[category] = category_values unless category_values.empty?
      end

      keyed_categories
    end

    def url_not_valid?(url)
      !url_valid?(url)
    end

    def url_valid?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && !uri.host.nil?
    rescue URI::InvalidURIError
      false
    end
  end
end
