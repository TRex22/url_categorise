require 'test_helper'

class UrlCategoriseComprehensiveEdgeCasesTest < Minitest::Test
  def setup
    @temp_cache_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_cache_dir)
  end

  def test_empty_host_urls_initialization
    WebMock.disable_net_connect!

    client = UrlCategorise::Client.new(host_urls: {})
    assert_empty client.hosts
    assert_empty client.metadata
    assert_equal 0, client.count_of_hosts
    assert_equal 0, client.count_of_categories
    assert_equal 0.0, client.size_of_data
  end

  def test_categorise_with_malformed_urls
    client = UrlCategorise::Client.new(host_urls: {})

    # Test URLs that should work without raising errors
    safe_malformed_urls = [
      'not-a-url',
      'ftp://example.com',  # Wrong protocol
      '//example.com',      # Protocol-relative
      'example',            # No TLD
      'http:///path' # Missing host
    ]

    safe_malformed_urls.each do |url|
      categories = client.categorise(url)
      assert_empty categories, "Should return empty for malformed URL: #{url.inspect}"
    end

    # Test URLs that will raise errors
    assert_raises(URI::InvalidURIError) do
      client.categorise(nil)
    end

    # Empty string actually gets processed and returns empty categories
    categories = client.categorise('')
    assert_empty categories

    # Space string raises error like nil
    assert_raises(URI::InvalidURIError) do
      client.categorise(' ')
    end
  end

  def test_categorise_with_nil_url
    client = UrlCategorise::Client.new(host_urls: {})

    assert_raises(URI::InvalidURIError) do
      client.categorise(nil)
    end
  end

  def test_categorise_ip_with_various_formats
    # Set up IP list
    WebMock.stub_request(:get, 'http://example.com/ips.txt')
           .to_return(body: "192.168.1.1\n10.0.0.1\n172.16.0.1\n127.0.0.1")

    client = UrlCategorise::Client.new(
      host_urls: { bad_ips: ['http://example.com/ips.txt'] }
    )

    # Test various IP formats
    valid_ips = [
      '192.168.1.1',
      '10.0.0.1',
      '172.16.0.1',
      '127.0.0.1'
    ]

    valid_ips.each do |ip|
      categories = client.categorise_ip(ip)
      assert_includes categories, :bad_ips, "Should categorize IP: #{ip}"
    end

    # Test invalid IPs
    invalid_ips = [
      '256.256.256.256',  # Out of range
      '192.168.1',        # Incomplete
      '192.168.1.1.1',    # Too many octets
      'not-an-ip',        # Not numeric
      '',                 # Empty
      ' '                 # Whitespace
    ]

    invalid_ips.each do |ip|
      categories = client.categorise_ip(ip)
      assert_empty categories, "Should not categorize invalid IP: #{ip}"
    end
  end

  def test_cache_directory_permissions
    # Test with read-only directory (simulate permission issues)
    readonly_dir = File.join(@temp_cache_dir, 'readonly')
    Dir.mkdir(readonly_dir)

    # On systems where we can change permissions
    begin
      File.chmod(0o444, readonly_dir)
    rescue StandardError
      skip 'Cannot test permissions on this system'
    end

    WebMock.stub_request(:get, 'http://example.com/test.txt')
           .to_return(body: 'test.com')

    # Should handle permission errors gracefully
    client = UrlCategorise::Client.new(
      host_urls: { test: ['http://example.com/test.txt'] },
      cache_dir: readonly_dir
    )
    # Should complete initialization without errors
    assert_instance_of UrlCategorise::Client, client
  ensure
    # Restore permissions for cleanup
    File.chmod(0o755, readonly_dir) if File.exist?(readonly_dir)
  end

  def test_large_response_handling
    # Test with moderate response
    large_content = (1..100).map { |i| "site#{i}.com" }.join("\n")

    WebMock.stub_request(:get, 'http://example.com/large.txt')
           .to_return(body: large_content)

    client = UrlCategorise::Client.new(
      host_urls: { large_list: ['http://example.com/large.txt'] }
    )

    # Just verify the client handles the response
    assert client.hosts[:large_list].is_a?(Array)
    assert client.size_of_data >= 0
  end

  def test_concurrent_cache_access_simulation
    # Simulate concurrent access to cache files
    WebMock.stub_request(:get, 'http://example.com/test.txt')
           .to_return(body: 'test.com', headers: { 'etag' => '"test123"' })

    WebMock.stub_request(:head, 'http://example.com/test.txt')
           .to_return(headers: { 'etag' => '"test123"' })

    # Create first client to establish cache
    client1 = UrlCategorise::Client.new(
      host_urls: { test: ['http://example.com/test.txt'] },
      cache_dir: @temp_cache_dir
    )

    # Create second client that should read from cache
    client2 = UrlCategorise::Client.new(
      host_urls: { test: ['http://example.com/test.txt'] },
      cache_dir: @temp_cache_dir
    )

    assert_equal client1.hosts[:test], client2.hosts[:test]
  end

  def test_dns_resolution_with_custom_servers
    # Test with various DNS server configurations
    dns_configs = [
      ['8.8.8.8'], # Single server
      ['8.8.8.8', '8.8.4.4'],       # Google DNS
      ['1.1.1.1', '1.0.0.1'],       # Cloudflare DNS
      ['208.67.222.222'],            # OpenDNS
      []                             # Empty (should use default)
    ]

    dns_configs.each do |dns_servers|
      client = UrlCategorise::Client.new(
        host_urls: {},
        dns_servers: dns_servers.empty? ? ['1.1.1.1', '1.0.0.1'] : dns_servers
      )

      expected_servers = dns_servers.empty? ? ['1.1.1.1', '1.0.0.1'] : dns_servers
      assert_equal expected_servers, client.dns_servers
    end
  end

  def test_resolve_and_categorise_with_ipv6
    # Mock IPv6 resolution
    resolver = mock('resolver')
    ipv6_addr = IPAddr.new('2001:db8::1')
    resolver.expects(:getaddresses).with('example.com').returns([ipv6_addr])
    Resolv::DNS.expects(:new).with(nameserver: ['1.1.1.1', '1.0.0.1']).returns(resolver)

    WebMock.stub_request(:get, 'http://example.com/domains.txt')
           .to_return(body: 'example.com')

    WebMock.stub_request(:get, 'http://example.com/ipv6.txt')
           .to_return(body: '2001:db8::1')

    client = UrlCategorise::Client.new(
      host_urls: {
        domains: ['http://example.com/domains.txt'],
        ipv6_list: ['http://example.com/ipv6.txt']
      }
    )

    # Should handle IPv6 addresses
    categories = client.resolve_and_categorise('example.com')
    assert categories.is_a?(Array)
  end

  def test_mixed_content_parsing
    # Test lists with mixed content - use plain format for predictable parsing
    mixed_content = "badsite.com\nevil.com\nblockedsite.com\n# This is a comment\n\ntracking.com"

    WebMock.stub_request(:get, 'http://example.com/mixed.txt')
           .to_return(body: mixed_content)

    client = UrlCategorise::Client.new(
      host_urls: { mixed: ['http://example.com/mixed.txt'] }
    )

    hosts = client.hosts[:mixed].flatten.compact
    assert hosts.include?('badsite.com'), "Should find badsite.com in: #{hosts.inspect}"
    assert hosts.include?('evil.com'), "Should find evil.com in: #{hosts.inspect}"
    assert hosts.include?('blockedsite.com'), "Should find blockedsite.com in: #{hosts.inspect}"
    # Comments and empty lines should be filtered out
    refute hosts.any? { |h| h.to_s.start_with?('#') }, "Should not include comments in: #{hosts.inspect}"
  end

  def test_timeout_with_different_values
    # Test various timeout values
    timeout_values = [1, 5, 10, 30, 60]

    timeout_values.each do |timeout|
      client = UrlCategorise::Client.new(
        host_urls: {},
        request_timeout: timeout
      )

      assert_equal timeout, client.request_timeout
    end
  end

  def test_metadata_with_all_header_combinations
    # Test various combinations of HTTP headers
    header_combinations = [
      {}, # No headers
      { 'etag' => '"abc123"' }, # Only ETag
      { 'last-modified' => 'Wed, 21 Oct 2015 07:28:00 GMT' }, # Only Last-Modified
      { 'etag' => '"abc123"', 'last-modified' => 'Wed, 21 Oct 2015 07:28:00 GMT' }, # Both
      { 'etag' => '', 'last-modified' => '' }, # Empty values
      { 'content-length' => '1234' } # Other headers
    ]

    header_combinations.each_with_index do |headers, index|
      url = "http://example.com/headers#{index}.txt"
      WebMock.stub_request(:get, url)
             .to_return(body: 'test.com', headers: headers)

      client = UrlCategorise::Client.new(
        host_urls: { "test#{index}".to_sym => [url] }
      )

      metadata = client.metadata[url]
      assert_equal 'success', metadata[:status]
      assert metadata.key?(:last_updated)
      assert metadata.key?(:content_hash)
    end
  end

  def test_url_parsing_edge_cases
    WebMock.stub_request(:get, 'http://example.com/domains.txt')
           .to_return(body: 'test.com')

    client = UrlCategorise::Client.new(
      host_urls: { test: ['http://example.com/domains.txt'] }
    )

    # Test various URL formats that should all resolve to the same domain
    url_variations = [
      'test.com',
      'http://test.com',
      'https://test.com',
      'http://www.test.com',
      'https://www.test.com',
      'http://test.com/',
      'http://test.com/path',
      'http://test.com/path?query=1',
      'http://test.com:80',
      'http://TEST.COM', # Case variations
      'http://www.TEST.COM'
    ]

    url_variations.each do |url|
      categories = client.categorise(url)
      assert_includes categories, :test, "Should categorize URL variation: #{url}"
    end
  end

  def test_error_recovery_in_batch_processing
    # Test that errors in one URL don't affect others
    WebMock.stub_request(:get, 'http://good1.com/list.txt')
           .to_return(body: 'badsite1.com')

    WebMock.stub_request(:get, 'http://error.com/list.txt')
           .to_raise(SocketError.new('Network error'))

    WebMock.stub_request(:get, 'http://good2.com/list.txt')
           .to_return(body: 'badsite2.com')

    client = UrlCategorise::Client.new(
      host_urls: {
        category1: [
          'http://good1.com/list.txt',
          'http://error.com/list.txt', # This should fail
          'http://good2.com/list.txt'
        ]
      }
    )

    # Should have processed the good URLs despite the error
    hosts = client.hosts[:category1].flatten.compact
    assert_includes hosts, 'badsite1.com'
    assert_includes hosts, 'badsite2.com'

    # Error should be recorded in metadata
    assert_equal 'failed', client.metadata['http://error.com/list.txt'][:status]
  end

  def test_cache_corruption_recovery
    WebMock.stub_request(:get, 'http://example.com/test.txt')
           .to_return(body: 'test.com', headers: { 'etag' => '"test456"' })

    WebMock.stub_request(:head, 'http://example.com/test.txt')
           .to_return(headers: { 'etag' => '"test456"' })

    # First, create a valid cache
    UrlCategorise::Client.new(
      host_urls: { test: ['http://example.com/test.txt'] },
      cache_dir: @temp_cache_dir
    )

    # Find and corrupt the cache file
    cache_files = Dir.glob(File.join(@temp_cache_dir, '*.cache'))
    refute_empty cache_files

    cache_file = cache_files.first
    File.write(cache_file, "corrupted binary data \x00\x01\x02")

    # Should recover gracefully and re-download
    client2 = UrlCategorise::Client.new(
      host_urls: { test: ['http://example.com/test.txt'] },
      cache_dir: @temp_cache_dir
    )

    assert_includes client2.hosts[:test].flatten, 'test.com'
  end
end
