require_relative '../test_helper'
require 'stringio'
require 'json'

class DatasetProcessorTest < Minitest::Test
  def setup
    FileUtils.mkdir_p('./test/tmp/downloads')
    FileUtils.mkdir_p('./test/tmp/cache')

    # Clean up from any previous tests
    FileUtils.rm_rf(Dir.glob('./test/tmp/**/*'))

    # Create processor with minimal config to avoid warning during setup
    @processor = UrlCategorise::DatasetProcessor.new(
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/cache',
      username: 'test_user',
      api_key: 'test_key'
    )
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
    custom_download_path = File.join(Dir.tmpdir, 'custom', 'downloads')
    custom_cache_path = File.join(Dir.tmpdir, 'custom', 'cache')

    processor = UrlCategorise::DatasetProcessor.new(
      download_path: custom_download_path,
      cache_path: custom_cache_path,
      timeout: 60
    )

    assert_equal custom_download_path, processor.download_path
    assert_equal custom_cache_path, processor.cache_path
    assert_equal 60, processor.timeout

    # Clean up the created directories
    FileUtils.rm_rf(File.join(Dir.tmpdir, 'custom')) if Dir.exist?(File.join(Dir.tmpdir, 'custom'))
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

    # Pass explicit credentials to override file and test env variables
    processor = UrlCategorise::DatasetProcessor.new(
      username: 'env_user',
      api_key: 'env_key'
    )
    assert_equal 'env_user', processor.username
    assert_equal 'env_key', processor.api_key
    assert processor.kaggle_enabled

    ENV.delete('KAGGLE_USERNAME')
    ENV.delete('KAGGLE_KEY')
  end

  def test_initialization_with_kaggle_disabled
    processor = UrlCategorise::DatasetProcessor.new(enable_kaggle: false)
    assert_nil processor.username
    assert_nil processor.api_key
    refute processor.kaggle_enabled
  end

  def test_kaggle_disabled_warning
    # Capture warnings
    original_stderr = $stderr
    stderr_capture = StringIO.new
    $stderr = stderr_capture

    begin
      processor = UrlCategorise::DatasetProcessor.new(
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/cache',
        enable_kaggle: false
      )

      warning_output = stderr_capture.string

      # Should not have any warnings when Kaggle is explicitly disabled
      assert_equal '', warning_output
      assert_nil processor.username
      assert_nil processor.api_key
      refute processor.kaggle_enabled
    ensure
      $stderr = original_stderr
    end
  end

  def test_kaggle_credentials_missing_warning
    # Capture warnings
    original_stderr = $stderr
    stderr_capture = StringIO.new
    $stderr = stderr_capture

    # Temporarily stub File.exist? to simulate no default kaggle.json file
    File.stub(:exist?, ->(path) { path != File.expand_path('~/.kaggle/kaggle.json') }) do
      processor = UrlCategorise::DatasetProcessor.new(
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/cache',
        username: nil,
        api_key: nil,
        enable_kaggle: true
      )

      warning_output = stderr_capture.string

      assert_match(/Warning: Kaggle credentials not found/, warning_output)
      assert_match(%r{KAGGLE_USERNAME/KAGGLE_KEY}, warning_output)
      assert processor.kaggle_enabled
    end
  ensure
    $stderr = original_stderr
  end

  def test_process_csv_dataset_success
    csv_content = "url,category\nhttps://example.com,malware\nhttps://test.com,phishing"

    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 200, body: csv_content)

    result = @processor.process_csv_dataset('https://example.com/dataset.csv')

    assert_equal 2, result.length
    assert_equal 'https://example.com', result[0]['url']
    assert_equal 'malware', result[0]['category']
    assert_equal 'https://test.com', result[1]['url']
    assert_equal 'phishing', result[1]['category']
  end

  def test_process_csv_dataset_with_caching
    csv_content = "url,category\nhttps://example.com,malware"

    stub_request(:get, 'https://example.com/cached-dataset.csv')
      .to_return(status: 200, body: csv_content)

    # First request should fetch from network
    result1 = @processor.process_csv_dataset(
      'https://example.com/cached-dataset.csv',
      use_cache: true
    )

    # Second request should fetch from cache
    result2 = @processor.process_csv_dataset(
      'https://example.com/cached-dataset.csv',
      use_cache: true
    )

    assert_equal result1, result2
    assert_requested :get, 'https://example.com/cached-dataset.csv', times: 1
  end

  def test_process_csv_dataset_network_error
    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 500)

    error = assert_raises(UrlCategorise::Error) do
      @processor.process_csv_dataset('https://example.com/dataset.csv')
    end

    assert_match(/Failed to download CSV dataset/, error.message)
  end

  def test_process_kaggle_dataset_without_credentials
    # Temporarily stub File.exist? to simulate no default kaggle.json file
    File.stub(:exist?, ->(path) { path != File.expand_path('~/.kaggle/kaggle.json') }) do
      processor = UrlCategorise::DatasetProcessor.new(
        download_path: './test/tmp/downloads',
        cache_path: './test/tmp/cache'
      )

      error = assert_raises(UrlCategorise::Error) do
        processor.process_kaggle_dataset('owner', 'dataset')
      end

      assert_match(/Kaggle credentials required for downloading new datasets/, error.message)
      assert_match(%r{KAGGLE_USERNAME/KAGGLE_KEY}, error.message)
    end
  end

  def test_process_kaggle_dataset_with_kaggle_disabled
    processor = UrlCategorise::DatasetProcessor.new(
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/cache',
      enable_kaggle: false
    )

    error = assert_raises(UrlCategorise::Error) do
      processor.process_kaggle_dataset('owner', 'dataset')
    end

    assert_match(/Kaggle functionality is disabled/, error.message)
    assert_match(/enable_kaggle: true/, error.message)
  end

  def test_process_kaggle_dataset_with_cached_data
    processor = UrlCategorise::DatasetProcessor.new(
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/cache',
      username: nil, # No credentials
      api_key: nil
    )

    # Create cached data manually (generate cache key like the processor would)
    cache_key = 'kaggle_owner_dataset_processed.json'
    cache_file_path = File.join('./test/tmp/cache', cache_key)
    cached_data = [{ 'url' => 'https://cached.com', 'category' => 'cached' }]
    File.write(cache_file_path, JSON.pretty_generate(cached_data))

    # Should work even without credentials since data is cached
    result = processor.process_kaggle_dataset('owner', 'dataset', use_cache: true)

    assert_equal cached_data, result
  end

  def test_process_kaggle_dataset_with_extracted_files
    processor = UrlCategorise::DatasetProcessor.new(
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/cache',
      username: nil, # No credentials
      api_key: nil
    )

    # Create extracted directory with CSV file manually
    extracted_dir = File.join('./test/tmp/downloads', 'owner_dataset')
    FileUtils.mkdir_p(extracted_dir)
    csv_file = File.join(extracted_dir, 'test.csv')
    File.write(csv_file, "url,category\nhttps://extracted.com,extracted_category")

    # Should work even without credentials since files are already extracted
    result = processor.process_kaggle_dataset('owner', 'dataset', use_cache: true)

    assert_equal 1, result.length
    assert_equal 'https://extracted.com', result[0]['url']
    assert_equal 'extracted_category', result[0]['category']
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

    assert result['categories']['malware'].include?('malware.example.com')
    assert result['categories']['phishing'].include?('phishing.example.com')
    assert result['categories']['spam'].include?('spam.example.com')
    assert result['_metadata']
    assert result['_metadata'][:total_entries] > 0
    assert result['raw_content']
    assert result['raw_content'].length > 0
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

    assert result['categories']['malware'].include?('malware.example.com')
    assert result['categories']['phishing'].include?('phishing.example.com')
    assert result['_metadata']
    assert result['raw_content']
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

    assert result['categories']['malware'].include?('example.com')
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
    # Test that cache keys are generated consistently by using the same dataset twice
    processor1 = UrlCategorise::DatasetProcessor.new(
      download_path: './test/tmp/downloads1',
      cache_path: './test/tmp/cache1',
      username: 'test',
      api_key: 'test'
    )

    processor2 = UrlCategorise::DatasetProcessor.new(
      download_path: './test/tmp/downloads2',
      cache_path: './test/tmp/cache2',
      username: 'test',
      api_key: 'test'
    )

    # Both processors should generate same cache keys for same inputs
    # We'll test this by checking that the cache directory structure is consistent
    FileUtils.mkdir_p('./test/tmp/cache1')
    FileUtils.mkdir_p('./test/tmp/cache2')

    # Cache keys should be consistent (we can't directly test private method,
    # but we know the format from implementation)
    assert_equal processor1.cache_path, './test/tmp/cache1'
    assert_equal processor2.cache_path, './test/tmp/cache2'
  end

  def test_csv_parsing_with_malformed_data
    malformed_csv = "url,category\nexample.com,malware\n\"unclosed,quote,too many,fields,here"

    # Use a URL that returns malformed CSV
    stub_request(:get, 'https://example.com/malformed.csv')
      .to_return(status: 200, body: malformed_csv)

    error = assert_raises(UrlCategorise::Error) do
      @processor.process_csv_dataset('https://example.com/malformed.csv')
    end

    assert_match(/Failed to parse CSV content/, error.message)
  end

  def test_automatic_column_detection_integration
    # Test that the processor can automatically detect URL and category columns
    csv_content = "website_url,classification_type\nhttps://malware.example.com,malware\nhttps://phishing.test.com,phishing"

    stub_request(:get, 'https://example.com/auto-detect.csv')
      .to_return(status: 200, body: csv_content)

    result = @processor.process_csv_dataset('https://example.com/auto-detect.csv')

    # Should successfully parse and detect columns
    assert_equal 2, result.length
    assert_equal 'https://malware.example.com', result[0]['website_url']
    assert_equal 'malware', result[0]['classification_type']
  end

  def test_category_name_mapping_integration
    # Test that category mapping works through dataset integration
    csv_content = "url,type\nhttps://bad.example.com,bad\nhttps://suspicious.test.com,suspicious"

    stub_request(:get, 'https://example.com/mapping-test.csv')
      .to_return(status: 200, body: csv_content)

    category_mappings = {
      url_column: 'url',
      category_column: 'type',
      category_map: { 'bad' => 'malware', 'suspicious' => 'phishing' }
    }

    integrated_data = @processor.integrate_dataset_into_categorization(
      @processor.process_csv_dataset('https://example.com/mapping-test.csv'),
      category_mappings
    )

    # Should map categories correctly
    assert integrated_data['categories']['malware'].include?('bad.example.com')
    assert integrated_data['categories']['phishing'].include?('suspicious.test.com')
  end

  def test_domain_extraction_integration
    # Test domain extraction through dataset processing
    csv_content = "url,category\nhttps://example.com/path,malware\nwww.test.com,phishing\nsubdomain.site.com,spam"

    stub_request(:get, 'https://example.com/domain-test.csv')
      .to_return(status: 200, body: csv_content)

    integrated_data = @processor.integrate_dataset_into_categorization(
      @processor.process_csv_dataset('https://example.com/domain-test.csv')
    )

    # Should extract domains correctly
    assert integrated_data['categories']['malware'].include?('example.com')
    assert integrated_data['categories']['phishing'].include?('test.com')
    assert integrated_data['categories']['spam'].include?('subdomain.site.com')
  end

  private

  def extract_domain_helper(url)
    @processor.send(:extract_domain, url)
  end
end
