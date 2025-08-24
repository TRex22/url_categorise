require_relative '../test_helper'

class ClientDatasetIntegrationTest < Minitest::Test
  def setup
    @cache_dir = './test/tmp/cache'
    FileUtils.mkdir_p(@cache_dir)
    
    # Clean up from any previous tests
    FileUtils.rm_rf(Dir.glob('./test/tmp/**/*'))
    
    # Mock data for default host URLs to avoid network calls
    stub_request(:head, /.*/)
      .to_return(status: 200)
    stub_request(:get, /.*/)
      .to_return(status: 200, body: "0.0.0.0 example-blocked.com\n0.0.0.0 test-blocked.com")
  end

  def teardown
    FileUtils.rm_rf('./test/tmp') if Dir.exist?('./test/tmp')
  end

  def test_client_initialization_without_dataset_config
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir
    )
    
    assert_nil client.dataset_processor
  end

  def test_client_initialization_with_dataset_config
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }
    
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )
    
    refute_nil client.dataset_processor
    assert_equal './test/tmp/downloads', client.dataset_processor.download_path
    assert_equal './test/tmp/datasets', client.dataset_processor.cache_path
  end

  def test_client_initialization_with_kaggle_config
    dataset_config = {
      kaggle: {
        username: 'test_user',
        api_key: 'test_key'
      }
    }
    
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )
    
    refute_nil client.dataset_processor
    assert_equal 'test_user', client.dataset_processor.username
    assert_equal 'test_key', client.dataset_processor.api_key
  end

  def test_load_csv_dataset_without_processor
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir
    )
    
    error = assert_raises(UrlCategorise::Error) do
      client.load_csv_dataset("https://example.com/dataset.csv")
    end
    
    assert_match(/Dataset processor not configured/, error.message)
  end

  def test_load_csv_dataset_with_integration
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }
    
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )
    
    csv_content = "url,category\nhttps://malware.example.com,malware\nhttps://phishing.test.com,phishing"
    
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 200, body: csv_content)
    
    result = client.load_csv_dataset("https://example.com/dataset.csv")
    
    # Check that dataset was integrated into client's hosts
    assert client.hosts[:malware].include?('malware.example.com')
    assert client.hosts[:phishing].include?('phishing.test.com')
    
    # Check that categorization works
    categories = client.categorise('https://malware.example.com')
    assert categories.include?(:malware)
    
    categories = client.categorise('https://phishing.test.com')
    assert categories.include?(:phishing)
  end

  def test_load_csv_dataset_without_integration
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }
    
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )
    
    csv_content = "url,category\nhttps://malware.example.com,malware"
    
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 200, body: csv_content)
    
    result = client.load_csv_dataset(
      "https://example.com/dataset.csv",
      integrate_data: false
    )
    
    # Dataset should not be integrated
    refute client.hosts[:malware]&.include?('malware.example.com')
    
    # But should return the raw dataset
    assert_equal 1, result.length
    assert_equal "https://malware.example.com", result[0]['url']
  end

  def test_load_kaggle_dataset_without_processor
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir
    )
    
    error = assert_raises(UrlCategorise::Error) do
      client.load_kaggle_dataset("owner", "dataset")
    end
    
    assert_match(/Dataset processor not configured/, error.message)
  end

  def test_dataset_metadata_without_processor
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir
    )
    
    metadata = client.dataset_metadata
    assert_empty metadata
  end

  def test_dataset_metadata_with_processor
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }
    
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )
    
    csv_content = "url,category\nhttps://example.com,malware"
    
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 200, body: csv_content)
    
    client.load_csv_dataset("https://example.com/dataset.csv")
    
    metadata = client.dataset_metadata
    refute_empty metadata
    
    # Should have one dataset with metadata
    data_hash = metadata.keys.first
    assert metadata[data_hash][:processed_at]
    assert metadata[data_hash][:total_entries]
    assert metadata[data_hash][:data_hash]
  end

  def test_reload_with_datasets
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }
    
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )
    
    csv_content = "url,category\nhttps://example.com,malware"
    
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 200, body: csv_content)
    
    client.load_csv_dataset("https://example.com/dataset.csv")
    
    # Add some more data to hosts manually
    client.hosts[:manual_test] = ['manual.example.com']
    
    # Reload should refresh all data
    reloaded_client = client.reload_with_datasets
    
    # Should be same object
    assert_equal client.object_id, reloaded_client.object_id
    
    # Should still have dataset data
    assert client.hosts[:malware].include?('example.com')
    
    # But manual data should be gone
    refute client.hosts[:manual_test]
  end

  def test_custom_category_mappings
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }
    
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )
    
    csv_content = "website,type\nhttps://bad.example.com,dangerous"
    
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 200, body: csv_content)
    
    category_mappings = {
      url_column: 'website',
      category_column: 'type',
      category_map: { 'dangerous' => 'malware' }
    }
    
    client.load_csv_dataset(
      "https://example.com/dataset.csv",
      category_mappings: category_mappings
    )
    
    # Should be categorized as malware, not dangerous
    assert client.hosts[:malware].include?('bad.example.com')
    refute client.hosts[:dangerous]
  end

  def test_dataset_processor_initialization_failure
    # Mock dataset processor to raise error during initialization
    UrlCategorise::DatasetProcessor.stubs(:new).raises(UrlCategorise::Error, "Test error")
    
    # Should not raise error, but should set processor to nil
    client = UrlCategorise::Client.new(
      host_urls: { test: ["https://example.com/list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: { download_path: './test/tmp' }
    )
    
    assert_nil client.dataset_processor
  end

  def test_integration_with_existing_categorization
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }
    
    # Create client with some existing host data
    client = UrlCategorise::Client.new(
      host_urls: { malware: ["https://example.com/malware-list.txt"] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )
    
    # Add dataset data for same category
    csv_content = "url,category\nhttps://dataset-malware.com,malware"
    
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 200, body: csv_content)
    
    client.load_csv_dataset("https://example.com/dataset.csv")
    
    # Both original and dataset domains should be present
    assert client.hosts[:malware].include?('example-blocked.com') # from original list
    assert client.hosts[:malware].include?('dataset-malware.com') # from dataset
    
    # Categorization should work for both
    categories1 = client.categorise('https://example-blocked.com')
    assert categories1.include?(:malware)
    
    categories2 = client.categorise('https://dataset-malware.com')
    assert categories2.include?(:malware)
  end
end