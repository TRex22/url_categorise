require 'set'
require 'digest'

module UrlCategorise
  class Client < ApiPattern::Client
    include ::UrlCategorise::Constants
    include ActiveAttr::Model

    def self.compatible_api_version
      'v2'
    end

    def self.api_version
      'v2 2025-08-23'
    end

    attribute :host_urls, default: -> { DEFAULT_HOST_URLS }
    attribute :cache_dir
    attribute :force_download, type: Boolean, default: false
    attribute :dns_servers, default: ['1.1.1.1', '1.0.0.1']
    attribute :request_timeout, type: Integer, default: 10
    attribute :iab_compliance_enabled, type: Boolean, default: false
    attribute :iab_version, default: :v3
    attribute :auto_load_datasets, type: Boolean, default: false
    attribute :smart_categorization_enabled, type: Boolean, default: false
    attribute :smart_rules, default: -> { {} }
    attribute :regex_categorization_enabled, type: Boolean, default: false
    attribute :regex_patterns_file, default: -> { VIDEO_URL_PATTERNS_FILE }

    attr_reader :hosts, :metadata, :dataset_processor, :dataset_categories, :regex_patterns

    def initialize(**kwargs)
      # Extract dataset_config for later use
      dataset_config = kwargs.fetch(:dataset_config, {})
      
      # Set ActiveAttr attributes - preserve explicitly passed values including nil
      self.host_urls = kwargs.key?(:host_urls) ? kwargs[:host_urls] : DEFAULT_HOST_URLS
      self.cache_dir = kwargs[:cache_dir] # will be nil if not provided or explicitly nil
      self.force_download = kwargs.key?(:force_download) ? kwargs[:force_download] : false
      self.dns_servers = kwargs.key?(:dns_servers) ? kwargs[:dns_servers] : ['1.1.1.1', '1.0.0.1']
      self.request_timeout = kwargs.key?(:request_timeout) ? kwargs[:request_timeout] : 10
      self.iab_compliance_enabled = kwargs.key?(:iab_compliance) ? kwargs[:iab_compliance] : false
      self.iab_version = kwargs.key?(:iab_version) ? kwargs[:iab_version] : :v3
      self.auto_load_datasets = kwargs.key?(:auto_load_datasets) ? kwargs[:auto_load_datasets] : false
      self.smart_categorization_enabled = kwargs.key?(:smart_categorization) ? kwargs[:smart_categorization] : false
      self.smart_rules = initialize_smart_rules(kwargs.key?(:smart_rules) ? kwargs[:smart_rules] : {})
      self.regex_categorization_enabled = kwargs.key?(:regex_categorization) ? kwargs[:regex_categorization] : false
      self.regex_patterns_file = kwargs.key?(:regex_patterns_file) ? kwargs[:regex_patterns_file] : VIDEO_URL_PATTERNS_FILE

      @metadata = {}
      @dataset_categories = Set.new # Track which categories come from datasets
      @regex_patterns = {}

      # Initialize dataset processor if config provided
      @dataset_processor = initialize_dataset_processor(dataset_config) unless dataset_config.empty?

      @hosts = fetch_and_build_host_lists

      # Load regex patterns if enabled
      load_regex_patterns if regex_categorization_enabled

      # Auto-load datasets from constants if enabled
      load_datasets_from_constants if auto_load_datasets && @dataset_processor
    end

    def categorise(url)
      host = (URI.parse(url).host || url).downcase
      host = host.gsub('www.', '')

      categories = @hosts.keys.select do |category|
        @hosts[category].any? do |blocked_host|
          host == blocked_host || host.end_with?(".#{blocked_host}")
        end
      end

      # Apply smart categorization if enabled
      categories = apply_smart_categorization(url, categories) if smart_categorization_enabled

      # Apply regex categorization if enabled
      categories = apply_regex_categorization(url, categories) if regex_categorization_enabled

      if iab_compliance_enabled
        IabCompliance.get_iab_categories(categories, iab_version)
      else
        categories
      end
    end

    def categorise_ip(ip_address)
      categories = @hosts.keys.select do |category|
        @hosts[category].include?(ip_address)
      end

      if iab_compliance_enabled
        IabCompliance.get_iab_categories(categories, iab_version)
      else
        categories
      end
    end

    def resolve_and_categorise(domain)
      categories = categorise(domain)

      begin
        resolver = Resolv::DNS.new(nameserver: dns_servers)
        ip_addresses = resolver.getaddresses(domain).map(&:to_s)

        ip_addresses.each do |ip|
          categories.concat(categorise_ip(ip))
        end
      rescue StandardError
        # DNS resolution failed, return domain categories only
      end

      categories.uniq
    end

    def video_url?(url)
      return false unless url && !url.empty?
      return false unless regex_categorization_enabled && @regex_patterns.any?

      # First check if it's from a video hosting domain
      categories = categorise(url)
      video_hosting_categories = categories & [:video, :video_hosting, :youtube, :vimeo, :tiktok, :dailymotion, :twitch]
      
      return false unless video_hosting_categories.any?

      # Then check if it matches video content patterns
      @regex_patterns.each do |_category, patterns|
        patterns.each do |pattern_info|
          return true if url.match?(pattern_info[:pattern])
        end
      end

      false
    rescue StandardError
      # Handle any regex or URL parsing errors gracefully
      false
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

    def size_of_dataset_data
      dataset_hosts = {}
      @dataset_categories.each do |category|
        dataset_hosts[category] = @hosts[category] || []
      end
      hash_size_in_mb(dataset_hosts)
    end

    def size_of_blocklist_data
      blocklist_hosts = {}
      @hosts.each do |category, domains|
        blocklist_hosts[category] = domains unless @dataset_categories.include?(category)
      end
      hash_size_in_mb(blocklist_hosts)
    end

    def size_of_data_bytes
      hash_size_in_bytes(@hosts)
    end

    def size_of_dataset_data_bytes
      dataset_hosts = {}
      @dataset_categories.each do |category|
        dataset_hosts[category] = @hosts[category] || []
      end
      hash_size_in_bytes(dataset_hosts)
    end

    def size_of_blocklist_data_bytes
      blocklist_hosts = {}
      @hosts.each do |category, domains|
        blocklist_hosts[category] = domains unless @dataset_categories.include?(category)
      end
      hash_size_in_bytes(blocklist_hosts)
    end

    def count_of_dataset_hosts
      @dataset_categories.map do |category|
        @hosts[category]&.size || 0
      end.sum
    end

    def count_of_dataset_categories
      @dataset_categories.size
    end

    def iab_compliant?
      iab_compliance_enabled
    end

    def get_iab_mapping(category)
      return nil unless iab_compliance_enabled

      IabCompliance.map_category_to_iab(category, iab_version)
    end

    def check_all_lists
      puts 'Checking all lists in constants...'

      unreachable_lists = {}
      missing_categories = []
      successful_lists = {}

      (host_urls || {}).each do |category, urls|
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
            response = HTTParty.head(url, timeout: request_timeout, follow_redirects: true)

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
      total_categories = (host_urls || {}).keys.length
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

      # Reload datasets from constants if auto-loading is enabled
      load_datasets_from_constants if auto_load_datasets && @dataset_processor

      self
    end

    def export_hosts_files(output_path = nil)
      export_dir = output_path || (cache_dir ? File.join(cache_dir, 'exports', 'hosts') : File.join(Dir.pwd, 'exports', 'hosts'))
      
      FileUtils.mkdir_p(export_dir) unless Dir.exist?(export_dir)
      
      exported_files = {}
      
      @hosts.each do |category, domains|
        next if domains.empty?
        
        filename = "#{category}.hosts"
        file_path = File.join(export_dir, filename)
        
        File.open(file_path, 'w') do |file|
          file.puts "# #{category.to_s.gsub('_', ' ').split.map(&:capitalize).join(' ')} - Generated by UrlCategorise"
          file.puts "# Generated at: #{Time.now}"
          file.puts "# Total entries: #{domains.length}"
          file.puts ""
          
          domains.sort.each do |domain|
            file.puts "0.0.0.0 #{domain}"
          end
        end
        
        exported_files[category] = {
          path: file_path,
          filename: filename,
          count: domains.length
        }
      end
      
      # Create summary file
      summary_path = File.join(export_dir, '_export_summary.txt')
      File.open(summary_path, 'w') do |file|
        file.puts "UrlCategorise Hosts Export Summary"
        file.puts "=================================="
        file.puts "Generated at: #{Time.now}"
        file.puts "Export directory: #{export_dir}"
        file.puts "Total categories: #{exported_files.keys.length}"
        file.puts "Total domains: #{@hosts.values.map(&:length).sum}"
        file.puts ""
        file.puts "Files created:"
        
        exported_files.each do |category, info|
          file.puts "  #{info[:filename]} - #{info[:count]} domains"
        end
      end
      
      exported_files[:_summary] = {
        path: summary_path,
        total_categories: exported_files.keys.length,
        total_domains: @hosts.values.map(&:length).sum,
        export_directory: export_dir
      }
      
      exported_files
    end

    def export_csv_data(output_path = nil)
      require 'csv'
      
      export_dir = output_path || (cache_dir ? File.join(cache_dir, 'exports', 'csv') : File.join(Dir.pwd, 'exports', 'csv'))
      
      FileUtils.mkdir_p(export_dir) unless Dir.exist?(export_dir)
      
      # Create single comprehensive CSV with ALL data
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = "url_categorise_comprehensive_export_#{timestamp}.csv"
      file_path = File.join(export_dir, filename)
      
      # Collect all available data
      all_data = collect_all_export_data
      
      # Create CSV with dynamic headers
      headers = determine_comprehensive_headers(all_data)
      
      CSV.open(file_path, 'w', headers: true) do |csv|
        csv << headers
        
        all_data.each do |entry|
          row = headers.map { |header| entry[header] || entry[header.to_sym] || '' }
          csv << row
        end
      end
      
      # Create summary file
      summary_filename = "export_summary_#{timestamp}.json"
      summary_file_path = File.join(export_dir, summary_filename)
      
      summary = create_comprehensive_export_summary(file_path, all_data, export_dir)
      File.write(summary_file_path, JSON.pretty_generate(summary))
      
      {
        csv_file: file_path,
        summary_file: summary_file_path,
        summary: summary[:data_summary],
        export_directory: export_dir,
        total_entries: all_data.length
      }
    end

    private

    def load_regex_patterns
      return unless regex_patterns_file

      @regex_patterns = {}
      current_category = nil

      content = fetch_regex_patterns_content
      return unless content

      content.split("\n").each do |line|
        line = line.strip
        next if line.empty?

        # Check if this line is a source comment
        if line.match(/^# Source: (.+)$/)
          current_category = $1.downcase
          @regex_patterns[current_category] = [] unless @regex_patterns[current_category]
        elsif current_category && !line.start_with?('#') && !line.empty?
          # This is a regex pattern
          begin
            regex = Regexp.new(line)
            @regex_patterns[current_category] << {
              pattern: regex,
              raw: line
            }
          rescue RegexpError => e
            puts "Warning: Invalid regex pattern '#{line}': #{e.message}"
          end
        end
      end

      puts "Loaded #{@regex_patterns.values.flatten.size} regex patterns from #{@regex_patterns.keys.size} categories" if @regex_patterns.any?
    end

    def fetch_regex_patterns_content
      if regex_patterns_file.start_with?('http://', 'https://')
        # Remote URL
        begin
          response = HTTParty.get(regex_patterns_file, timeout: request_timeout)
          return response.body if response.code == 200
        rescue HTTParty::Error, Net::HTTPError, SocketError, Timeout::Error, URI::InvalidURIError, StandardError => e
          puts "Warning: Failed to fetch regex patterns from #{regex_patterns_file}: #{e.message}"
          return nil
        end
      elsif regex_patterns_file.start_with?('file://')
        # Local file URL
        file_path = regex_patterns_file.sub('file://', '')
        return File.read(file_path) if File.exist?(file_path)
      elsif File.exist?(regex_patterns_file)
        # Direct file path
        return File.read(regex_patterns_file)
      end

      puts "Warning: Regex patterns file not found: #{regex_patterns_file}"
      nil
    end

    def apply_regex_categorization(url, existing_categories)
      return existing_categories unless @regex_patterns.any?

      # If we have existing categories that match domains, check if the URL matches video patterns
      video_categories = existing_categories & [:video, :video_hosting, :youtube, :vimeo, :tiktok]
      
      if video_categories.any?
        # Check if this URL matches any video patterns
        @regex_patterns.each do |category, patterns|
          patterns.each do |pattern_info|
            if url.match?(pattern_info[:pattern])
              # This is a video content URL, add a more specific categorization
              existing_categories << "#{video_categories.first}_content".to_sym unless existing_categories.include?("#{video_categories.first}_content".to_sym)
              break
            end
          end
        end
      end

      existing_categories.uniq
    end

    def collect_all_export_data
      all_data = []
      
      # 1. Add all processed domain/category mappings
      @hosts.each do |category, domains|
        domains.each do |domain|
          source_type = @dataset_categories.include?(category) ? 'dataset' : 'blocklist'
          is_dataset_category = @dataset_categories.include?(category)
          
          # Get IAB mappings if compliance is enabled
          iab_v2 = nil
          iab_v3 = nil
          if iab_compliance_enabled
            iab_v2 = IabCompliance.map_category_to_iab(category, :v2)
            iab_v3 = IabCompliance.map_category_to_iab(category, :v3)
          end
          
          entry = {
            'data_type' => 'domain_categorization',
            'domain' => domain,
            'url' => domain, # For compatibility
            'category' => category.to_s,
            'source_type' => source_type,
            'is_dataset_category' => is_dataset_category,
            'iab_category_v2' => iab_v2,
            'iab_category_v3' => iab_v3,
            'export_timestamp' => Time.now.iso8601,
            'smart_categorization_enabled' => smart_categorization_enabled
          }
          
          all_data << entry
        end
      end
      
      # 2. Add raw dataset content from cache
      collect_cached_dataset_content.each do |entry|
        entry['data_type'] = 'raw_dataset_content'
        all_data << entry
      end
      
      # 3. Try to collect currently loaded dataset data if available
      collect_current_dataset_content.each do |entry|
        entry['data_type'] = 'current_dataset_content'  
        all_data << entry
      end
      
      all_data
    end

    def collect_cached_dataset_content
      cached_data = []
      return cached_data unless @dataset_processor

      # Collect from cached datasets if available
      (@dataset_metadata || {}).each do |data_hash, metadata|
        cache_key = @dataset_processor.send(:generate_cache_key, metadata[:source_identifier] || data_hash, metadata[:source_type]&.to_sym || :unknown)
        cached_result = @dataset_processor.send(:load_from_cache, cache_key)
        
        if cached_result && cached_result.is_a?(Hash) && cached_result['raw_content']
          cached_result['raw_content'].each do |entry|
            enhanced_entry = entry.dup
            enhanced_entry['dataset_source'] = metadata[:source_identifier] || 'unknown'
            enhanced_entry['dataset_type'] = metadata[:source_type] || 'unknown'
            enhanced_entry['processed_at'] = metadata[:processed_at]
            cached_data << enhanced_entry
          end
        elsif cached_result.is_a?(Array)
          # Legacy format - array of entries
          cached_result.each do |entry|
            next unless entry.is_a?(Hash)
            enhanced_entry = entry.dup
            enhanced_entry['dataset_source'] = metadata[:source_identifier] || 'unknown' 
            enhanced_entry['dataset_type'] = metadata[:source_type] || 'unknown'
            enhanced_entry['processed_at'] = metadata[:processed_at]
            cached_data << enhanced_entry
          end
        end
      end

      cached_data
    end

    def collect_current_dataset_content
      # This is a placeholder - in practice, the original dataset content 
      # is processed and only domain mappings are kept in @hosts.
      # The raw content should come from cache, but if we want to be more
      # aggressive, we could re-process datasets here or store them differently.
      []
    end

    def determine_comprehensive_headers(all_data)
      # Collect all unique keys from all entries
      all_keys = Set.new
      all_data.each do |entry|
        all_keys.merge(entry.keys.map(&:to_s))
      end
      all_keys_array = all_keys.to_a

      # Core headers that should appear first
      core_headers = %w[data_type domain url category]
      
      # Standard categorization headers
      categorization_headers = %w[source_type is_dataset_category iab_category_v2 iab_category_v3]
      
      # Dataset content headers
      content_headers = %w[title description text content summary body]
      
      # Metadata headers
      metadata_headers = %w[dataset_source dataset_type processed_at export_timestamp smart_categorization_enabled]
      
      # Build final header order
      ordered_headers = []
      ordered_headers += (core_headers & all_keys_array)
      ordered_headers += (categorization_headers & all_keys_array)
      ordered_headers += (content_headers & all_keys_array)
      
      # Add any remaining headers (alphabetically sorted)
      remaining_headers = (all_keys_array - ordered_headers - metadata_headers).sort
      ordered_headers += remaining_headers
      
      # Add metadata headers at the end
      ordered_headers += (metadata_headers & all_keys_array)
      
      ordered_headers
    end

    def create_comprehensive_export_summary(file_path, all_data, export_dir)
      domain_entries = all_data.select { |entry| entry['data_type'] == 'domain_categorization' }
      dataset_entries = all_data.select { |entry| entry['data_type']&.include?('dataset') }
      
      {
        export_info: {
          timestamp: Time.now.iso8601,
          export_directory: export_dir,
          csv_file: file_path,
          total_entries: all_data.length
        },
        client_settings: {
          iab_compliance_enabled: iab_compliance_enabled,
          iab_version: iab_version,
          smart_categorization_enabled: smart_categorization_enabled,
          auto_load_datasets: auto_load_datasets
        },
        data_summary: {
          total_entries: all_data.length,
          domain_categorization_entries: domain_entries.length,
          dataset_content_entries: dataset_entries.length,
          total_domains: @hosts.values.map(&:length).sum,
          total_categories: @hosts.keys.length,
          dataset_categories_count: @dataset_categories.size,
          blocklist_categories_count: @hosts.keys.length - @dataset_categories.size,
          categories: @hosts.keys.sort.map(&:to_s),
          has_dataset_content: dataset_entries.any?
        },
        dataset_metadata: dataset_metadata
      }
    end


    private

    def initialize_dataset_processor(config)
      processor_config = {
        download_path: config[:download_path] || cache_dir&.+(File::SEPARATOR + 'downloads'),
        cache_path: config[:cache_path] || cache_dir&.+(File::SEPARATOR + 'datasets'),
        timeout: config[:timeout] || request_timeout,
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
      return nil unless dataset # Handle nil datasets gracefully

      processed_result = @dataset_processor.integrate_dataset_into_categorization(dataset, category_mappings)

      # Handle new data structure with categories and raw_content
      if processed_result.is_a?(Hash) && processed_result['categories']
        categorized_data = processed_result['categories']
        metadata = processed_result['_metadata']
      else
        # Legacy format - assume the whole result is categorized data
        categorized_data = processed_result
        metadata = categorized_data[:_metadata] if categorized_data.respond_to?(:delete)
      end

      # Store metadata
      if metadata
        @dataset_metadata ||= {}
        @dataset_metadata[metadata[:data_hash]] = metadata
      end

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

    def load_datasets_from_constants
      return unless defined?(CATEGORIY_DATABASES) && CATEGORIY_DATABASES.is_a?(Array)
      return unless @dataset_processor

      puts "Loading #{CATEGORIY_DATABASES.length} datasets from constants..." if ENV['DEBUG']
      loaded_count = 0

      CATEGORIY_DATABASES.each do |dataset_config|
        begin
          case dataset_config[:type]
          when :kaggle
            # Parse the kaggle path to get owner and dataset name
            path_parts = dataset_config[:path].split('/')
            next unless path_parts.length == 2

            dataset_owner, dataset_name = path_parts
            
            # Check if dataset is already cached before attempting to load
            cache_key = @dataset_processor.send(:generate_cache_key, "#{dataset_owner}/#{dataset_name}", :kaggle)
            cache_file = File.join(@dataset_processor.cache_path, cache_key)
            
            if File.exist?(cache_file)
              puts "Loading cached Kaggle dataset: #{dataset_owner}/#{dataset_name}" if ENV['DEBUG']
              load_kaggle_dataset(dataset_owner, dataset_name, {
                                    use_cache: true,
                                    integrate_data: true
                                  })
              loaded_count += 1
            else
              puts "Attempting to download missing Kaggle dataset: #{dataset_owner}/#{dataset_name}" if ENV['DEBUG']
              begin
                load_kaggle_dataset(dataset_owner, dataset_name, {
                                      use_cache: true,
                                      integrate_data: true
                                    })
                loaded_count += 1
              rescue Error => e
                puts "Warning: Failed to download Kaggle dataset #{dataset_owner}/#{dataset_name}: #{e.message}" if ENV['DEBUG']
              end
            end

          when :csv
            # Check if CSV dataset is cached
            cache_key = @dataset_processor.send(:generate_cache_key, dataset_config[:path], :csv)
            cache_file = File.join(@dataset_processor.cache_path, cache_key)
            
            if File.exist?(cache_file)
              puts "Loading cached CSV dataset: #{dataset_config[:path]}" if ENV['DEBUG']
              load_csv_dataset(dataset_config[:path], {
                                 use_cache: true,
                                 integrate_data: true
                               })
              loaded_count += 1
            else
              puts "Attempting to download missing CSV dataset: #{dataset_config[:path]}" if ENV['DEBUG']
              begin
                load_csv_dataset(dataset_config[:path], {
                                   use_cache: true,
                                   integrate_data: true
                                 })
                loaded_count += 1
              rescue Error => e
                puts "Warning: Failed to download CSV dataset #{dataset_config[:path]}: #{e.message}" if ENV['DEBUG']
              end
            end
          end
        rescue Error => e
          puts "Warning: Failed to load dataset #{dataset_config[:path]}: #{e.message}" if ENV['DEBUG']
          # Continue loading other datasets even if one fails
        rescue StandardError => e
          puts "Warning: Unexpected error loading dataset #{dataset_config[:path]}: #{e.message}" if ENV['DEBUG']
          # Continue loading other datasets even if one fails
        end
      end

      puts "Finished loading datasets from constants (#{loaded_count}/#{CATEGORIY_DATABASES.length} loaded)" if ENV['DEBUG']
    end

    def hash_size_in_mb(hash)
      size_bytes = hash_size_in_bytes(hash)
      (size_bytes / ONE_MEGABYTE.to_f).round(2)
    end

    def hash_size_in_bytes(hash)
      size = 0
      hash.each do |_key, value|
        next unless value.is_a?(Array)

        size += value.join.length
      end
      size
    end

    def fetch_and_build_host_lists
      @hosts = {}

      (host_urls || {}).keys.each do |category|
        @hosts[category] = build_host_data((host_urls || {})[category])
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

    def initialize_smart_rules(custom_rules)
      custom_rules = {} if custom_rules.nil?
      default_rules = {
        social_media_platforms: {
          domains: %w[reddit.com facebook.com twitter.com x.com instagram.com linkedin.com
                      pinterest.com tiktok.com youtube.com snapchat.com discord.com],
          remove_categories: %i[health_and_fitness forums news technology education
                                business finance entertainment travel sports politics
                                science music art food_and_drink shopping gaming]
        },
        search_engines: {
          domains: %w[google.com bing.com yahoo.com duckduckgo.com baidu.com yandex.com],
          remove_categories: %i[news shopping travel health_and_fitness finance technology]
        },
        video_platforms: {
          domains: %w[youtube.com vimeo.com dailymotion.com twitch.tv],
          remove_categories: %i[education news entertainment music sports gaming]
        },
        news_aggregators: {
          domains: %w[reddit.com digg.com],
          keep_primary_only: %i[social_media reddit digg]
        }
      }

      # Merge custom rules with defaults
      default_rules.merge(custom_rules)
    end

    def apply_smart_categorization(url, categories)
      return categories unless smart_categorization_enabled

      host = extract_host(url)

      smart_rules.each do |_rule_name, rule_config|
        if rule_config[:domains]&.any? { |domain| host == domain || host.end_with?(".#{domain}") }
          categories = apply_rule(categories, rule_config, host, url)
        end
      end

      categories
    end

    def apply_rule(categories, rule_config, _host, url)
      # Rule: Remove overly broad categories for specific platforms
      if rule_config[:remove_categories]
        categories = categories.reject { |cat| rule_config[:remove_categories].include?(cat) }
      end

      # Rule: Keep only primary categories
      if rule_config[:keep_primary_only]
        primary_categories = categories & rule_config[:keep_primary_only]
        categories = primary_categories if primary_categories.any?
      end

      # Rule: Add specific categories based on URL patterns
      if rule_config[:add_categories_by_path]
        rule_config[:add_categories_by_path].each do |path_pattern, additional_categories|
          categories = (categories + additional_categories).uniq if url.match?(path_pattern)
        end
      end

      # Rule: Remove all categories except allowed ones
      categories &= rule_config[:allowed_categories_only] if rule_config[:allowed_categories_only]

      categories
    end

    def extract_host(url)
      (URI.parse(url).host || url).downcase.gsub('www.', '')
    rescue URI::InvalidURIError
      url.downcase.gsub('www.', '')
    end

    def build_host_data(urls)
      all_hosts = []

      urls.each do |url|
        next unless url_valid?(url)

        hosts_data = nil

        hosts_data = read_from_cache(url) if cache_dir && !force_download

        if hosts_data.nil?
          hosts_data = download_and_parse_list(url)
          save_to_cache(url, hosts_data) if cache_dir
        end

        all_hosts.concat(hosts_data) if hosts_data
      end

      all_hosts.compact.sort.uniq
    end

    def download_and_parse_list(url)
      if url.start_with?('file://')
        # Handle local file URLs
        file_path = url.sub('file://', '')
        return [] unless File.exist?(file_path)
        
        content = File.read(file_path)
        return [] if content.nil? || content.empty?
        
        # Store metadata
        @metadata[url] = {
          last_updated: Time.now,
          content_hash: Digest::SHA256.hexdigest(content),
          status: 'success'
        }
        
        return parse_list_content(content, detect_list_format(content))
      end
      
      raw_data = HTTParty.get(url, timeout: request_timeout)
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
      return nil unless cache_dir

      FileUtils.mkdir_p(cache_dir) unless Dir.exist?(cache_dir)
      filename = Digest::MD5.hexdigest(url) + '.cache'
      File.join(cache_dir, filename)
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
      return true if force_download
      return true unless cache_data[:metadata]

      # Update if cache is older than 24 hours
      cache_age = Time.now - cache_data[:cached_at]
      return true if cache_age > 24 * 60 * 60

      # Check if remote content has changed
      begin
        head_response = HTTParty.head(url, timeout: request_timeout)
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

      (host_urls || {}).keys.each do |category|
        category_values = (host_urls || {})[category].select do |url|
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
      return false if url.nil? || url.empty?
      return true if url.start_with?('file://')
      
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && !uri.host.nil?
    rescue URI::InvalidURIError
      false
    end
  end
end
