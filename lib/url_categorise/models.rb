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
        
        serialize :categories, coder: JSON
        
        scope :by_category, ->(category) { where('categories LIKE ?', "%#{category}%") }
        scope :updated_since, ->(time) { where('updated_at > ?', time) }
      end

      class Domain < ActiveRecord::Base
        self.table_name = 'url_categorise_domains'
        
        validates :domain, presence: true, uniqueness: true
        validates :categories, presence: true
        
        serialize :categories, coder: JSON
        
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
        
        serialize :categories, coder: JSON
        
        scope :by_category, ->(category) { where('categories LIKE ?', "%#{category}%") }
        scope :in_subnet, ->(subnet) { where('ip_address LIKE ?', "#{subnet}%") }
        
        def self.categorise(ip)
          record = find_by(ip_address: ip)
          record ? record.categories : []
        end
      end

      class DatasetMetadata < ActiveRecord::Base
        self.table_name = 'url_categorise_dataset_metadata'
        
        validates :source_type, presence: true, inclusion: { in: %w[kaggle csv] }
        validates :identifier, presence: true
        validates :data_hash, presence: true, uniqueness: true
        validates :total_entries, presence: true, numericality: { greater_than: 0 }
        
        serialize :category_mappings, coder: JSON
        serialize :processing_options, coder: JSON
        
        scope :by_source, ->(source) { where(source_type: source) }
        scope :by_identifier, ->(identifier) { where(identifier: identifier) }
        scope :processed_since, ->(time) { where('processed_at > ?', time) }
        
        def kaggle_dataset?
          source_type == 'kaggle'
        end
        
        def csv_dataset?
          source_type == 'csv'
        end
      end

      # Generator for Rails integration
      def self.generate_migration
        <<~MIGRATION
          class CreateUrlCategoriseTables < ActiveRecord::Migration[8.0]
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

              create_table :url_categorise_dataset_metadata do |t|
                t.string :source_type, null: false, index: true
                t.string :identifier, null: false
                t.string :data_hash, null: false, index: { unique: true }
                t.integer :total_entries, null: false
                t.text :category_mappings
                t.text :processing_options
                t.datetime :processed_at
                t.timestamps
              end
              
              add_index :url_categorise_dataset_metadata, :source_type
              add_index :url_categorise_dataset_metadata, :identifier
              add_index :url_categorise_dataset_metadata, :processed_at
            end
          end
        MIGRATION
      end
    end
  end
end