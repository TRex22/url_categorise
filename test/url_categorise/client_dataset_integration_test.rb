require_relative '../test_helper'
require 'json'

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
      host_urls: { test: ['https://example.com/list.txt'] },
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
      host_urls: { test: ['https://example.com/list.txt'] },
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
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    refute_nil client.dataset_processor
    assert_equal 'test_user', client.dataset_processor.username
    assert_equal 'test_key', client.dataset_processor.api_key
    assert client.dataset_processor.kaggle_enabled
  end

  def test_client_initialization_with_kaggle_disabled
    dataset_config = {
      enable_kaggle: false,
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    refute_nil client.dataset_processor
    assert_nil client.dataset_processor.username
    assert_nil client.dataset_processor.api_key
    refute client.dataset_processor.kaggle_enabled
  end

  def test_load_kaggle_dataset_with_kaggle_disabled
    dataset_config = {
      enable_kaggle: false,
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    error = assert_raises(UrlCategorise::Error) do
      client.load_kaggle_dataset('owner', 'dataset')
    end

    assert_match(/Kaggle functionality is disabled/, error.message)
  end

  def test_load_kaggle_dataset_with_cached_data_no_credentials
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets',
      kaggle: {} # No credentials provided
    }

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    # Create cached data manually
    cache_key = 'kaggle_owner_dataset_processed.json'
    cache_file_path = File.join('./test/tmp/datasets', cache_key)
    FileUtils.mkdir_p(File.dirname(cache_file_path))
    cached_data = [{ 'url' => 'https://cached.com', 'category' => 'cached' }]
    File.write(cache_file_path, JSON.pretty_generate(cached_data))

    # Should work even without credentials since data is cached
    result = client.load_kaggle_dataset('owner', 'dataset', use_cache: true, integrate_data: false)

    assert_equal cached_data, result
  end

  def test_load_csv_dataset_without_processor
    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir
    )

    error = assert_raises(UrlCategorise::Error) do
      client.load_csv_dataset('https://example.com/dataset.csv')
    end

    assert_match(/Dataset processor not configured/, error.message)
  end

  def test_load_csv_dataset_with_integration
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    csv_content = "url,category\nhttps://malware.example.com,malware\nhttps://phishing.test.com,phishing"

    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 200, body: csv_content)

    client.load_csv_dataset('https://example.com/dataset.csv')

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
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    csv_content = "url,category\nhttps://malware.example.com,malware"

    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 200, body: csv_content)

    result = client.load_csv_dataset(
      'https://example.com/dataset.csv',
      integrate_data: false
    )

    # Dataset should not be integrated
    refute client.hosts[:malware]&.include?('malware.example.com')

    # But should return the raw dataset
    assert_equal 1, result.length
    assert_equal 'https://malware.example.com', result[0]['url']
  end

  def test_load_kaggle_dataset_without_processor
    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir
    )

    error = assert_raises(UrlCategorise::Error) do
      client.load_kaggle_dataset('owner', 'dataset')
    end

    assert_match(/Dataset processor not configured/, error.message)
  end

  def test_dataset_metadata_without_processor
    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
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
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    csv_content = "url,category\nhttps://example.com,malware"

    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 200, body: csv_content)

    client.load_csv_dataset('https://example.com/dataset.csv')

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
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    csv_content = "url,category\nhttps://example.com,malware"

    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 200, body: csv_content)

    client.load_csv_dataset('https://example.com/dataset.csv')

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
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    csv_content = "website,type\nhttps://bad.example.com,dangerous"

    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 200, body: csv_content)

    category_mappings = {
      url_column: 'website',
      category_column: 'type',
      category_map: { 'dangerous' => 'malware' }
    }

    client.load_csv_dataset(
      'https://example.com/dataset.csv',
      category_mappings: category_mappings
    )

    # Should be categorized as malware, not dangerous
    assert client.hosts[:malware].include?('bad.example.com')
    refute client.hosts[:dangerous]
  end

  def test_dataset_processor_initialization_failure
    # Mock dataset processor to raise error during initialization
    UrlCategorise::DatasetProcessor.stubs(:new).raises(UrlCategorise::Error, 'Test error')

    # Should not raise error, but should set processor to nil
    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
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
      host_urls: { malware: ['https://example.com/malware-list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    # Add dataset data for same category
    csv_content = "url,category\nhttps://dataset-malware.com,malware"

    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 200, body: csv_content)

    client.load_csv_dataset('https://example.com/dataset.csv')

    # Both original and dataset domains should be present
    assert client.hosts[:malware].include?('example-blocked.com') # from original list
    assert client.hosts[:malware].include?('dataset-malware.com') # from dataset

    # Categorization should work for both
    categories1 = client.categorise('https://example-blocked.com')
    assert categories1.include?(:malware)

    categories2 = client.categorise('https://dataset-malware.com')
    assert categories2.include?(:malware)
  end

  def test_auto_load_datasets_disabled_by_default
    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir
    )

    assert_equal false, client.auto_load_datasets
  end

  def test_auto_load_datasets_with_no_processor
    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      auto_load_datasets: true
    )

    # Should not crash when no dataset processor is available
    assert_equal true, client.auto_load_datasets
    assert_nil client.dataset_processor
  end

  def test_auto_load_datasets_from_constants
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets',
      kaggle: {
        username: 'test_user',
        api_key: 'test_key'
      }
    }

    # Mock Kaggle API responses
    kaggle_zip_content = create_mock_kaggle_zip
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/shaurov/website-classification-using-url')
      .to_return(status: 200, body: kaggle_zip_content)

    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/hetulmehta/website-classification')
      .to_return(status: 200, body: kaggle_zip_content)

    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/shawon10/url-classification-dataset-dmoz')
      .to_return(status: 200, body: kaggle_zip_content)

    # Mock CSV dataset response
    csv_content = "url,category\nhttps://csv-dataset-malware.com,malware\nhttps://csv-dataset-phishing.com,phishing"
    stub_request(:get, 'https://query.data.world/s/zackomeddpgotrp3yel66aphvvlcuq?dws=00000')
      .to_return(status: 200, body: csv_content)

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config,
      auto_load_datasets: true
    )

    # Should have loaded datasets automatically
    refute_nil client.dataset_processor
    assert_equal true, client.auto_load_datasets

    # Should have dataset categories with some domains
    refute_empty client.dataset_categories
    assert client.count_of_dataset_hosts > 0

    # Should have some domains from the CSV dataset
    assert client.hosts[:malware]&.include?('csv-dataset-malware.com')
    assert client.hosts[:phishing]&.include?('csv-dataset-phishing.com')
  end

  def test_auto_load_datasets_error_handling
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets',
      kaggle: {
        username: 'test_user',
        api_key: 'test_key'
      }
    }

    # Mock some datasets to fail
    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/shaurov/website-classification-using-url')
      .to_return(status: 404, body: 'Not Found')

    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/hetulmehta/website-classification')
      .to_return(status: 403, body: 'Forbidden')

    stub_request(:get, 'https://www.kaggle.com/api/v1/datasets/download/shawon10/url-classification-dataset-dmoz')
      .to_return(status: 200, body: create_mock_kaggle_zip)

    stub_request(:get, 'https://query.data.world/s/zackomeddpgotrp3yel66aphvvlcuq?dws=00000')
      .to_return(status: 200, body: "url,category\nhttps://working-dataset.com,malware")

    # Should not crash even if some datasets fail
    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config,
      auto_load_datasets: true
    )

    # Should still work and load the successful datasets
    refute_nil client.dataset_processor
    assert client.hosts[:malware]&.include?('working-dataset.com')
  end

  def test_auto_load_datasets_with_cached_data
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }

    # Create cached data for one of the Kaggle datasets
    cache_key = 'kaggle_shaurov_website-classification-using-url_processed.json'
    cache_file_path = File.join('./test/tmp/datasets', cache_key)
    FileUtils.mkdir_p(File.dirname(cache_file_path))
    cached_data = [
      { 'url' => 'https://cached-kaggle-malware.com', 'category' => 'malware' },
      { 'url' => 'https://cached-kaggle-phishing.com', 'category' => 'phishing' }
    ]
    File.write(cache_file_path, JSON.pretty_generate(cached_data))

    # Mock CSV dataset (should still be downloaded since not cached)
    csv_content = "url,category\nhttps://csv-malware.com,malware"
    stub_request(:get, 'https://query.data.world/s/zackomeddpgotrp3yel66aphvvlcuq?dws=00000')
      .to_return(status: 200, body: csv_content)

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config,
      auto_load_datasets: true
    )

    # Should load from cache for Kaggle dataset and download CSV dataset
    assert client.hosts[:malware]&.include?('cached-kaggle-malware.com')
    assert client.hosts[:phishing]&.include?('cached-kaggle-phishing.com')
    assert client.hosts[:malware]&.include?('csv-malware.com')
  end

  def test_reload_with_datasets_preserves_auto_loaded_data
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }

    # Create cached data
    cache_key = 'kaggle_shaurov_website-classification-using-url_processed.json'
    cache_file_path = File.join('./test/tmp/datasets', cache_key)
    FileUtils.mkdir_p(File.dirname(cache_file_path))
    cached_data = [{ 'url' => 'https://auto-loaded-domain.com', 'category' => 'malware' }]
    File.write(cache_file_path, JSON.pretty_generate(cached_data))

    stub_request(:get, 'https://query.data.world/s/zackomeddpgotrp3yel66aphvvlcuq?dws=00000')
      .to_return(status: 200, body: "url,category\nhttps://csv-domain.com,malware")

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config,
      auto_load_datasets: true
    )

    # Verify auto-loaded data is present
    assert client.hosts[:malware]&.include?('auto-loaded-domain.com')
    assert client.hosts[:malware]&.include?('csv-domain.com')

    # Add manual data
    client.hosts[:manual_test] = ['manual.example.com']

    # Reload should preserve auto-loaded data but remove manual additions
    reloaded_client = client.reload_with_datasets

    assert_equal client.object_id, reloaded_client.object_id
    assert client.hosts[:malware]&.include?('auto-loaded-domain.com') # auto-loaded preserved
    assert client.hosts[:malware]&.include?('csv-domain.com') # auto-loaded preserved
    refute client.hosts[:manual_test] # manual data removed
  end

  private

  def create_mock_kaggle_zip
    # Create a simple ZIP file containing a CSV for testing
    zip_buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry('dataset.csv')
      zip.write("url,category\nhttps://kaggle-malware.com,malware\nhttps://kaggle-phishing.com,phishing")
    end
    zip_buffer.string
  end
end
