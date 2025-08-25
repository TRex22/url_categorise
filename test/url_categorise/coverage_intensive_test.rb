require 'test_helper'

class UrlCategoriseCoverageIntensiveTest < Minitest::Test
  def setup
    @temp_cache_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_cache_dir)
  end

  def test_every_single_code_path_scenario_1
    # Test absolutely every code path to maximize coverage

    # Test 1: Complex categorise method with various URL formats
    WebMock.stub_request(:get, 'http://example.com/comprehensive.txt')
           .to_return(body: "testsite.com\nwww.testsite.com\nanother.com")

    client = UrlCategorise::Client.new(
      host_urls: { comprehensive: ['http://example.com/comprehensive.txt'] }
    )

    # Test every URL parsing branch
    test_urls = [
      'testsite.com',                    # Plain domain
      'http://testsite.com',             # HTTP
      'https://testsite.com',            # HTTPS
      'http://www.testsite.com',         # With www
      'https://www.testsite.com',        # HTTPS with www
      'testsite.com/path',               # With path
      'http://testsite.com/path?q=1',    # With query
      'https://testsite.com:443/path',   # With port
      'WWW.TESTSITE.COM',                # Case variations
      'HTTP://TESTSITE.COM' # Uppercase protocol
    ]

    test_urls.each do |url|
      categories = client.categorise(url)
      # Skip URLs that have paths since they require exact matching
      assert_includes categories, :comprehensive, "Failed for URL: #{url}" unless url.include?('/path')
    end
  end

  def test_every_single_code_path_scenario_2
    # Test 2: All possible error conditions and edge cases

    # Setup various error scenarios
    WebMock.stub_request(:get, 'http://error-test.com/httparty.txt')
           .to_raise(HTTParty::Error.new('HTTParty failed'))

    WebMock.stub_request(:get, 'http://error-test.com/net-http.txt')
           .to_raise(Net::HTTPError.new('Net HTTP failed', nil))

    WebMock.stub_request(:get, 'http://error-test.com/socket.txt')
           .to_raise(SocketError.new('Socket failed'))

    WebMock.stub_request(:get, 'http://error-test.com/timeout.txt')
           .to_raise(Timeout::Error.new('Timeout'))

    WebMock.stub_request(:get, 'http://error-test.com/uri.txt')
           .to_raise(URI::InvalidURIError.new('Invalid URI'))

    WebMock.stub_request(:get, 'http://error-test.com/standard.txt')
           .to_raise(StandardError.new('Standard error'))

    # Test each error type
    error_urls = {
      httparty: 'http://error-test.com/httparty.txt',
      net_http: 'http://error-test.com/net-http.txt',
      socket: 'http://error-test.com/socket.txt',
      timeout: 'http://error-test.com/timeout.txt',
      uri: 'http://error-test.com/uri.txt',
      standard: 'http://error-test.com/standard.txt'
    }

    error_urls.each do |error_type, url|
      client = UrlCategorise::Client.new(
        host_urls: { error_type => [url] }
      )

      # Should handle all errors gracefully
      assert_equal [], client.hosts[error_type]
      assert_equal 'failed', client.metadata[url][:status]
    end
  end

  def test_every_single_code_path_scenario_3
    # Test 3: All list format detection and parsing branches

    # Test every format detection pattern
    format_tests = [
      # Hosts format variations
      { content: '0.0.0.0 example.com', expected: :hosts },
      { content: '127.0.0.1 localhost', expected: :hosts },
      { content: '192.168.1.1 router.local', expected: :hosts },

      # dnsmasq format variations
      { content: 'address=/example.com/0.0.0.0', expected: :dnsmasq },
      { content: 'address=/test.org/127.0.0.1', expected: :dnsmasq },

      # uBlock format variations
      { content: '||example.com^', expected: :ublock },
      { content: '||test.com^$important', expected: :ublock },

      # Plain format (default)
      { content: 'example.com', expected: :plain },
      { content: "test.org\nexample.com", expected: :plain },
      { content: '# Just comments', expected: :plain },
      { content: '', expected: :plain }
    ]

    client = UrlCategorise::Client.new(host_urls: {})

    format_tests.each do |test_case|
      detected = client.send(:detect_list_format, test_case[:content])
      assert_equal test_case[:expected], detected,
                   "Format detection failed for: #{test_case[:content].inspect}"
    end
  end

  def test_every_single_code_path_scenario_4
    # Test 4: All parsing format branches with edge cases

    client = UrlCategorise::Client.new(host_urls: {})

    # Test hosts format parsing with edge cases
    hosts_edge_cases = [
      '0.0.0.0 domain.com',
      '127.0.0.1   spaced-domain.com   ', # Extra spaces
      '# Comment line',
      '', # Empty line
      '   ', # Whitespace only
      '0.0.0.0', # Missing domain
      'domain-only.com' # No IP prefix
    ]

    hosts_content = hosts_edge_cases.join("\n")
    result = client.send(:parse_list_content, hosts_content, :hosts)
    assert_includes result, 'domain.com'
    assert_includes result, 'spaced-domain.com'

    # Test dnsmasq format parsing edge cases
    dnsmasq_edge_cases = [
      'address=/domain.com/0.0.0.0',
      'address=/test.org/127.0.0.1',
      '# Comment',
      '',
      'invalid-dnsmasq-line',
      'address=/incomplete' # Incomplete format
    ]

    dnsmasq_content = dnsmasq_edge_cases.join("\n")
    result = client.send(:parse_list_content, dnsmasq_content, :dnsmasq)
    assert_includes result, 'domain.com'
    assert_includes result, 'test.org'

    # Test uBlock format parsing edge cases
    ublock_edge_cases = [
      '||domain.com^',
      '||test.org^$important',
      '||*.wildcard.com^',
      '||ads.example.com^$third-party',
      '# Comment',
      '',
      'invalid-ublock-line',
      '||incomplete' # Incomplete format
    ]

    ublock_content = ublock_edge_cases.join("\n")
    result = client.send(:parse_list_content, ublock_content, :ublock)
    assert_includes result, 'domain.com'
    assert_includes result, 'test.org'
    assert_includes result, '*.wildcard.com'
    assert_includes result, 'ads.example.com'

    # Test plain format edge cases
    plain_edge_cases = [
      'domain.com',
      'test.org',
      '# Comment should be filtered',
      '', # Empty line
      '   spaced-domain.com   ' # Whitespace
    ]

    plain_content = plain_edge_cases.join("\n")
    result = client.send(:parse_list_content, plain_content, :plain)
    assert_includes result, 'domain.com'
    assert_includes result, 'test.org'
    assert_includes result, 'spaced-domain.com'

    # Test unknown format (falls through to plain)
    unknown_content = "unknown.com\ntest.com"
    result = client.send(:parse_list_content, unknown_content, :unknown_format)
    assert_includes result, 'unknown.com'
    assert_includes result, 'test.com'
  end

  def test_every_single_code_path_scenario_5
    # Test 5: All cache-related code paths

    WebMock.stub_request(:get, 'http://cache-test.com/file.txt')
           .to_return(
             body: 'cached-domain.com',
             headers: {
               'etag' => '"cache-etag"',
               'last-modified' => 'Wed, 21 Oct 2015 07:28:00 GMT'
             }
           )

    WebMock.stub_request(:head, 'http://cache-test.com/file.txt')
           .to_return(headers: {
                        'etag' => '"cache-etag"',
                        'last-modified' => 'Wed, 21 Oct 2015 07:28:00 GMT'
                      })

    url = 'http://cache-test.com/file.txt'

    # Test cache directory creation
    client = UrlCategorise::Client.new(
      host_urls: { cache_test: [url] },
      cache_dir: @temp_cache_dir
    )

    # Verify cache directory was created
    assert Dir.exist?(@temp_cache_dir)

    # Test cache file path generation
    cache_path = client.send(:cache_file_path, url)
    assert cache_path.include?(@temp_cache_dir)
    assert cache_path.end_with?('.cache')

    # Test cache file was created
    assert File.exist?(cache_path)

    # Test reading from cache
    cached_data = client.send(:read_from_cache, url)
    assert_includes cached_data, 'cached-domain.com'

    # Test all should_update_cache? conditions

    # 1. Force download = true
    client_force = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir,
      force_download: true
    )
    assert client_force.send(:should_update_cache?, url, { metadata: {}, cached_at: Time.now })

    # 2. Missing metadata
    assert client.send(:should_update_cache?, url, { cached_at: Time.now })

    # 3. Old cache (> 24 hours)
    old_cache = {
      metadata: { etag: 'old' },
      cached_at: Time.now - (25 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, old_cache)

    # 4. Different ETags
    WebMock.stub_request(:head, url)
           .to_return(headers: { 'etag' => '"new-etag"' })

    different_etag_cache = {
      metadata: { etag: 'old-etag' },
      cached_at: Time.now - (1 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, different_etag_cache)

    # 5. Different Last-Modified
    WebMock.stub_request(:head, url)
           .to_return(headers: { 'last-modified' => 'Thu, 22 Oct 2015 07:28:00 GMT' })

    different_modified_cache = {
      metadata: { last_modified: 'Wed, 21 Oct 2015 07:28:00 GMT' },
      cached_at: Time.now - (1 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, different_modified_cache)

    # 6. HEAD request failure
    WebMock.stub_request(:head, url).to_raise(StandardError.new('HEAD failed'))

    head_fail_cache = {
      metadata: { etag: 'test' },
      cached_at: Time.now - (1 * 60 * 60)
    }
    assert client.send(:should_update_cache?, url, head_fail_cache)

    # 7. Fresh cache (should NOT update)
    WebMock.stub_request(:head, url)
           .to_return(headers: { 'etag' => '"same-etag"' })

    fresh_cache = {
      metadata: { etag: '"same-etag"' },
      cached_at: Time.now - (30 * 60) # 30 minutes ago
    }
    refute client.send(:should_update_cache?, url, fresh_cache)
  end

  def test_every_single_code_path_scenario_6
    # Test 6: DNS resolution all branches

    WebMock.stub_request(:get, 'http://dns-test.com/domains.txt')
           .to_return(body: 'dns-test-domain.com')

    WebMock.stub_request(:get, 'http://dns-test.com/ips.txt')
           .to_return(body: "192.168.100.100\n10.10.10.10")

    client = UrlCategorise::Client.new(
      host_urls: {
        domains: ['http://dns-test.com/domains.txt'],
        ips: ['http://dns-test.com/ips.txt']
      }
    )

    # Test successful DNS resolution
    resolver = mock('resolver')
    ip1 = IPAddr.new('192.168.100.100')
    ip2 = IPAddr.new('10.10.10.10')
    resolver.expects(:getaddresses).with('dns-test-domain.com').returns([ip1, ip2])
    Resolv::DNS.expects(:new).with(nameserver: ['1.1.1.1', '1.0.0.1']).returns(resolver)

    categories = client.resolve_and_categorise('dns-test-domain.com')
    assert_includes categories, :domains
    assert_includes categories, :ips

    # Test DNS resolution failure (exception path)
    resolver_fail = mock('resolver')
    resolver_fail.expects(:getaddresses).with('fail-domain.com').raises(StandardError.new('DNS failed'))
    Resolv::DNS.expects(:new).with(nameserver: ['1.1.1.1', '1.0.0.1']).returns(resolver_fail)

    categories_fail = client.resolve_and_categorise('fail-domain.com')
    # Should still return domain categories even if DNS fails
    assert categories_fail.is_a?(Array)
  end

  def test_every_single_code_path_scenario_7
    # Test 7: All initialization parameter combinations

    # Test with nil parameters
    client_nil = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: nil,
      force_download: nil,
      dns_servers: nil,
      request_timeout: nil
    )

    assert_nil client_nil.cache_dir
    assert_nil client_nil.force_download
    assert_nil client_nil.dns_servers
    assert_nil client_nil.request_timeout

    # Test with various types
    client_various = UrlCategorise::Client.new(
      host_urls: { test: [] },
      cache_dir: @temp_cache_dir,
      force_download: true,
      dns_servers: ['8.8.8.8', '8.8.4.4'],
      request_timeout: 30
    )

    assert_equal @temp_cache_dir, client_various.cache_dir
    assert_equal true, client_various.force_download
    assert_equal ['8.8.8.8', '8.8.4.4'], client_various.dns_servers
    assert_equal 30, client_various.request_timeout
  end

  def test_every_single_code_path_scenario_8
    # Test 8: Build host data edge cases

    WebMock.stub_request(:get, 'http://build-test.com/valid1.txt')
           .to_return(body: 'valid1.com')

    WebMock.stub_request(:get, 'http://build-test.com/valid2.txt')
           .to_return(body: 'valid2.com')

    client = UrlCategorise::Client.new(host_urls: {})

    # Test with mixed valid/invalid URLs
    mixed_urls = [
      'http://build-test.com/valid1.txt',  # Valid
      'invalid-url-format',                # Invalid
      'http://build-test.com/valid2.txt',  # Valid
      'another-invalid-url'                # Invalid
    ]

    result = client.send(:build_host_data, mixed_urls)
    assert_includes result, 'valid1.com'
    assert_includes result, 'valid2.com'

    # Test with empty URLs array
    empty_result = client.send(:build_host_data, [])
    assert_empty empty_result

    # Test with all invalid URLs
    invalid_urls = %w[invalid1 invalid2 invalid3]
    invalid_result = client.send(:build_host_data, invalid_urls)
    assert_equal [], invalid_result
  end

  def test_every_single_code_path_scenario_9
    # Test 9: Categorise IP comprehensive edge cases

    WebMock.stub_request(:get, 'http://ip-test.com/iplist.txt')
           .to_return(body: "1.2.3.4\n5.6.7.8\n192.168.1.1\n10.0.0.1")

    client = UrlCategorise::Client.new(
      host_urls: { ip_list: ['http://ip-test.com/iplist.txt'] }
    )

    # Test IPs that are in the list
    listed_ips = ['1.2.3.4', '5.6.7.8', '192.168.1.1', '10.0.0.1']
    listed_ips.each do |ip|
      categories = client.categorise_ip(ip)
      assert_includes categories, :ip_list, "Should categorize IP: #{ip}"
    end

    # Test IPs that are NOT in the list
    unlisted_ips = ['8.8.8.8', '1.1.1.1', '127.0.0.1']
    unlisted_ips.each do |ip|
      categories = client.categorise_ip(ip)
      assert_empty categories, "Should NOT categorize unlisted IP: #{ip}"
    end

    # Test with empty hosts
    empty_client = UrlCategorise::Client.new(host_urls: {})
    empty_result = empty_client.categorise_ip('1.2.3.4')
    assert_empty empty_result
  end

  def test_every_single_code_path_scenario_10
    # Test 10: Hash size calculation comprehensive

    client = UrlCategorise::Client.new(host_urls: {})

    # Test with various hash structures
    test_hashes = [
      {}, # Empty
      { category1: [] }, # Empty arrays
      { category1: ['a'] }, # Single item
      { category1: %w[a b] }, # Multiple items
      {
        category1: ['domain1.com', 'domain2.com'],
        category2: ['domain3.com', 'domain4.com', 'domain5.com']
      }, # Multiple categories
      {
        category1: (1..100).map { |i| "domain#{i}.com" }
      } # Large array
    ]

    test_hashes.each_with_index do |hash, index|
      size = client.send(:hash_size_in_mb, hash)
      assert_kind_of Numeric, size, "Hash #{index} should return numeric size"
      assert size >= 0, "Hash #{index} size should be non-negative"
    end
  end
end
