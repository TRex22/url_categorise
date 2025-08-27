require "test_helper"

class UrlCategoriseCoverageEnhancementTest < Minitest::Test
  def setup
    @temp_cache_dir = Dir.mktmpdir

    # Mock various URL responses
    WebMock.stub_request(:get, "http://example.com/malware.txt")
           .to_return(
             body: "0.0.0.0 badsite.com\n0.0.0.0 evilsite.com",
             headers: { "etag" => '"abc123"', "last-modified" => "Wed, 21 Oct 2015 07:28:00 GMT" }
           )

    WebMock.stub_request(:get, "http://example.com/ads.txt")
           .to_return(body: "0.0.0.0 adsite1.com\n0.0.0.0 adsite2.com")

    WebMock.stub_request(:head, "http://example.com/malware.txt")
           .to_return(headers: { "etag" => '"abc123"', "last-modified" => "Wed, 21 Oct 2015 07:28:00 GMT" })
  end

  def teardown
    FileUtils.rm_rf(@temp_cache_dir)
  end

  def test_hash_size_in_mb_calculation
    client = UrlCategorise::Client.new(host_urls: test_host_urls)

    # Test size calculation
    size = client.size_of_data
    assert_kind_of Numeric, size # Could be Float or Integer depending on size
    assert size >= 0
  end

  def test_count_methods
    client = UrlCategorise::Client.new(host_urls: test_host_urls)

    # Test count methods
    assert_instance_of Integer, client.count_of_hosts
    assert client.count_of_hosts > 0

    assert_instance_of Integer, client.count_of_categories
    assert client.count_of_categories > 0
  end

  def test_categories_with_keys_functionality
    # Test categories that reference other categories
    host_urls = {
      malware: [ "http://example.com/malware.txt" ],
      ads: [ "http://example.com/ads.txt" ],
      combined: %i[malware ads] # References other categories
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Combined category should include hosts from referenced categories
    assert_includes client.hosts.keys, :combined
    assert client.hosts[:combined].is_a?(Array)
  end

  def test_url_validation_methods
    client = UrlCategorise::Client.new(host_urls: test_host_urls)

    # Test valid URLs
    assert client.send(:url_valid?, "http://example.com")
    assert client.send(:url_valid?, "https://example.com")

    # Test invalid URLs
    refute client.send(:url_valid?, "not-a-url")
    refute client.send(:url_valid?, "")
    refute client.send(:url_valid?, nil)
  end

  def test_url_not_valid_method
    client = UrlCategorise::Client.new(host_urls: test_host_urls)

    # Test url_not_valid? method - should return true for invalid URLs
    refute client.send(:url_not_valid?, "http://example.com")   # Valid URL should return false
    refute client.send(:url_not_valid?, "https://example.com")  # Valid URL should return false
    assert client.send(:url_not_valid?, "not-a-url") # Invalid URL should return true
  end

  def test_parse_list_content_with_different_formats
    client = UrlCategorise::Client.new(host_urls: test_host_urls)

    # Test hosts format parsing
    hosts_content = "0.0.0.0 badsite.com\n127.0.0.1 localhost\n# This is a comment"
    result = client.send(:parse_list_content, hosts_content, :hosts)
    assert_includes result, "badsite.com"
    assert_includes result, "localhost"
    refute_includes result, "# This is a comment"

    # Test plain format parsing
    plain_content = "badsite.com\ngoodsite.com\n# Comment\n\n"
    result = client.send(:parse_list_content, plain_content, :plain)
    assert_includes result, "badsite.com"
    assert_includes result, "goodsite.com"

    # Test dnsmasq format parsing
    dnsmasq_content = "address=/badsite.com/0.0.0.0\naddress=/evilsite.com/127.0.0.1"
    result = client.send(:parse_list_content, dnsmasq_content, :dnsmasq)
    assert_includes result, "badsite.com"
    assert_includes result, "evilsite.com"

    # Test ublock format parsing
    ublock_content = "||badsite.com^\n||evilsite.com^$important\n||tracking.com^"
    result = client.send(:parse_list_content, ublock_content, :ublock)
    assert_includes result, "badsite.com"
    assert_includes result, "evilsite.com"
    assert_includes result, "tracking.com"

    # Test unknown format (defaults to plain)
    unknown_content = "badsite.com\nevilsite.com"
    result = client.send(:parse_list_content, unknown_content, :unknown)
    assert_includes result, "badsite.com"
    assert_includes result, "evilsite.com"
  end

  def test_detect_list_format_method
    client = UrlCategorise::Client.new(host_urls: test_host_urls)

    # Test hosts format detection
    hosts_content = "0.0.0.0 badsite.com\n127.0.0.1 localhost"
    assert_equal :hosts, client.send(:detect_list_format, hosts_content)

    # Test dnsmasq format detection
    dnsmasq_content = "address=/badsite.com/0.0.0.0\nother line"
    assert_equal :dnsmasq, client.send(:detect_list_format, dnsmasq_content)

    # Test ublock format detection
    ublock_content = "||badsite.com^\nother line"
    assert_equal :ublock, client.send(:detect_list_format, ublock_content)

    # Test plain format (default)
    plain_content = "badsite.com\nevilsite.com"
    assert_equal :plain, client.send(:detect_list_format, plain_content)
  end

  def test_cache_file_path_generation
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir
    )

    url = "http://example.com/test.txt"
    cache_path = client.send(:cache_file_path, url)

    assert cache_path.include?(@temp_cache_dir)
    assert cache_path.end_with?(".cache")

    # Test with nil cache_dir
    client_no_cache = UrlCategorise::Client.new(host_urls: test_host_urls)
    assert_nil client_no_cache.send(:cache_file_path, url)
  end

  def test_cache_operations_with_corrupted_cache
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir
    )

    url = "http://example.com/malware.txt"
    cache_file = client.send(:cache_file_path, url)

    # Create corrupted cache file
    File.write(cache_file, "corrupted data")

    # Should handle corrupted cache gracefully
    result = client.send(:read_from_cache, url)
    assert_nil result
  end

  def test_save_to_cache_with_nil_cache_file
    client = UrlCategorise::Client.new(host_urls: test_host_urls)

    # Should handle nil cache file gracefully (no cache_dir set)
    result = client.send(:save_to_cache, "http://example.com", [ "host1.com" ])
    assert_nil result # Should return nil without error
  end

  def test_should_update_cache_with_various_conditions
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir
    )

    url = "http://example.com/malware.txt"

    # Test force download
    client_force = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir,
      force_download: true
    )

    cache_data = { metadata: {}, cached_at: Time.now }
    assert client_force.send(:should_update_cache?, url, cache_data)

    # Test missing metadata
    cache_data_no_meta = { cached_at: Time.now }
    assert client.send(:should_update_cache?, url, cache_data_no_meta)

    # Test old cache (over 24 hours)
    old_cache_data = {
      metadata: { etag: "old" },
      cached_at: Time.now - (25 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, old_cache_data)

    # Test HEAD request failure
    WebMock.stub_request(:head, url).to_raise(StandardError.new("Network error"))

    recent_cache_data = {
      metadata: { etag: "recent" },
      cached_at: Time.now - (1 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, recent_cache_data)
  end

  def test_categorise_with_edge_cases
    client = UrlCategorise::Client.new(host_urls: test_host_urls)

    # Test with URL that has protocol
    categories = client.categorise("https://badsite.com")
    assert_includes categories, :malware

    # Test with URL that has path
    categories = client.categorise("https://badsite.com/path/to/page")
    assert_includes categories, :malware

    # Test with URL that has query parameters
    categories = client.categorise("https://badsite.com?param=value")
    assert_includes categories, :malware

    # Test with just domain
    categories = client.categorise("badsite.com")
    assert_includes categories, :malware

    # Test with www prefix
    categories = client.categorise("www.badsite.com")
    assert_includes categories, :malware
  end

  def test_resolve_and_categorise_with_multiple_ips
    # Mock DNS resolution with multiple IPs
    resolver = mock("resolver")
    ip1 = IPAddr.new("192.168.1.100")
    ip2 = IPAddr.new("10.0.0.1")
    resolver.expects(:getaddresses).with("badsite.com").returns([ ip1, ip2 ])
    Resolv::DNS.expects(:new).with(nameserver: [ "1.1.1.1", "1.0.0.1" ]).returns(resolver)

    # Mock IP lists
    WebMock.stub_request(:get, "http://example.com/ip-list.txt")
           .to_return(body: "192.168.1.100\n10.0.0.1")

    client = UrlCategorise::Client.new(
      host_urls: {
        malware: [ "http://example.com/malware.txt" ],
        bad_ips: [ "http://example.com/ip-list.txt" ]
      }
    )

    categories = client.resolve_and_categorise("badsite.com")
    assert_includes categories, :malware
    assert_includes categories, :bad_ips
  end

  def test_build_host_data_with_mixed_url_types
    # Mix of valid URLs and symbol references
    WebMock.stub_request(:get, "http://example.com/list1.txt")
           .to_return(body: "badsite1.com")
    WebMock.stub_request(:get, "http://example.com/list2.txt")
           .to_return(body: "badsite2.com")

    host_urls = {
      category1: [ "http://example.com/list1.txt" ],
      category2: [ "http://example.com/list2.txt" ],
      combined: %i[category1 category2]
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test that symbol references are processed
    assert_includes client.hosts.keys, :combined
  end

  def test_http_response_edge_cases
    # Test with empty response body
    WebMock.stub_request(:get, "http://example.com/empty.txt")
           .to_return(body: "")

    # Test with nil response body
    WebMock.stub_request(:get, "http://example.com/nil.txt")
           .to_return(body: nil)

    client = UrlCategorise::Client.new(
      host_urls: {
        empty: [ "http://example.com/empty.txt" ],
        nil_body: [ "http://example.com/nil.txt" ]
      }
    )

    # Should handle empty/nil responses gracefully
    assert_equal [], client.hosts[:empty]
    assert_equal [], client.hosts[:nil_body]
  end

  def test_metadata_with_missing_headers
    # Test response without etag or last-modified headers
    WebMock.stub_request(:get, "http://example.com/no-headers.txt")
           .to_return(body: "badsite.com")

    client = UrlCategorise::Client.new(
      host_urls: { test: [ "http://example.com/no-headers.txt" ] }
    )

    metadata = client.metadata["http://example.com/no-headers.txt"]
    assert_equal "success", metadata[:status]
    assert metadata.key?(:last_updated)
    assert metadata.key?(:content_hash)
  end

  def test_initialization_with_all_parameters
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir,
      force_download: true,
      dns_servers: [ "8.8.8.8", "1.1.1.1" ],
      request_timeout: 30
    )

    assert_equal test_host_urls, client.host_urls
    assert_equal @temp_cache_dir, client.cache_dir
    assert_equal true, client.force_download
    assert_equal [ "8.8.8.8", "1.1.1.1" ], client.dns_servers
    assert_equal 30, client.request_timeout
    assert_instance_of Hash, client.metadata
    assert_instance_of Hash, client.hosts
  end

  private

  def test_host_urls
    {
      malware: [ "http://example.com/malware.txt" ],
      ads: [ "http://example.com/ads.txt" ]
    }
  end
end
