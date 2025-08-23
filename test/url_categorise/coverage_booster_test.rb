require "test_helper"

class UrlCategoriseCoverageBoosterTest < Minitest::Test
  def setup
    @temp_cache_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_cache_dir)
  end

  def test_all_list_format_detection_branches
    client = UrlCategorise::Client.new(host_urls: {})
    
    # Test all format detection branches
    hosts_content = "0.0.0.0 example.com\n127.0.0.1 test.com"
    assert_equal :hosts, client.send(:detect_list_format, hosts_content)
    
    dnsmasq_content = "address=/example.com/0.0.0.0"
    assert_equal :dnsmasq, client.send(:detect_list_format, dnsmasq_content)
    
    ublock_content = "||example.com^"
    assert_equal :ublock, client.send(:detect_list_format, ublock_content)
    
    plain_content = "example.com\ntest.com"
    assert_equal :plain, client.send(:detect_list_format, plain_content)
  end

  def test_all_list_format_parsing_branches
    client = UrlCategorise::Client.new(host_urls: {})
    
    # Test hosts format with various entries
    hosts_content = "0.0.0.0 badsite.com\n127.0.0.1 localhost\n# comment"
    result = client.send(:parse_list_content, hosts_content, :hosts)
    assert_includes result, "badsite.com"
    assert_includes result, "localhost"
    
    # Test plain format
    plain_content = "badsite.com\ngoodsite.com\n# comment\n"
    result = client.send(:parse_list_content, plain_content, :plain)
    assert_includes result, "badsite.com"
    assert_includes result, "goodsite.com"
    
    # Test dnsmasq format
    dnsmasq_content = "address=/badsite.com/0.0.0.0\naddress=/evilsite.com/127.0.0.1"
    result = client.send(:parse_list_content, dnsmasq_content, :dnsmasq)
    assert_includes result, "badsite.com"
    assert_includes result, "evilsite.com"
    
    # Test ublock format with different patterns
    ublock_content = "||badsite.com^\n||evilsite.com^$important\n||*.tracking.com^"
    result = client.send(:parse_list_content, ublock_content, :ublock)
    assert_includes result, "badsite.com"
    assert_includes result, "evilsite.com"
    
    # Test unknown format (falls back to plain)
    unknown_content = "badsite.com\nevilsite.com"
    result = client.send(:parse_list_content, unknown_content, :unknown_format)
    assert_includes result, "badsite.com"
    assert_includes result, "evilsite.com"
  end

  def test_cache_update_conditions_comprehensive
    # Test all branches of should_update_cache?
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir
    )
    
    url = "http://example.com/test.txt"
    
    # Test force_download = true
    client_force = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir,
      force_download: true
    )
    cache_data = { metadata: { etag: "test" }, cached_at: Time.now }
    assert client_force.send(:should_update_cache?, url, cache_data)
    
    # Test missing metadata
    cache_data_no_meta = { cached_at: Time.now }
    assert client.send(:should_update_cache?, url, cache_data_no_meta)
    
    # Test cache older than 24 hours
    old_cache_data = {
      metadata: { etag: "old" },
      cached_at: Time.now - (25 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, old_cache_data)
    
    # Test different etags
    WebMock.stub_request(:head, url)
           .to_return(headers: { 'etag' => '"new_etag"' })
    
    different_etag_cache = {
      metadata: { etag: "old_etag" },
      cached_at: Time.now - (1 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, different_etag_cache)
    
    # Test different last-modified
    WebMock.stub_request(:head, url)
           .to_return(headers: { 'last-modified' => 'Thu, 22 Oct 2015 07:28:00 GMT' })
    
    different_modified_cache = {
      metadata: { last_modified: 'Wed, 21 Oct 2015 07:28:00 GMT' },
      cached_at: Time.now - (1 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, different_modified_cache)
    
    # Test HEAD request failure
    WebMock.stub_request(:head, url).to_raise(StandardError.new("Network error"))
    
    recent_cache_data = {
      metadata: { etag: "recent" },
      cached_at: Time.now - (1 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, recent_cache_data)
    
    # Test when cache is fresh (should not update)
    WebMock.stub_request(:head, url)
           .to_return(headers: { 'etag' => '"same_etag"' })
    
    fresh_cache_data = {
      metadata: { etag: '"same_etag"' },
      cached_at: Time.now - (30 * 60)  # 30 minutes ago
    }
    refute client.send(:should_update_cache?, url, fresh_cache_data)
  end

  def test_error_handling_comprehensive
    # Test all error types in download_and_parse_list
    error_types = [
      HTTParty::Error.new("HTTParty error"),
      Net::HTTPError.new("HTTP error", nil),
      SocketError.new("Socket error"),
      Timeout::Error.new("Timeout error"),
      URI::InvalidURIError.new("Invalid URI"),
      StandardError.new("Standard error")
    ]
    
    error_types.each_with_index do |error, index|
      url = "http://example.com/error#{index}.txt"
      WebMock.stub_request(:get, url).to_raise(error)
      
      client = UrlCategorise::Client.new(
        host_urls: { "error#{index}".to_sym => [url] }
      )
      
      # Should handle error gracefully
      assert_equal [], client.hosts["error#{index}".to_sym]
      assert_equal 'failed', client.metadata[url][:status]
      assert_includes client.metadata[url][:error], error.message
    end
  end

  def test_cache_operations_comprehensive
    WebMock.stub_request(:get, "http://example.com/test.txt")
           .to_return(body: "test.com", headers: { 'etag' => '"test123"' })
    
    WebMock.stub_request(:head, "http://example.com/test.txt")
           .to_return(headers: { 'etag' => '"test123"' })
    
    # Test cache creation and reading
    client = UrlCategorise::Client.new(
      host_urls: { test: ["http://example.com/test.txt"] },
      cache_dir: @temp_cache_dir
    )
    
    url = "http://example.com/test.txt"
    
    # Test cache file path generation
    cache_path = client.send(:cache_file_path, url)
    assert cache_path.include?(@temp_cache_dir)
    assert cache_path.end_with?('.cache')
    assert File.exist?(cache_path)
    
    # Test reading from cache
    cached_data = client.send(:read_from_cache, url)
    assert cached_data.include?("test.com")
    
    # Test save to cache with new data
    new_data = ["newsite.com"]
    client.send(:save_to_cache, url, new_data)
    
    # Verify cache was updated
    updated_cache = client.send(:read_from_cache, url)
    assert updated_cache.include?("newsite.com")
  end

  def test_uri_parsing_edge_cases
    # Mock some test data
    WebMock.stub_request(:get, "http://example.com/test.txt")
           .to_return(body: "testsite.com")
    
    client = UrlCategorise::Client.new(
      host_urls: { test: ["http://example.com/test.txt"] }
    )
    
    # Test various URI formats
    test_cases = [
      # [input_url, expected_host]
      ["testsite.com", "testsite.com"],
      ["http://testsite.com", "testsite.com"],
      ["https://testsite.com", "testsite.com"],
      ["http://www.testsite.com", "testsite.com"],
      ["https://www.testsite.com", "testsite.com"],
      ["http://testsite.com/", "testsite.com"],
      ["http://testsite.com/path", "testsite.com"],
      ["http://testsite.com:8080", "testsite.com"],
      ["http://testsite.com?query=1", "testsite.com"],
      ["http://TESTSITE.COM", "testsite.com"],  # Case handling
    ]
    
    test_cases.each do |input_url, expected_host|
      categories = client.categorise(input_url)
      if expected_host == "testsite.com"
        assert_includes categories, :test, "Failed for input: #{input_url}"
      else
        assert_empty categories, "Should be empty for: #{input_url}"
      end
    end
  end

  def test_dns_resolution_comprehensive
    # Test DNS resolution with different scenarios
    WebMock.stub_request(:get, "http://example.com/domains.txt")
           .to_return(body: "testdomain.com")
    
    WebMock.stub_request(:get, "http://example.com/ips.txt")
           .to_return(body: "192.168.1.100")
    
    client = UrlCategorise::Client.new(
      host_urls: {
        domains: ["http://example.com/domains.txt"],
        ips: ["http://example.com/ips.txt"]
      }
    )
    
    # Test successful DNS resolution
    resolver = mock('resolver')
    ip_addr = IPAddr.new('192.168.1.100')
    resolver.expects(:getaddresses).with('testdomain.com').returns([ip_addr])
    Resolv::DNS.expects(:new).with(nameserver: ['1.1.1.1', '1.0.0.1']).returns(resolver)
    
    categories = client.resolve_and_categorise('testdomain.com')
    assert_includes categories, :domains
    assert_includes categories, :ips
    
    # Test DNS resolution failure
    resolver_fail = mock('resolver')
    resolver_fail.expects(:getaddresses).with('faileddomain.com').raises(StandardError.new("DNS failed"))
    Resolv::DNS.expects(:new).with(nameserver: ['1.1.1.1', '1.0.0.1']).returns(resolver_fail)
    
    categories_fail = client.resolve_and_categorise('faileddomain.com')
    # Should still return empty array gracefully
    assert categories_fail.is_a?(Array)
  end

  def test_host_data_building_edge_cases
    # Test build_host_data with mixed URL types
    WebMock.stub_request(:get, "http://example.com/valid.txt")
           .to_return(body: "valid.com")
    
    client = UrlCategorise::Client.new(host_urls: {})
    
    # Test with empty URLs array
    result = client.send(:build_host_data, [])
    assert_empty result
    
    # Test with valid URLs
    result = client.send(:build_host_data, ["http://example.com/valid.txt"])
    assert_includes result, "valid.com"
    
    # Test with invalid URL (should be skipped)
    result = client.send(:build_host_data, ["not-a-valid-url"])
    assert_equal [], result
  end

  def test_metadata_comprehensive
    # Test metadata handling with various HTTP headers
    test_headers = [
      { 'etag' => '"abc123"', 'last-modified' => 'Wed, 21 Oct 2015 07:28:00 GMT' },
      { 'etag' => '"def456"' },
      { 'last-modified' => 'Thu, 22 Oct 2015 07:28:00 GMT' },
      {}
    ]
    
    test_headers.each_with_index do |headers, index|
      url = "http://example.com/meta#{index}.txt"
      WebMock.stub_request(:get, url)
             .to_return(body: "meta#{index}.com", headers: headers)
      
      client = UrlCategorise::Client.new(
        host_urls: { "meta#{index}".to_sym => [url] }
      )
      
      metadata = client.metadata[url]
      assert_equal 'success', metadata[:status]
      assert metadata.key?(:last_updated)
      assert metadata.key?(:content_hash)
      
      if headers['etag']
        assert_equal headers['etag'], metadata[:etag]
      end
      
      if headers['last-modified']
        assert_equal headers['last-modified'], metadata[:last_modified]
      end
    end
  end

  def test_initialization_parameter_combinations
    # Test various parameter combinations
    test_configs = [
      {},  # All defaults
      { cache_dir: @temp_cache_dir },
      { force_download: true },
      { dns_servers: ['8.8.8.8'] },
      { request_timeout: 30 },
      { 
        cache_dir: @temp_cache_dir,
        force_download: true,
        dns_servers: ['8.8.8.8', '8.8.4.4'],
        request_timeout: 15
      }
    ]
    
    test_configs.each do |config|
      client = UrlCategorise::Client.new(
        host_urls: {},
        **config
      )
      
      if config[:cache_dir]
        assert_equal config[:cache_dir], client.cache_dir
      else
        assert_nil client.cache_dir
      end
      assert_equal !!config[:force_download], client.force_download
      assert_equal config[:dns_servers] || ['1.1.1.1', '1.0.0.1'], client.dns_servers
      assert_equal config[:request_timeout] || 10, client.request_timeout
      assert_instance_of Hash, client.metadata
      assert_instance_of Hash, client.hosts
    end
  end
end