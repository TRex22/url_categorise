require_relative '../test_helper'

class DatasetProcessorTest < Minitest::Test
  def setup
    @processor = UrlCategorise::DatasetProcessor.new(
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/cache'
    )
    
    FileUtils.mkdir_p('./test/tmp/downloads')
    FileUtils.mkdir_p('./test/tmp/cache')
    
    # Clean up from any previous tests
    FileUtils.rm_rf(Dir.glob('./test/tmp/**/*'))
  end

  def teardown
    FileUtils.rm_rf('./test/tmp') if Dir.exist?('./test/tmp')
  end

  def test_initialization_with_default_paths
    processor = UrlCategorise::DatasetProcessor.new
    refute_nil processor
    assert_equal './downloads', processor.download_path
    assert_equal './cache', processor.cache_path
    assert_equal 30, processor.timeout
  end

  def test_initialization_with_custom_paths
    processor = UrlCategorise::DatasetProcessor.new(
      download_path: '/custom/downloads',
      cache_path: '/custom/cache',
      timeout: 60
    )
    
    assert_equal '/custom/downloads', processor.download_path
    assert_equal '/custom/cache', processor.cache_path
    assert_equal 60, processor.timeout
  end

  def test_initialization_with_kaggle_credentials
    processor = UrlCategorise::DatasetProcessor.new(
      username: 'test_user',
      api_key: 'test_key'
    )
    
    assert_equal 'test_user', processor.username
    assert_equal 'test_key', processor.api_key
  end

  def test_initialization_with_credentials_file
    # Create temporary credentials file
    credentials_file = './test/tmp/kaggle.json'
    File.write(credentials_file, { username: 'file_user', key: 'file_key' }.to_json)
    
    processor = UrlCategorise::DatasetProcessor.new(credentials_file: credentials_file)
    assert_equal 'file_user', processor.username
    assert_equal 'file_key', processor.api_key
  end

  def test_initialization_with_environment_variables
    ENV['KAGGLE_USERNAME'] = 'env_user'
    ENV['KAGGLE_KEY'] = 'env_key'
    
    processor = UrlCategorise::DatasetProcessor.new
    assert_equal 'env_user', processor.username
    assert_equal 'env_key', processor.api_key
    
    ENV.delete('KAGGLE_USERNAME')
    ENV.delete('KAGGLE_KEY')
  end

  def test_process_csv_dataset_success
    csv_content = "url,category\nhttps://example.com,malware\nhttps://test.com,phishing"
    
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 200, body: csv_content)
    
    result = @processor.process_csv_dataset("https://example.com/dataset.csv")
    
    assert_equal 2, result.length
    assert_equal "https://example.com", result[0]['url']
    assert_equal "malware", result[0]['category']
    assert_equal "https://test.com", result[1]['url']
    assert_equal "phishing", result[1]['category']
  end

  def test_process_csv_dataset_with_caching
    csv_content = "url,category\nhttps://example.com,malware"
    
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 200, body: csv_content)
    
    # First request should fetch from network
    result1 = @processor.process_csv_dataset(
      "https://example.com/dataset.csv",
      use_cache: true
    )
    
    # Second request should fetch from cache
    result2 = @processor.process_csv_dataset(
      "https://example.com/dataset.csv",
      use_cache: true
    )
    
    assert_equal result1, result2
    assert_requested :get, "https://example.com/dataset.csv", times: 1
  end

  def test_process_csv_dataset_network_error
    stub_request(:get, "https://example.com/dataset.csv")
      .to_return(status: 500)
    
    error = assert_raises(UrlCategorise::Error) do
      @processor.process_csv_dataset("https://example.com/dataset.csv")
    end
    
    assert_match(/Failed to download CSV dataset/, error.message)
  end

  def test_process_kaggle_dataset_without_credentials
    processor = UrlCategorise::DatasetProcessor.new(
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/cache'
    )
    
    error = assert_raises(UrlCategorise::Error) do
      processor.process_kaggle_dataset("owner", "dataset")
    end
    
    assert_match(/Kaggle credentials required/, error.message)
  end

  def test_generate_dataset_hash
    data = [{ 'url' => 'example.com', 'category' => 'test' }]
    hash1 = @processor.generate_dataset_hash(data)
    hash2 = @processor.generate_dataset_hash(data)
    
    assert_equal hash1, hash2
    assert_equal 64, hash1.length # SHA256 hex length
    
    # Different data should produce different hash
    different_data = [{ 'url' => 'different.com', 'category' => 'test' }]
    hash3 = @processor.generate_dataset_hash(different_data)
    refute_equal hash1, hash3
  end

  def test_integrate_dataset_into_categorization_with_array
    dataset = [
      { 'url' => 'https://malware.example.com', 'category' => 'malware' },
      { 'url' => 'https://phishing.example.com', 'category' => 'phishing' },
      { 'domain' => 'spam.example.com', 'type' => 'spam' }
    ]
    
    result = @processor.integrate_dataset_into_categorization(dataset)
    
    assert result[:malware].include?('malware.example.com')
    assert result[:phishing].include?('phishing.example.com')
    assert result[:spam].include?('spam.example.com')
    assert result[:_metadata]
    assert result[:_metadata][:total_entries] > 0
  end

  def test_integrate_dataset_into_categorization_with_hash
    dataset = {
      'file1' => [
        { 'url' => 'https://malware.example.com', 'category' => 'malware' }
      ],
      'file2' => [
        { 'url' => 'https://phishing.example.com', 'category' => 'phishing' }
      ]
    }
    
    result = @processor.integrate_dataset_into_categorization(dataset)
    
    assert result[:malware].include?('malware.example.com')
    assert result[:phishing].include?('phishing.example.com')
    assert result[:_metadata]
  end

  def test_integrate_dataset_with_custom_category_mappings
    dataset = [
      { 'website' => 'https://example.com', 'classification' => 'bad' }
    ]
    
    category_mappings = {
      url_column: 'website',
      category_column: 'classification',
      category_map: { 'bad' => 'malware' }
    }
    
    result = @processor.integrate_dataset_into_categorization(dataset, category_mappings)
    
    assert result[:malware].include?('example.com')
  end

  def test_domain_extraction_from_urls
    # Test full URLs
    assert_equal 'example.com', extract_domain_helper('https://example.com/path')
    assert_equal 'example.com', extract_domain_helper('http://www.example.com')
    assert_equal 'subdomain.example.com', extract_domain_helper('https://subdomain.example.com')
    
    # Test domain-only entries
    assert_equal 'example.com', extract_domain_helper('example.com')
    assert_equal 'example.com', extract_domain_helper('www.example.com')
    
    # Test malformed URLs
    assert_equal 'example.com', extract_domain_helper('example.com/path')
    assert_nil extract_domain_helper('')
    assert_nil extract_domain_helper(nil)
  end

  def test_cache_key_generation
    key1 = @processor.send(:generate_cache_key, 'owner/dataset', :kaggle)
    key2 = @processor.send(:generate_cache_key, 'https://example.com/data.csv', :csv)
    
    assert_equal 'kaggle_owner_dataset_processed.json', key1
    assert_equal 'csv_https___example_com_data_csv_processed.json', key2
  end

  def test_csv_parsing_with_malformed_data
    malformed_csv = "url,category\nexample.com,malware\nbroken line without comma"
    
    error = assert_raises(UrlCategorise::Error) do
      @processor.send(:parse_csv_content, malformed_csv)
    end
    
    assert_match(/Failed to parse CSV content/, error.message)
  end

  def test_url_column_detection
    sample_row = {
      'website_url' => 'https://example.com',
      'domain_name' => 'example.com',
      'category' => 'malware',
      'other_field' => 'value'
    }
    
    detected = @processor.send(:detect_url_columns, sample_row)
    assert detected.include?('website_url')
    assert detected.include?('domain_name')
    refute detected.include?('category')
    refute detected.include?('other_field')
  end

  def test_category_column_detection
    sample_row = {
      'url' => 'https://example.com',
      'category' => 'malware',
      'classification_type' => 'security',
      'label' => 'malicious',
      'other_field' => 'value'
    }
    
    detected = @processor.send(:detect_category_columns, sample_row)
    assert detected.include?('category')
    assert detected.include?('classification_type')
    assert detected.include?('label')
    refute detected.include?('url')
    refute detected.include?('other_field')
  end

  def test_category_name_mapping
    # Test with explicit mapping
    category_mappings = {
      category_map: { 'bad' => 'malware', 'suspicious' => 'phishing' }
    }
    
    assert_equal 'malware', @processor.send(:map_category_name, 'bad', category_mappings)
    assert_equal 'phishing', @processor.send(:map_category_name, 'suspicious', category_mappings)
    
    # Test sanitization of unmapped names
    assert_equal 'social_media', @processor.send(:map_category_name, 'Social Media!', {})
    assert_equal 'test_category', @processor.send(:map_category_name, 'Test-Category@#', {})
    assert_equal 'dataset_category', @processor.send(:map_category_name, '!!!', {})
  end

  private

  def extract_domain_helper(url)
    @processor.send(:extract_domain, url)
  end
end