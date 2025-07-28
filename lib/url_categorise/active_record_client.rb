require_relative 'models'

module UrlCategorise
  class ActiveRecordClient < Client
    def initialize(**kwargs)
      raise "ActiveRecord not available" unless UrlCategorise::Models.available?
      
      @use_database = kwargs.delete(:use_database) { true }
      super(**kwargs)
      
      populate_database if @use_database
    end

    def categorise(url)
      return super(url) unless @use_database && UrlCategorise::Models.available?
      
      host = (URI.parse(url).host || url).downcase.gsub("www.", "")
      
      # Try database first
      categories = UrlCategorise::Models::Domain.categorise(host)
      return categories unless categories.empty?
      
      # Fallback to memory-based categorization
      super(url)
    end

    def categorise_ip(ip_address)
      return super(ip_address) unless @use_database && UrlCategorise::Models.available?
      
      # Try database first
      categories = UrlCategorise::Models::IpAddress.categorise(ip_address)
      return categories unless categories.empty?
      
      # Fallback to memory-based categorization
      super(ip_address)
    end

    def update_database
      return unless @use_database && UrlCategorise::Models.available?
      
      populate_database
    end

    def database_stats
      return {} unless @use_database && UrlCategorise::Models.available?
      
      {
        domains: UrlCategorise::Models::Domain.count,
        ip_addresses: UrlCategorise::Models::IpAddress.count,
        list_metadata: UrlCategorise::Models::ListMetadata.count,
        categories: UrlCategorise::Models::Domain.distinct.pluck(:categories).flatten.uniq.size
      }
    end

    private

    def populate_database
      return unless UrlCategorise::Models.available?
      
      # Store list metadata
      @host_urls.each do |category, urls|
        urls.each do |url|
          next unless url.is_a?(String)
          
          metadata = @metadata[url] || {}
          UrlCategorise::Models::ListMetadata.find_or_create_by(url: url) do |record|
            record.name = category.to_s
            record.categories = [category.to_s]
            record.file_hash = metadata[:content_hash]
            record.fetched_at = metadata[:last_updated]
          end
        end
      end

      # Store domain data
      @hosts.each do |category, domains|
        domains.each do |domain|
          next if domain.nil? || domain.empty?
          
          existing = UrlCategorise::Models::Domain.find_by(domain: domain)
          if existing
            # Add category if not already present
            categories = existing.categories | [category.to_s]
            existing.update(categories: categories) if categories != existing.categories
          else
            UrlCategorise::Models::Domain.create!(
              domain: domain,
              categories: [category.to_s]
            )
          end
        end
      end

      # Store IP data (for IP-based lists)
      ip_categories = [:sanctions_ips, :compromised_ips, :tor_exit_nodes, :open_proxy_ips, 
                       :banking_trojans, :malicious_ssl_certificates, :top_attack_sources]
      
      ip_categories.each do |category|
        next unless @hosts[category]
        
        @hosts[category].each do |ip|
          next if ip.nil? || ip.empty? || !ip.match(/^\d+\.\d+\.\d+\.\d+$/)
          
          existing = UrlCategorise::Models::IpAddress.find_by(ip_address: ip)
          if existing
            categories = existing.categories | [category.to_s]
            existing.update(categories: categories) if categories != existing.categories
          else
            UrlCategorise::Models::IpAddress.create!(
              ip_address: ip,
              categories: [category.to_s]
            )
          end
        end
      end
    end
  end
end