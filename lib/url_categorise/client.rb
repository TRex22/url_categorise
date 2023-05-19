module UrlCategorise
  class Client < ApiPattern::Client
    include ::UrlCategorise::Constants

    attr_reader :host_urls, :hosts

    # TODO: Sanctioned IPs
    # TODO: More default lists
    # TODO: ActiveRecord support
    # TODO: List of abuse IPs
    # TODO: https://github.com/blocklistproject/Lists
    # TODO: https://github.com/nickoppen/pihole-blocklists
    def initialize(host_urls: DEFAULT_HOST_URLS)
      @host_urls = host_urls
      # @hosts = fetch_and_build_host_lists
    end

    def self.compatible_api_version
      'v1'
    end

    def self.api_version
      'v2 2023-05-19'
    end

    def categorise(url)
      host = (URI.parse(url).host || url).downcase

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

    end

    def fetch_and_build_host_lists
      @hosts = {}

      host_urls.keys.each do |category|
        @hosts[category] = build_host_data(host_urls[category])
      end

      @hosts
    end

    def build_host_data(urls)
      urls.map do |url|
        raw_data = HTTParty.get(url)
        raw_data.split("\n").reject do |line|
          line.include?("#")
        end.map do |line|
          line.gsub("0.0.0.0 ", "")
        end
      end.flatten.compact.sort
    end
  end
end
