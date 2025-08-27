require "test_helper"

class UrlCategoriseFinalCoverageTest < Minitest::Test
  def setup
    @temp_cache_dir = Dir.mktmpdir

    # Simple, reliable stubs
    WebMock.stub_request(:get, "http://example.com/simple.txt")
           .to_return(body: "simple.com", headers: { "etag" => '"simple123"' })

    WebMock.stub_request(:head, "http://example.com/simple.txt")
           .to_return(headers: { "etag" => '"simple123"' })
  end

  def teardown
    FileUtils.rm_rf(@temp_cache_dir)
  end

  def test_private_method_url_not_valid
    client = UrlCategorise::Client.new(host_urls: {})

    # Test the url_not_valid? method - should return true for invalid URLs
    refute client.send(:url_not_valid?, "http://example.com")   # Valid URL should return false
    refute client.send(:url_not_valid?, "https://example.com")  # Valid URL should return false
    assert client.send(:url_not_valid?, "not-a-url") # Invalid URL should return true
  end

  def test_private_method_categories_with_keys
    host_urls = {
      malware: [ "http://example.com/simple.txt" ],
      combined: [ :malware ] # This should trigger the categories_with_keys logic
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # The combined category should reference the malware category
    assert_includes client.hosts.keys, :combined
    assert_includes client.hosts.keys, :malware
  end

  def test_cache_file_path_with_cache_dir
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir
    )

    path = client.send(:cache_file_path, "http://example.com")
    assert path.include?(@temp_cache_dir)
    assert path.end_with?(".cache")
  end

  def test_cache_file_path_without_cache_dir
    client = UrlCategorise::Client.new(host_urls: {})

    path = client.send(:cache_file_path, "http://example.com")
    assert_nil path
  end

  def test_read_from_cache_with_no_cache_file
    client = UrlCategorise::Client.new(host_urls: {})

    result = client.send(:read_from_cache, "http://example.com")
    assert_nil result
  end

  def test_should_update_cache_edge_cases
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir,
      force_download: true
    )

    # Force download should always return true
    cache_data = { metadata: { etag: "test" }, cached_at: Time.now }
    assert client.send(:should_update_cache?, "http://example.com", cache_data)
  end

  def test_should_update_cache_missing_metadata
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir
    )

    # Missing metadata should trigger update
    cache_data = { cached_at: Time.now }
    assert client.send(:should_update_cache?, "http://example.com", cache_data)
  end

  def test_should_update_cache_old_cache
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir
    )

    # Old cache (over 24 hours) should trigger update
    old_time = Time.now - (25 * 60 * 60)
    cache_data = { metadata: { etag: "test" }, cached_at: old_time }
    assert client.send(:should_update_cache?, "http://example.com", cache_data)
  end

  def test_categorise_with_protocol_variations
    WebMock.stub_request(:get, "http://example.com/hosts.txt")
           .to_return(body: "test.com")

    client = UrlCategorise::Client.new(
      host_urls: { test: [ "http://example.com/hosts.txt" ] }
    )

    # Test that domains are properly extracted and matched
    variations = [
      "test.com",
      "http://test.com",
      "https://test.com",
      "http://www.test.com",
      "https://www.test.com"
    ]

    variations.each do |url|
      categories = client.categorise(url)
      assert_includes categories, :test, "Should categorize #{url}"
    end
  end

  def test_hash_size_calculation_with_empty_data
    client = UrlCategorise::Client.new(host_urls: {})

    # Empty data should return 0.0
    assert_equal 0.0, client.size_of_data
  end

  def test_parse_list_content_edge_cases
    client = UrlCategorise::Client.new(host_urls: {})

    # Test with empty content
    result = client.send(:parse_list_content, "", :plain)
    assert_empty result

    # Test with only comments
    result = client.send(:parse_list_content, "# Comment only", :plain)
    assert_empty result

    # Test with only whitespace - this returns empty strings that get filtered
    result = client.send(:parse_list_content, "   \n  \n  ", :plain)
    # The method strips but doesn't filter empty strings, so we get ["", "", ""]
    refute_empty result # It actually returns empty strings
    assert(result.all? { |item| item.strip.empty? })
  end

  def test_detect_list_format_edge_cases
    client = UrlCategorise::Client.new(host_urls: {})

    # Test with empty content
    result = client.send(:detect_list_format, "")
    assert_equal :plain, result

    # Test with only comments
    result = client.send(:detect_list_format, "# Comment")
    assert_equal :plain, result
  end

  def test_dns_resolution_with_empty_servers
    client = UrlCategorise::Client.new(
      host_urls: {},
      dns_servers: []
    )

    assert_equal [], client.dns_servers
  end

  def test_categorise_ip_with_empty_hosts
    client = UrlCategorise::Client.new(host_urls: {})

    result = client.categorise_ip("192.168.1.1")
    assert_empty result
  end

  def test_resolve_and_categorise_with_empty_hosts
    client = UrlCategorise::Client.new(host_urls: {})

    # Should not raise error even with empty hosts
    result = client.resolve_and_categorise("example.com")
    assert_empty result
  end

  def test_metadata_access
    client = UrlCategorise::Client.new(
      host_urls: { test: [ "http://example.com/simple.txt" ] }
    )

    # Metadata should be populated
    refute_empty client.metadata

    metadata = client.metadata["http://example.com/simple.txt"]
    assert_equal "success", metadata[:status]
    assert metadata.key?(:last_updated)
    assert metadata.key?(:content_hash)
  end

  def test_build_host_data_with_empty_urls
    client = UrlCategorise::Client.new(host_urls: {})

    result = client.send(:build_host_data, [])
    assert_empty result
  end

  def test_initialization_parameter_coverage
    # Test all initialization parameters are properly assigned
    client = UrlCategorise::Client.new(
      host_urls: { test: [] },
      cache_dir: @temp_cache_dir,
      force_download: true,
      dns_servers: [ "8.8.8.8" ],
      request_timeout: 15
    )

    assert_equal({ test: [] }, client.host_urls)
    assert_equal @temp_cache_dir, client.cache_dir
    assert_equal true, client.force_download
    assert_equal [ "8.8.8.8" ], client.dns_servers
    assert_equal 15, client.request_timeout
    assert_instance_of Hash, client.metadata
    assert_instance_of Hash, client.hosts
  end

  def test_count_methods_with_populated_data
    client = UrlCategorise::Client.new(
      host_urls: { test: [ "http://example.com/simple.txt" ] }
    )

    assert client.count_of_hosts > 0
    assert client.count_of_categories > 0
    assert client.size_of_data >= 0
  end

  def test_api_version_methods
    assert_equal "v2", UrlCategorise::Client.compatible_api_version
    assert_equal "v2 2025-08-23", UrlCategorise::Client.api_version
  end

  def test_constants_inclusion
    client = UrlCategorise::Client.new(host_urls: {})

    # Client should include Constants module
    assert client.class.include?(UrlCategorise::Constants)
  end

  def test_categorise_ip_method_comprehensive
    WebMock.stub_request(:get, "http://example.com/ip-list.txt")
           .to_return(status: 200, body: "192.168.1.1\n10.0.0.1\n")

    client = UrlCategorise::Client.new(
      host_urls: { malware: [ "http://example.com/ip-list.txt" ] }
    )

    categories = client.categorise_ip("192.168.1.1")
    assert_includes categories, :malware

    categories_empty = client.categorise_ip("1.2.3.4")
    assert_empty categories_empty
  end

  def test_resolve_and_categorise_with_dns_failure
    WebMock.stub_request(:get, "http://example.com/domain-list.txt")
           .to_return(status: 200, body: "example.com\n")

    client = UrlCategorise::Client.new(
      host_urls: { tracking: [ "http://example.com/domain-list.txt" ] },
      dns_servers: [ "invalid.dns.server" ]
    )

    # Should still return domain categories even if DNS fails
    categories = client.resolve_and_categorise("example.com")
    assert_includes categories, :tracking
  end

  def test_download_with_various_http_errors
    # Test SocketError
    WebMock.stub_request(:get, "http://socket-error.com/list.txt")
           .to_raise(SocketError.new("Connection failed"))

    client = UrlCategorise::Client.new(
      host_urls: { test_socket: [ "http://socket-error.com/list.txt" ] }
    )

    hosts_data = client.instance_variable_get(:@hosts)[:test_socket]
    assert hosts_data.empty? || hosts_data == [ [] ], "Expected empty hosts data, got: #{hosts_data.inspect}"
    assert_equal "failed", client.metadata["http://socket-error.com/list.txt"][:status]

    # Test Timeout::Error
    WebMock.stub_request(:get, "http://timeout-error.com/list.txt")
           .to_timeout

    client2 = UrlCategorise::Client.new(
      host_urls: { test_timeout: [ "http://timeout-error.com/list.txt" ] }
    )

    hosts_data2 = client2.instance_variable_get(:@hosts)[:test_timeout]
    assert hosts_data2.empty? || hosts_data2 == [ [] ], "Expected empty hosts data, got: #{hosts_data2.inspect}"
    assert_equal "failed", client2.metadata["http://timeout-error.com/list.txt"][:status]
  end

  def test_detect_list_format_comprehensive_edge_cases
    client = UrlCategorise::Client.new(host_urls: {})

    # Test with only comments and empty lines
    content_with_comments = "#comment\n\n#another comment\n"
    format = client.send(:detect_list_format, content_with_comments)
    assert_equal :plain, format

    # Test with mixed content
    mixed_content = "#comment\n0.0.0.0 example.com\nplain-domain.com\n"
    format = client.send(:detect_list_format, mixed_content)
    assert_equal :hosts, format

    # Test dnsmasq detection
    dnsmasq_content = "address=/example.com/0.0.0.0\naddress=/test.com/127.0.0.1\n"
    format = client.send(:detect_list_format, dnsmasq_content)
    assert_equal :dnsmasq, format

    # Test ublock detection
    ublock_content = "||example.com^\n||another.com^$important\n"
    format = client.send(:detect_list_format, ublock_content)
    assert_equal :ublock, format
  end

  def test_parse_list_content_comprehensive_edge_cases
    client = UrlCategorise::Client.new(host_urls: {})

    # Test hosts format with malformed lines
    hosts_content = "0.0.0.0 good-domain.com\nmalformed-line\n127.0.0.1 another-domain.com\n"
    result = client.send(:parse_list_content, hosts_content, :hosts)
    assert_includes result, "good-domain.com"
    assert_includes result, "another-domain.com"
    refute_includes result, "malformed-line"

    # Test ublock format with complex rules
    ublock_content = "||example.com^\n||another.com^$important\n||third.com^$script,domain=example.org\n"
    result = client.send(:parse_list_content, ublock_content, :ublock)
    assert_includes result, "example.com"
    assert_includes result, "another.com"
    assert_includes result, "third.com"

    # Test dnsmasq format
    dnsmasq_content = "address=/example.com/0.0.0.0\naddress=/test.com/127.0.0.1\n"
    result = client.send(:parse_list_content, dnsmasq_content, :dnsmasq)
    assert_includes result, "example.com"
    assert_includes result, "test.com"

    # Test unknown format fallback
    unknown_content = "line1\nline2\nline3\n"
    result = client.send(:parse_list_content, unknown_content, :unknown)
    assert_includes result, "line1"
    assert_includes result, "line2"
    assert_includes result, "line3"
  end

  def test_cache_functionality_comprehensive_scenarios
    WebMock.stub_request(:get, "http://example.com/cached-list.txt")
           .to_return(
             status: 200,
             body: "cached-domain.com\n",
             headers: { "etag" => "test-etag", "last-modified" => "Wed, 01 Jan 2025 00:00:00 GMT" }
           )

    UrlCategorise::Client.new(
      host_urls: { cached_test: [ "http://example.com/cached-list.txt" ] },
      cache_dir: @temp_cache_dir
    )

    # Verify cache was created
    cache_files = Dir.glob(File.join(@temp_cache_dir, "*.cache"))
    assert_equal 1, cache_files.length

    # Test reading from cache on second initialization
    WebMock.stub_request(:head, "http://example.com/cached-list.txt")
           .to_return(
             status: 200,
             headers: { "etag" => "test-etag", "last-modified" => "Wed, 01 Jan 2025 00:00:00 GMT" }
           )

    client2 = UrlCategorise::Client.new(
      host_urls: { cached_test: [ "http://example.com/cached-list.txt" ] },
      cache_dir: @temp_cache_dir,
      force_download: false
    )

    categories = client2.categorise("cached-domain.com")
    assert_includes categories, :cached_test
  end

  def test_should_update_cache_comprehensive_scenarios
    WebMock.stub_request(:get, "http://example.com/cache-test.txt")
           .to_return(status: 200, body: "test.com\n", headers: { "etag" => "original-etag" })

    client = UrlCategorise::Client.new(
      host_urls: { cache_test: [ "http://example.com/cache-test.txt" ] },
      cache_dir: @temp_cache_dir
    )

    # Test with changed ETag
    WebMock.stub_request(:head, "http://example.com/cache-test.txt")
           .to_return(status: 200, headers: { "etag" => "new-etag" })

    cache_data = {
      cached_at: Time.now - 1000, # Recent cache
      metadata: { etag: "original-etag" }
    }

    should_update = client.send(:should_update_cache?, "http://example.com/cache-test.txt", cache_data)
    assert should_update

    # Test with changed last-modified
    WebMock.stub_request(:head, "http://example.com/cache-test2.txt")
           .to_return(status: 200, headers: { "last-modified" => "Thu, 02 Jan 2025 00:00:00 GMT" })

    cache_data2 = {
      cached_at: Time.now - 1000,
      metadata: { last_modified: "Wed, 01 Jan 2025 00:00:00 GMT" }
    }

    should_update2 = client.send(:should_update_cache?, "http://example.com/cache-test2.txt", cache_data2)
    assert should_update2

    # Test with HEAD request failure
    WebMock.stub_request(:head, "http://example.com/cache-test-fail.txt")
           .to_raise(SocketError.new("Connection failed"))

    cache_data3 = {
      cached_at: Time.now - 1000,
      metadata: { etag: "test" }
    }

    should_update3 = client.send(:should_update_cache?, "http://example.com/cache-test-fail.txt", cache_data3)
    assert should_update3 # Should update when HEAD fails
  end

  def test_save_to_cache_error_handling
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: "/invalid/path/that/cannot/be/created"
    )

    # Should not raise error even if cache save fails
    begin
      client.send(:save_to_cache, "http://example.com/test.txt", [ "test.com" ])
      # Test passes if no exception is raised
      assert true
    rescue StandardError => e
      flunk "Expected no exception, but got: #{e.message}"
    end
  end

  def test_read_from_cache_error_handling
    # Create invalid cache file
    FileUtils.mkdir_p(@temp_cache_dir)
    cache_file = File.join(@temp_cache_dir, Digest::MD5.hexdigest("http://example.com/test.txt") + ".cache")
    File.write(cache_file, "invalid marshal data")

    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir
    )

    # Should return nil for corrupted cache
    result = client.send(:read_from_cache, "http://example.com/test.txt")
    assert_nil result
  end

  def test_build_host_data_with_invalid_urls
    client = UrlCategorise::Client.new(host_urls: {})

    urls = [ "http://valid.com/list.txt", "not-a-url", :symbol_url ]

    WebMock.stub_request(:get, "http://valid.com/list.txt")
           .to_return(status: 200, body: "valid.com\n")

    result = client.send(:build_host_data, urls)
    assert_includes result, "valid.com"
    assert_equal 1, result.length # Only valid URL should be processed
  end

  def test_categorise_with_subdomain_matching
    WebMock.stub_request(:get, "http://example.com/domain-list.txt")
           .to_return(status: 200, body: "example.com\n")

    client = UrlCategorise::Client.new(
      host_urls: { test_subdomain: [ "http://example.com/domain-list.txt" ] }
    )

    # Test subdomain matching
    categories = client.categorise("subdomain.example.com")
    assert_includes categories, :test_subdomain

    # Test with URL format
    categories_url = client.categorise("https://api.example.com/endpoint")
    assert_includes categories_url, :test_subdomain
  end

  def test_empty_and_nil_response_handling
    WebMock.stub_request(:get, "http://example.com/empty.txt")
           .to_return(status: 200, body: "")

    WebMock.stub_request(:get, "http://example.com/nil-body.txt")
           .to_return(status: 200, body: nil)

    client = UrlCategorise::Client.new(
      host_urls: {
        empty_test: [ "http://example.com/empty.txt" ],
        nil_test: [ "http://example.com/nil-body.txt" ]
      }
    )

    hosts_data1 = client.instance_variable_get(:@hosts)[:empty_test]
    hosts_data2 = client.instance_variable_get(:@hosts)[:nil_test]
    assert hosts_data1.empty? || hosts_data1 == [ [] ],
           "Expected empty hosts data for empty_test, got: #{hosts_data1.inspect}"
    assert hosts_data2.empty? || hosts_data2 == [ [] ],
           "Expected empty hosts data for nil_test, got: #{hosts_data2.inspect}"
  end

  def test_hash_size_in_mb_private_method
    client = UrlCategorise::Client.new(host_urls: {})

    test_hash = {
      category1: [ "short.com" ],
      category2: [ "verylongdomainname.example.com", "another.long.domain.com" ]
    }

    size = client.send(:hash_size_in_mb, test_hash)
    assert_kind_of Numeric, size
    assert size >= 0
  end

  def test_uri_parsing_error_handling
    client = UrlCategorise::Client.new(host_urls: {})

    # Test url_valid? with invalid URI
    refute client.send(:url_valid?, "not a valid uri with spaces")
    refute client.send(:url_valid?, "ftp://example.com") # Not HTTP/HTTPS
    assert client.send(:url_valid?, "http://example.com")
    assert client.send(:url_valid?, "https://example.com")
  end

  def test_metadata_storage_during_download
    WebMock.stub_request(:get, "http://example.com/metadata-test.txt")
           .to_return(
             status: 200,
             body: "test.com\n",
             headers: {
               "etag" => "metadata-etag",
               "last-modified" => "Wed, 01 Jan 2025 12:00:00 GMT",
               "content-type" => "text/plain"
             }
           )

    client = UrlCategorise::Client.new(
      host_urls: { metadata_test: [ "http://example.com/metadata-test.txt" ] }
    )

    metadata = client.metadata["http://example.com/metadata-test.txt"]
    assert_equal "success", metadata[:status]
    assert_equal "metadata-etag", metadata[:etag]
    assert_equal "Wed, 01 Jan 2025 12:00:00 GMT", metadata[:last_modified]
    assert metadata.key?(:content_hash)
    assert metadata.key?(:last_updated)
  end
end
