begin
  require 'active_record'
rescue LoadError
  # ActiveRecord not available, skip model definitions
  module UrlCategorise
    module Models
      def self.available?
        false
      end
    end
  end
else
  module UrlCategorise
    module Models
      def self.available?
        true
      end

      class ListMetadata < ActiveRecord::Base
        self.table_name = 'url_categorise_list_metadata'
        
        validates :name, presence: true, uniqueness: true
        validates :url, presence: true
        validates :categories, presence: true
        
        serialize :categories, Array
        
        scope :by_category, ->(category) { where('categories LIKE ?', "%#{category}%") }
        scope :updated_since, ->(time) { where('updated_at > ?', time) }
      end

      class Domain < ActiveRecord::Base
        self.table_name = 'url_categorise_domains'
        
        validates :domain, presence: true, uniqueness: true
        validates :categories, presence: true
        
        serialize :categories, Array
        
        scope :by_category, ->(category) { where('categories LIKE ?', "%#{category}%") }
        scope :search, ->(term) { where('domain LIKE ?', "%#{term}%") }
        
        def self.categorise(domain_name)
          record = find_by(domain: domain_name.downcase.gsub('www.', ''))
          record ? record.categories : []
        end
      end

      class IpAddress < ActiveRecord::Base
        self.table_name = 'url_categorise_ip_addresses'
        
        validates :ip_address, presence: true, uniqueness: true
        validates :categories, presence: true
        
        serialize :categories, Array
        
        scope :by_category, ->(category) { where('categories LIKE ?', "%#{category}%") }
        scope :in_subnet, ->(subnet) { where('ip_address LIKE ?', "#{subnet}%") }
        
        def self.categorise(ip)
          record = find_by(ip_address: ip)
          record ? record.categories : []
        end
      end

      # Generator for Rails integration
      def self.generate_migration
        <<~MIGRATION
          class CreateUrlCategoriseTables < ActiveRecord::Migration[7.0]
            def change
              create_table :url_categorise_list_metadata do |t|
                t.string :name, null: false, index: { unique: true }
                t.string :url, null: false
                t.text :categories, null: false
                t.string :file_path
                t.datetime :fetched_at
                t.string :file_hash
                t.datetime :file_updated_at
                t.timestamps
              end

              create_table :url_categorise_domains do |t|
                t.string :domain, null: false, index: { unique: true }
                t.text :categories, null: false
                t.timestamps
              end
              
              add_index :url_categorise_domains, :domain
              add_index :url_categorise_domains, :categories

              create_table :url_categorise_ip_addresses do |t|
                t.string :ip_address, null: false, index: { unique: true }
                t.text :categories, null: false
                t.timestamps
              end
              
              add_index :url_categorise_ip_addresses, :ip_address
              add_index :url_categorise_ip_addresses, :categories
            end
          end
        MIGRATION
      end
    end
  end
end