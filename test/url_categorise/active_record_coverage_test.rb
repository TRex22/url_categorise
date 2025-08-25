require 'test_helper'

class ActiveRecordCoverageTest < Minitest::Test
  def setup
    WebMock.reset!
    
    # Set up in-memory SQLite database for testing
    if defined?(ActiveRecord)
      ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: ':memory:'
      )
      
      # Create the tables using the migration
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
          t.text :categories, null: false, index: true
          t.timestamps
        end

        create_table :url_categorise_ip_addresses do |t|
          t.string :ip_address, null: false, index: { unique: true }
          t.text :categories, null: false, index: true
          t.timestamps
        end

        create_table :url_categorise_dataset_metadata do |t|
          t.string :source_type, null: false, index: true
          t.string :identifier, null: false, index: true
          t.string :data_hash, null: false, index: { unique: true }
          t.integer :total_entries, null: false
          t.text :category_mappings
          t.text :processing_options
          t.datetime :processed_at, index: true
          t.timestamps
        end
      end
    end
  end

  def test_activerecord_unavailable_error
    # Test when ActiveRecord is not available
    UrlCategorise::Models.stub(:available?, false) do
      assert_raises(RuntimeError, 'ActiveRecord not available') do
        UrlCategorise::ActiveRecordClient.new(host_urls: {})
      end
    end
  end

  def test_activerecord_client_without_database_usage
    skip "ActiveRecord not available for testing" unless defined?(ActiveRecord)
    
    WebMock.stub_request(:get, 'http://example.com/test.txt')
      .to_return(status: 200, body: "test.com\n")

    # Test with use_database: false
    client = UrlCategorise::ActiveRecordClient.new(
      host_urls: { test: ['http://example.com/test.txt'] },
      use_database: false
    )

    # Should use memory-based categorization
    categories = client.categorise('test.com')
    assert_includes categories, :test

    # Database methods should return empty/default values
    assert_empty client.database_stats
  end

  def test_activerecord_client_with_database_usage
    skip "ActiveRecord not available for testing" unless defined?(ActiveRecord)
    
    WebMock.stub_request(:get, 'http://example.com/test.txt')
      .to_return(status: 200, body: "test.com\nother.com\n")

    WebMock.stub_request(:get, 'http://example.com/ip-test.txt')
      .to_return(status: 200, body: "192.168.1.1\n10.0.0.1\n")

    # Test with database usage
    client = UrlCategorise::ActiveRecordClient.new(
      host_urls: { 
        test_domain: ['http://example.com/test.txt'],
        sanctions_ips: ['http://example.com/ip-test.txt']
      },
      use_database: true
    )

    # Test database-backed categorization
    categories = client.categorise('test.com')
    assert_includes categories, 'test_domain'  # ActiveRecord returns strings, not symbols

    # Test IP categorization
    ip_categories = client.categorise_ip('192.168.1.1')
    assert_includes ip_categories, 'sanctions_ips'  # ActiveRecord returns strings, not symbols

    # Test database stats
    stats = client.database_stats
    assert stats[:domains] > 0
    assert stats[:ip_addresses] > 0
    assert stats[:list_metadata] > 0

    # Test update database method
    client.update_database
  end

  def test_models_categorise_methods
    skip "ActiveRecord not available for testing" unless defined?(ActiveRecord)

    # Test Domain.categorise
    UrlCategorise::Models::Domain.create!(domain: 'test.com', categories: ['malware'])
    categories = UrlCategorise::Models::Domain.categorise('test.com')
    assert_includes categories, 'malware'

    # Test with www prefix removal
    categories_www = UrlCategorise::Models::Domain.categorise('www.test.com')
    assert_includes categories_www, 'malware'

    # Test IpAddress.categorise
    UrlCategorise::Models::IpAddress.create!(ip_address: '192.168.1.1', categories: ['sanctions'])
    ip_categories = UrlCategorise::Models::IpAddress.categorise('192.168.1.1')
    assert_includes ip_categories, 'sanctions'
  end

  def test_model_scopes
    skip "ActiveRecord not available for testing" unless defined?(ActiveRecord)

    # Test Domain scopes
    UrlCategorise::Models::Domain.create!(domain: 'malware.com', categories: ['malware'])
    UrlCategorise::Models::Domain.create!(domain: 'phishing.com', categories: ['phishing'])
    
    malware_domains = UrlCategorise::Models::Domain.by_category('malware')
    assert_equal 1, malware_domains.count

    search_results = UrlCategorise::Models::Domain.search('malware')
    assert_equal 1, search_results.count

    # Test IpAddress scopes
    UrlCategorise::Models::IpAddress.create!(ip_address: '10.0.0.1', categories: ['sanctions'])
    UrlCategorise::Models::IpAddress.create!(ip_address: '10.0.0.2', categories: ['malware'])

    sanctions_ips = UrlCategorise::Models::IpAddress.by_category('sanctions')
    assert_equal 1, sanctions_ips.count

    subnet_ips = UrlCategorise::Models::IpAddress.in_subnet('10.0')
    assert_equal 2, subnet_ips.count
  end

  def test_models_available_method
    if defined?(ActiveRecord)
      assert UrlCategorise::Models.available?
    else
      refute UrlCategorise::Models.available?
    end
  end

  def test_generate_migration_method
    skip "ActiveRecord not available for testing" unless defined?(ActiveRecord)
    
    migration = UrlCategorise::Models.generate_migration
    assert_instance_of String, migration
    assert_includes migration, 'CreateUrlCategoriseTables'
    assert_includes migration, 'url_categorise_domains'
    assert_includes migration, 'url_categorise_ip_addresses'
    assert_includes migration, 'url_categorise_list_metadata'
    assert_includes migration, 'ActiveRecord::Migration[8.0]'
  end
end