require_relative '../test_helper'

# Only run ActiveRecord tests if ActiveRecord is available
if defined?(ActiveRecord)
  # Setup in-memory SQLite database for testing
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: ':memory:'
  )

  class ActiveRecordDatasetTest < Minitest::Test
    def setup
      @cache_dir = './test/tmp/cache'
      FileUtils.mkdir_p(@cache_dir)
      
      # Clean up from any previous tests
      FileUtils.rm_rf(Dir.glob('./test/tmp/**/*'))
      
      # Create the database tables
      create_test_tables
      
      # Mock data for default host URLs to avoid network calls
      stub_request(:head, /.*/)
        .to_return(status: 200)
      stub_request(:get, /.*/)
        .to_return(status: 200, body: "0.0.0.0 example-blocked.com\n0.0.0.0 test-blocked.com")
    end

    def teardown
      # Clean up database
      drop_test_tables if ActiveRecord::Base.connection.table_exists?('url_categorise_domains')
      FileUtils.rm_rf('./test/tmp') if Dir.exist?('./test/tmp')
    end

    def test_activerecord_client_with_dataset_config
      dataset_config = {
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/datasets'
      }
      
      client = UrlCategorise::ActiveRecordClient.new(
        host_urls: { test: ["https://example.com/list.txt"] },
        cache_dir: @cache_dir,
        dataset_config: dataset_config,
        use_database: true
      )
      
      refute_nil client.dataset_processor
      assert_equal './test/tmp/downloads', client.dataset_processor.download_path
      assert_equal './test/tmp/datasets', client.dataset_processor.cache_path
    end

    def test_load_csv_dataset_with_database_storage
      dataset_config = {
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/datasets'
      }
      
      client = UrlCategorise::ActiveRecordClient.new(
        host_urls: { test: ["https://example.com/list.txt"] },
        cache_dir: @cache_dir,
        dataset_config: dataset_config,
        use_database: true
      )
      
      csv_content = "url,category\nhttps://malware.example.com,malware\nhttps://phishing.test.com,phishing"
      
      stub_request(:get, "https://example.com/dataset.csv")
        .to_return(status: 200, body: csv_content)
      
      result = client.load_csv_dataset("https://example.com/dataset.csv")
      
      # Check that data was stored in database
      malware_domain = UrlCategorise::Models::Domain.find_by(domain: 'malware.example.com')
      refute_nil malware_domain
      assert malware_domain.categories.include?('malware')
      
      phishing_domain = UrlCategorise::Models::Domain.find_by(domain: 'phishing.test.com')
      refute_nil phishing_domain
      assert phishing_domain.categories.include?('phishing')
      
      # Check dataset metadata was stored
      assert_equal 1, UrlCategorise::Models::DatasetMetadata.count
      
      dataset_metadata = UrlCategorise::Models::DatasetMetadata.first
      assert_equal 'csv', dataset_metadata.source_type
      assert_equal "https://example.com/dataset.csv", dataset_metadata.identifier
      assert_equal 2, dataset_metadata.total_entries
      refute_nil dataset_metadata.data_hash
      refute_nil dataset_metadata.processed_at
    end

    def test_load_kaggle_dataset_with_database_storage
      dataset_config = {
        kaggle: {
          username: 'test_user',
          api_key: 'test_key'
        },
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/datasets'
      }
      
      client = UrlCategorise::ActiveRecordClient.new(
        host_urls: { test: ["https://example.com/list.txt"] },
        cache_dir: @cache_dir,
        dataset_config: dataset_config,
        use_database: true
      )
      
      # Mock Kaggle API response with zip file
      zip_content = create_test_zip_with_csv("url,category\nhttps://kaggle-malware.com,malware")
      
      stub_request(:get, "https://www.kaggle.com/api/v1/datasets/download/owner/dataset")
        .to_return(status: 200, body: zip_content)
      
      result = client.load_kaggle_dataset("owner", "dataset")
      
      # Check that data was stored in database
      domain = UrlCategorise::Models::Domain.find_by(domain: 'kaggle-malware.com')
      refute_nil domain
      assert domain.categories.include?('malware')
      
      # Check dataset metadata was stored
      kaggle_metadata = UrlCategorise::Models::DatasetMetadata.find_by(source_type: 'kaggle')
      refute_nil kaggle_metadata
      assert_equal 'owner/dataset', kaggle_metadata.identifier
    end

    def test_dataset_history
      dataset_config = {
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/datasets'
      }
      
      client = UrlCategorise::ActiveRecordClient.new(
        host_urls: { test: ["https://example.com/list.txt"] },
        cache_dir: @cache_dir,
        dataset_config: dataset_config,
        use_database: true
      )
      
      # Load multiple datasets
      csv_content1 = "url,category\nhttps://example1.com,malware"
      csv_content2 = "url,category\nhttps://example2.com,phishing"
      
      stub_request(:get, "https://example.com/dataset1.csv")
        .to_return(status: 200, body: csv_content1)
      
      stub_request(:get, "https://example.com/dataset2.csv")
        .to_return(status: 200, body: csv_content2)
      
      client.load_csv_dataset("https://example.com/dataset1.csv")
      
      # Wait a moment to ensure different timestamps
      sleep(0.01)
      
      client.load_csv_dataset("https://example.com/dataset2.csv")
      
      # Check dataset history
      history = client.dataset_history(limit: 10)
      assert_equal 2, history.length
      
      # Should be ordered by processed_at descending
      assert history[0][:processed_at] >= history[1][:processed_at]
      
      # Check history filtering by source type
      csv_history = client.dataset_history(source_type: 'csv', limit: 10)
      assert_equal 2, csv_history.length
      
      kaggle_history = client.dataset_history(source_type: 'kaggle', limit: 10)
      assert_equal 0, kaggle_history.length
    end

    def test_database_stats_with_datasets
      dataset_config = {
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/datasets'
      }
      
      client = UrlCategorise::ActiveRecordClient.new(
        host_urls: { test: ["https://example.com/list.txt"] },
        cache_dir: @cache_dir,
        dataset_config: dataset_config,
        use_database: true
      )
      
      csv_content = "url,category\nhttps://example.com,malware"
      
      stub_request(:get, "https://example.com/dataset.csv")
        .to_return(status: 200, body: csv_content)
      
      client.load_csv_dataset("https://example.com/dataset.csv")
      
      stats = client.database_stats
      
      assert stats[:domains] > 0
      assert_equal 1, stats[:dataset_metadata]
      assert stats[:categories] > 0
    end

    def test_dataset_metadata_model_validations
      # Test source_type validation
      metadata = UrlCategorise::Models::DatasetMetadata.new(
        source_type: 'invalid',
        identifier: 'test',
        data_hash: 'hash123',
        total_entries: 1
      )
      
      refute metadata.valid?
      assert metadata.errors[:source_type]
      
      # Test valid source types
      metadata.source_type = 'kaggle'
      assert metadata.valid?
      
      metadata.source_type = 'csv'
      assert metadata.valid?
    end

    def test_dataset_metadata_model_scopes
      # Create test data
      UrlCategorise::Models::DatasetMetadata.create!(
        source_type: 'kaggle',
        identifier: 'owner/dataset',
        data_hash: 'hash1',
        total_entries: 100,
        processed_at: 2.days.ago
      )
      
      UrlCategorise::Models::DatasetMetadata.create!(
        source_type: 'csv',
        identifier: 'https://example.com/data.csv',
        data_hash: 'hash2',
        total_entries: 50,
        processed_at: 1.day.ago
      )
      
      # Test by_source scope
      kaggle_records = UrlCategorise::Models::DatasetMetadata.by_source('kaggle')
      assert_equal 1, kaggle_records.count
      assert_equal 'owner/dataset', kaggle_records.first.identifier
      
      csv_records = UrlCategorise::Models::DatasetMetadata.by_source('csv')
      assert_equal 1, csv_records.count
      assert_equal 'https://example.com/data.csv', csv_records.first.identifier
      
      # Test by_identifier scope
      specific_record = UrlCategorise::Models::DatasetMetadata.by_identifier('owner/dataset')
      assert_equal 1, specific_record.count
      
      # Test processed_since scope
      recent_records = UrlCategorise::Models::DatasetMetadata.processed_since(1.5.days.ago)
      assert_equal 1, recent_records.count
      assert_equal 'csv', recent_records.first.source_type
    end

    def test_dataset_metadata_model_methods
      metadata = UrlCategorise::Models::DatasetMetadata.create!(
        source_type: 'kaggle',
        identifier: 'owner/dataset',
        data_hash: 'hash1',
        total_entries: 100
      )
      
      assert metadata.kaggle_dataset?
      refute metadata.csv_dataset?
      
      metadata.source_type = 'csv'
      metadata.save!
      
      refute metadata.kaggle_dataset?
      assert metadata.csv_dataset?
    end

    def test_store_dataset_metadata_duplicate_handling
      dataset_config = {
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/datasets'
      }
      
      client = UrlCategorise::ActiveRecordClient.new(
        host_urls: { test: ["https://example.com/list.txt"] },
        cache_dir: @cache_dir,
        dataset_config: dataset_config,
        use_database: true
      )
      
      csv_content = "url,category\nhttps://example.com,malware"
      
      stub_request(:get, "https://example.com/dataset.csv")
        .to_return(status: 200, body: csv_content)
      
      # Load same dataset twice
      client.load_csv_dataset("https://example.com/dataset.csv")
      client.load_csv_dataset("https://example.com/dataset.csv")
      
      # Should only have one metadata record (duplicate hash prevention)
      assert_equal 1, UrlCategorise::Models::DatasetMetadata.count
    end

    private

    def create_test_tables
      ActiveRecord::Schema.define do
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

    def drop_test_tables
      ActiveRecord::Schema.define do
        drop_table :url_categorise_list_metadata if table_exists?(:url_categorise_list_metadata)
        drop_table :url_categorise_domains if table_exists?(:url_categorise_domains)
        drop_table :url_categorise_ip_addresses if table_exists?(:url_categorise_ip_addresses)
        drop_table :url_categorise_dataset_metadata if table_exists?(:url_categorise_dataset_metadata)
      end
    end

    def create_test_zip_with_csv(csv_content)
      zip_io = Zip::OutputStream.write_buffer do |zip|
        zip.put_next_entry('test_data.csv')
        zip.write(csv_content)
      end
      zip_io.rewind
      zip_io.string
    end
  end
else
  # Create a dummy test class when ActiveRecord is not available
  class ActiveRecordDatasetTest < Minitest::Test
    def test_activerecord_not_available
      skip "ActiveRecord not available for testing dataset functionality"
    end
  end
end