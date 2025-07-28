module UrlCategorise
  class Client < ApiPattern::Client
    include ::UrlCategorise::Constants

    def self.compatible_api_version
      'v2'
    end

    def self.api_version
      'v2 2023-04-12'
    end

    attr_reader :host_urls, :hosts, :cache_dir, :force_download, :dns_servers, :metadata

    def initialize(host_urls: DEFAULT_HOST_URLS, cache_dir: nil, force_download: false, dns_servers: ['1.1.1.1', '1.0.0.1'])
      @host_urls = host_urls
      @cache_dir = cache_dir
      @force_download = force_download
      @dns_servers = dns_servers
      @metadata = {}
      @hosts = fetch_and_build_host_lists
    end

    def categorise(url)
      host = (URI.parse(url).host || url).downcase
      host = host.gsub("www.", "")

      @hosts.keys.select do |category|
        @hosts[category].include?(host)
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
      rescue
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

    private

    def hash_size_in_mb(hash)
      size = 0

      hash.each do |key, value|
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

        extra_category_values = sub_category_values[category].each do |sub_category|
          @hosts[sub_category]
        end

        original_value << extra_category_values
        @hosts[category] = original_value.uniq.compact
      end

      @hosts
    end

    def build_host_data(urls)
      all_hosts = []
      
      urls.each do |url|
        next unless url_valid?(url)
        
        hosts_data = nil
        
        if @cache_dir && !@force_download
          hosts_data = read_from_cache(url)
        end
        
        if hosts_data.nil?
          hosts_data = download_and_parse_list(url)
          save_to_cache(url, hosts_data) if @cache_dir
        end
        
        all_hosts.concat(hosts_data) if hosts_data
      end
      
      all_hosts.compact.sort.uniq
    end

    def download_and_parse_list(url)
      raw_data = HTTParty.get(url)
      return [] if raw_data.body.nil? || raw_data.body.empty?
      
      # Store metadata
      etag = raw_data.headers['etag']
      last_modified = raw_data.headers['last-modified']
      @metadata[url] = {
        last_updated: Time.now,
        etag: etag,
        last_modified: last_modified,
        content_hash: Digest::SHA256.hexdigest(raw_data.body)
      }
      
      parse_list_content(raw_data.body, detect_list_format(raw_data.body))
    end

    def parse_list_content(content, format)
      lines = content.split("\n").reject { |line| line.empty? || line.strip.start_with?('#') }
      
      case format
      when :hosts
        lines.map { |line| line.split(' ')[1] }.compact
      when :plain
        lines.map(&:strip)
      when :dnsmasq
        lines.map { |line| 
          match = line.match(/address=\/(.+?)\//)
          match ? match[1] : nil
        }.compact
      when :ublock
        lines.map { |line| line.gsub(/^[\|\*\.]*/, '').gsub(/[\$\^].*$/, '').strip }.reject(&:empty?)
      else
        lines.map(&:strip)
      end
    end

    def detect_list_format(content)
      sample_lines = content.split("\n").first(10)
      
      return :hosts if sample_lines.any? { |line| line.match(/^(0\.0\.0\.0|127\.0\.0\.1)\s+/) }
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
      if should_update_cache?(url, cache_data)
        return nil
      end
      
      cache_data[:hosts]
    rescue
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
    rescue
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
        head_response = HTTParty.head(url)
        remote_etag = head_response.headers['etag']
        remote_last_modified = head_response.headers['last-modified']
        
        cached_metadata = cache_data[:metadata]
        
        return true if remote_etag && cached_metadata[:etag] && remote_etag != cached_metadata[:etag]
        return true if remote_last_modified && cached_metadata[:last_modified] && remote_last_modified != cached_metadata[:last_modified]
      rescue
        # If HEAD request fails, assume we should update
        return true
      end
      
      false
    end

    private

    def categories_with_keys
      keyed_categories = {}

      host_urls.keys.each do |category|
        category_values = host_urls[category].select do |url|
          url_not_valid?(url) && url.is_a?(Symbol)
        end

        keyed_categories[category] = category_values
      end

      keyed_categories
    end

    def url_not_valid?(url)
      url_valid?(url)
    end

    def url_valid?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && !uri.host.nil?
    rescue URI::InvalidURIError
      false
    end
  end
end
