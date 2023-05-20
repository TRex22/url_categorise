module UrlCategorise
  class Client < ApiPattern::Client
    include ::UrlCategorise::Constants

    attr_reader :host_urls, :hosts

    # TODO: Save to folder
    # TODO: Read from disk the database
    # TODO: Sanctioned IPs
    # TODO: ActiveRecord support
    # TODO: List of abuse IPs
    def initialize(host_urls: DEFAULT_HOST_URLS)
      @host_urls = host_urls
      @hosts = fetch_and_build_host_lists
    end

    def categorise(url)
      host = (URI.parse(url).host || url).downcase
      host = host.gsub("www.", "")

      @hosts.keys.select do |category|
        @hosts[category].include?(host)
      end
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
      (size / 1.megabyte).round(2)
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
        @hosts[category] = original_value
      end

      @hosts
    end

    def build_host_data(urls)
      urls.map do |url|
        next unless url_valid?(url)

        raw_data = HTTParty.get(url)
        raw_data.split("\n").reject do |line|
          line[0] == "#"
        end.map do |line|
          line.split(' ')[1] # Select the domain name # gsub("0.0.0.0 ", "")
        end
      end.flatten.compact.sort
    end

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
