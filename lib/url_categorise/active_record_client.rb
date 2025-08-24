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
        dataset_metadata: UrlCategorise::Models::DatasetMetadata.count,
        categories: UrlCategorise::Models::Domain.distinct.pluck(:categories).flatten.uniq.size
      }
    end

    def load_kaggle_dataset(dataset_owner, dataset_name, options = {})
      result = super(dataset_owner, dataset_name, options)
      
      # Store dataset metadata in database if enabled
      if @use_database && UrlCategorise::Models.available? && @dataset_metadata
        store_dataset_metadata_in_db(
          source_type: 'kaggle',
          identifier: "#{dataset_owner}/#{dataset_name}",
          metadata: @dataset_metadata.values.last,
          category_mappings: options[:category_mappings],
          processing_options: options
        )
      end
      
      result
    end

    def load_csv_dataset(url, options = {})
      result = super(url, options)
      
      # Store dataset metadata in database if enabled
      if @use_database && UrlCategorise::Models.available? && @dataset_metadata
        store_dataset_metadata_in_db(
          source_type: 'csv',
          identifier: url,
          metadata: @dataset_metadata.values.last,
          category_mappings: options[:category_mappings],
          processing_options: options
        )
      end
      
      result
    end

    def dataset_history(source_type: nil, limit: 10)
      return [] unless @use_database && UrlCategorise::Models.available?
      
      query = UrlCategorise::Models::DatasetMetadata.order(processed_at: :desc).limit(limit)
      query = query.by_source(source_type) if source_type
      
      query.map do |record|
        {
          source_type: record.source_type,
          identifier: record.identifier,
          data_hash: record.data_hash,
          total_entries: record.total_entries,
          processed_at: record.processed_at,
          category_mappings: record.category_mappings,
          processing_options: record.processing_options
        }
      end
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

    def store_dataset_metadata_in_db(source_type:, identifier:, metadata:, category_mappings: nil, processing_options: nil)
      return unless UrlCategorise::Models.available?
      
      UrlCategorise::Models::DatasetMetadata.find_or_create_by(data_hash: metadata[:data_hash]) do |record|
        record.source_type = source_type
        record.identifier = identifier
        record.total_entries = metadata[:total_entries]
        record.category_mappings = category_mappings || {}
        record.processing_options = processing_options || {}
        record.processed_at = metadata[:processed_at] || Time.now
      end
    rescue ActiveRecord::RecordInvalid => e
      # Dataset metadata already exists or validation failed
      puts "Warning: Failed to store dataset metadata: #{e.message}" if ENV['DEBUG']
    end
  end
end