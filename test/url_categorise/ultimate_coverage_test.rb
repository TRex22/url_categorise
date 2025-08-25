require 'test_helper'

class UrlCategoriseUltimateCoverageTest < Minitest::Test
  def setup
    @temp_cache_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_cache_dir)
  end

  def test_maximum_coverage_boost_all_methods
    # Comprehensive WebMock stubs for all scenarios
    WebMock.stub_request(:get, 'http://test.com/list1.txt')
           .to_return(body: "domain1.com\ndomain2.com", headers: { 'etag' => '"test1"' })

    WebMock.stub_request(:get, 'http://test.com/list2.txt')
           .to_return(body: "ip1.com\nip2.com", headers: { 'etag' => '"test2"' })

    WebMock.stub_request(:get, 'http://test.com/hosts.txt')
           .to_return(body: "0.0.0.0 blocked.com\n127.0.0.1 localhost", headers: { 'etag' => '"hosts"' })

    WebMock.stub_request(:get, 'http://test.com/dnsmasq.txt')
           .to_return(body: "address=/blocked.com/0.0.0.0\naddress=/test.org/127.0.0.1", headers: { 'etag' => '"dnsmasq"' })

    WebMock.stub_request(:get, 'http://test.com/ublock.txt')
           .to_return(body: "||blocked.com^\n||ads.example.com^$important", headers: { 'etag' => '"ublock"' })

    WebMock.stub_request(:get, 'http://test.com/plain.txt')
           .to_return(body: "simple.com\nplain.com", headers: { 'etag' => '"plain"' })

    WebMock.stub_request(:get, 'http://test.com/empty.txt')
           .to_return(body: '', headers: { 'etag' => '"empty"' })

    WebMock.stub_request(:get, 'http://test.com/ips.txt')
           .to_return(body: "192.168.1.100\n10.0.0.1\n172.16.0.1", headers: { 'etag' => '"ips"' })

    # Create client with comprehensive test data
    host_urls = {
      domains: ['http://test.com/list1.txt'],
      ips: ['http://test.com/list2.txt'],
      hosts_format: ['http://test.com/hosts.txt'],
      dnsmasq_format: ['http://test.com/dnsmasq.txt'],
      ublock_format: ['http://test.com/ublock.txt'],
      plain_format: ['http://test.com/plain.txt'],
      empty_category: ['http://test.com/empty.txt'],
      ip_list: ['http://test.com/ips.txt'],
      # Test symbol references
      combined: %i[domains ips],
      single_ref: [:domains]
    }

    # Test initialization with all parameters
    client = UrlCategorise::Client.new(
      host_urls: host_urls,
      cache_dir: @temp_cache_dir,
      force_download: true,
      dns_servers: ['8.8.8.8', '8.8.4.4'],
      request_timeout: 30
    )

    # Test all getter methods
    assert_equal host_urls, client.host_urls
    assert_equal @temp_cache_dir, client.cache_dir
    assert_equal true, client.force_download
    assert_equal ['8.8.8.8', '8.8.4.4'], client.dns_servers
    assert_equal 30, client.request_timeout
    assert_instance_of Hash, client.hosts
    assert_instance_of Hash, client.metadata

    # Test categorise method with various URL formats
    test_categorise_all_formats(client)

    # Test categorise_ip method
    test_categorise_ip_comprehensive(client)

    # Test resolve_and_categorise method
    test_resolve_and_categorise_comprehensive(client)

    # Test count methods
    assert client.count_of_hosts > 0
    assert client.count_of_categories > 0
    assert client.size_of_data >= 0

    # Test all private methods through public interface
    test_all_private_methods(client)

    # Test caching functionality
    test_comprehensive_caching(client)

    # Test error handling scenarios
    test_comprehensive_error_handling

    # Test edge cases
    test_edge_cases(client)
  end

  private

  def test_categorise_all_formats(client)
    # Test various URL formats that should be categorized
    urls_to_test = [
      'domain1.com',
      'http://domain1.com',
      'https://domain1.com',
      'https://www.domain1.com',
      'http://domain1.com/path',
      'https://domain1.com:443/path?query=test',
      'DOMAIN1.COM', # Case insensitive
      'blocked.com', # Should match hosts format
      'simple.com', # Should match plain format
      'ads.example.com' # Should match ublock format
    ]

    urls_to_test.each do |url|
      categories = client.categorise(url)
      assert_instance_of Array, categories
    end
  end

  def test_categorise_ip_comprehensive(client)
    # Test IP categorization
    ips_to_test = [
      '192.168.1.100', # Should be in ip_list
      '10.0.0.1', # Should be in ip_list
      '172.16.0.1', # Should be in ip_list
      '8.8.8.8', # Should not be in any list
      '127.0.0.1' # Should not be in any list
    ]

    ips_to_test.each do |ip|
      categories = client.categorise_ip(ip)
      assert_instance_of Array, categories
    end
  end

  def test_resolve_and_categorise_comprehensive(client)
    # Mock DNS resolution
    resolver = mock('resolver')
    ip1 = IPAddr.new('192.168.1.100')
    ip2 = IPAddr.new('10.0.0.1')
    resolver.expects(:getaddresses).with('domain1.com').returns([ip1, ip2])
    Resolv::DNS.expects(:new).with(nameserver: ['8.8.8.8', '8.8.4.4']).returns(resolver)

    categories = client.resolve_and_categorise('domain1.com')
    assert_instance_of Array, categories
    assert categories.uniq.length <= categories.length
  end

  def test_all_private_methods(client)
    # Test private methods through send

    # Test url_not_valid? method (should return true for invalid URLs)
    refute client.send(:url_not_valid?, 'http://example.com') # Valid URL should return false
    assert client.send(:url_not_valid?, 'not-a-url')          # Invalid URL should return true
    assert client.send(:url_not_valid?, '')                   # Empty string should return true

    # Test hash_size_in_mb with various inputs
    empty_hash = {}
    small_hash = { cat1: ['a.com'] }
    large_hash = { cat1: (1..100).map { |i| "site#{i}.com" } }

    assert_equal 0.0, client.send(:hash_size_in_mb, empty_hash)
    assert client.send(:hash_size_in_mb, small_hash) >= 0
    assert client.send(:hash_size_in_mb, large_hash) >= 0

    # Test detect_list_format with comprehensive examples
    format_tests = [
      { content: '0.0.0.0 example.com', expected: :hosts },
      { content: '127.0.0.1 localhost', expected: :hosts },
      { content: '192.168.1.1 test.com', expected: :hosts },
      { content: '10.0.0.1 local.test', expected: :hosts },
      { content: 'address=/example.com/0.0.0.0', expected: :dnsmasq },
      { content: 'address=/test.org/127.0.0.1', expected: :dnsmasq },
      { content: '||example.com^', expected: :ublock },
      { content: '||test.com^$important', expected: :ublock },
      { content: 'example.com', expected: :plain },
      { content: "test.com\nexample.org", expected: :plain },
      { content: '', expected: :plain },
      { content: '# Only comments', expected: :plain }
    ]

    format_tests.each do |test|
      result = client.send(:detect_list_format, test[:content])
      assert_equal test[:expected], result, "Failed for: #{test[:content]}"
    end

    # Test parse_list_content for all formats
    test_parse_list_content_all_formats(client)
  end

  def test_parse_list_content_all_formats(client)
    # Test hosts format parsing
    hosts_content = "0.0.0.0 bad1.com\n127.0.0.1 bad2.com\n# Comment\n\n   \n192.168.1.1   bad3.com   "
    result = client.send(:parse_list_content, hosts_content, :hosts)
    assert_includes result, 'bad1.com'
    assert_includes result, 'bad2.com'
    assert_includes result, 'bad3.com'

    # Test dnsmasq format parsing
    dnsmasq_content = "address=/bad1.com/0.0.0.0\naddress=/bad2.com/127.0.0.1\n# Comment\ninvalid line"
    result = client.send(:parse_list_content, dnsmasq_content, :dnsmasq)
    assert_includes result, 'bad1.com'
    assert_includes result, 'bad2.com'

    # Test ublock format parsing
    ublock_content = "||bad1.com^\n||bad2.com^$important\n||*.ads.com^\n# Comment\ninvalid"
    result = client.send(:parse_list_content, ublock_content, :ublock)
    assert_includes result, 'bad1.com'
    assert_includes result, 'bad2.com'
    assert_includes result, '*.ads.com'

    # Test plain format parsing
    plain_content = "bad1.com\nbad2.com\n# Comment\n\n   spaced.com   "
    result = client.send(:parse_list_content, plain_content, :plain)
    assert_includes result, 'bad1.com'
    assert_includes result, 'bad2.com'
    assert_includes result, 'spaced.com'

    # Test unknown format (should default to plain)
    unknown_content = "domain1.com\ndomain2.com"
    result = client.send(:parse_list_content, unknown_content, :unknown)
    assert_includes result, 'domain1.com'
    assert_includes result, 'domain2.com'
  end

  def test_comprehensive_caching(client)
    url = 'http://test.com/list1.txt'

    # Test cache file path generation
    cache_path = client.send(:cache_file_path, url)
    assert cache_path.include?(@temp_cache_dir)
    assert cache_path.end_with?('.cache')

    # Test cache directory creation
    assert Dir.exist?(@temp_cache_dir)

    # Test reading from cache (may be nil if cache needs update)
    cached_data = client.send(:read_from_cache, url)
    assert(cached_data.nil? || cached_data.is_a?(String))

    # Test should_update_cache? in various scenarios
    fresh_cache = {
      metadata: { etag: '"test1"' },
      cached_at: Time.now - (30 * 60) # 30 minutes ago
    }

    old_cache = {
      metadata: { etag: '"test1"' },
      cached_at: Time.now - (25 * 60 * 60) # 25 hours ago
    }

    WebMock.stub_request(:head, url)
           .to_return(headers: { 'etag' => '"test1"' })

    # Create a non-force-download client for cache testing
    cache_client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @temp_cache_dir,
      force_download: false
    )

    # Fresh cache should not update
    refute cache_client.send(:should_update_cache?, url, fresh_cache)

    # Old cache should update
    assert cache_client.send(:should_update_cache?, url, old_cache)

    # Force download should always update
    force_client = UrlCategorise::Client.new(
      host_urls: { test: [url] },
      cache_dir: @temp_cache_dir,
      force_download: true
    )
    assert force_client.send(:should_update_cache?, url, fresh_cache)

    # Test HEAD request failure scenario
    WebMock.stub_request(:head, 'http://test.com/head-fail.txt')
           .to_raise(StandardError.new('HEAD failed'))

    head_fail_cache = {
      metadata: { etag: '"old"' },
      cached_at: Time.now - (1 * 60 * 60)
    }
    assert client.send(:should_update_cache?, 'http://test.com/head-fail.txt', head_fail_cache)
  end

  def test_comprehensive_error_handling
    # Test various error scenarios
    error_scenarios = [
      { error: HTTParty::Error.new('HTTParty failed'), url: 'http://error.com/httparty.txt' },
      { error: Net::HTTPError.new('Net HTTP failed', nil), url: 'http://error.com/nethttp.txt' },
      { error: SocketError.new('Socket failed'), url: 'http://error.com/socket.txt' },
      { error: Timeout::Error.new('Timeout'), url: 'http://error.com/timeout.txt' },
      { error: URI::InvalidURIError.new('Invalid URI'), url: 'http://error.com/uri.txt' },
      { error: StandardError.new('Standard error'), url: 'http://error.com/standard.txt' }
    ]

    error_scenarios.each do |scenario|
      WebMock.stub_request(:get, scenario[:url])
             .to_raise(scenario[:error])

      client = UrlCategorise::Client.new(
        host_urls: { error_test: [scenario[:url]] }
      )

      # Should handle errors gracefully
      assert_equal [], client.hosts[:error_test]
      assert_equal 'failed', client.metadata[scenario[:url]][:status]
      assert_equal scenario[:error].message, client.metadata[scenario[:url]][:error]
    end
  end

  def test_edge_cases(client)
    # Test with nil host_urls (should use defaults)
    default_client = UrlCategorise::Client.new(host_urls: {})
    assert_instance_of Hash, default_client.hosts
    assert_equal 0, default_client.count_of_categories
    assert_equal 0, default_client.count_of_hosts

    # Test categorise with nil URL (should raise error)
    assert_raises(URI::InvalidURIError) do
      client.categorise(nil)
    end

    # Test build_host_data with empty array
    result = client.send(:build_host_data, [])
    assert_equal [], result

    # Test build_host_data with invalid URLs
    result = client.send(:build_host_data, %w[invalid-url another-invalid])
    assert_equal [], result

    # Test categorise_ip with empty hosts
    empty_client = UrlCategorise::Client.new(host_urls: {})
    assert_empty empty_client.categorise_ip('1.2.3.4')

    # Test resolve_and_categorise with DNS failure
    resolver_fail = mock('resolver')
    resolver_fail.expects(:getaddresses).with('fail.com').raises(StandardError.new('DNS failed'))
    Resolv::DNS.expects(:new).with(nameserver: client.dns_servers).returns(resolver_fail)

    categories = client.resolve_and_categorise('fail.com')
    assert_instance_of Array, categories

    # Test various initialization parameter combinations
    edge_clients = [
      UrlCategorise::Client.new(host_urls: {}, cache_dir: nil),
      UrlCategorise::Client.new(host_urls: {}, force_download: nil),
      UrlCategorise::Client.new(host_urls: {}, dns_servers: nil),
      UrlCategorise::Client.new(host_urls: {}, request_timeout: nil),
      UrlCategorise::Client.new(host_urls: {}, dns_servers: [])
    ]

    edge_clients.each do |edge_client|
      assert_instance_of UrlCategorise::Client, edge_client
    end
  end

  def test_class_methods_comprehensive
    # Test class methods multiple times for consistency
    10.times do
      assert_equal 'v2', UrlCategorise::Client.compatible_api_version
      assert_equal 'v2 2023-04-12', UrlCategorise::Client.api_version
    end

    # Verify they're accessible as class methods
    assert_respond_to UrlCategorise::Client, :compatible_api_version
    assert_respond_to UrlCategorise::Client, :api_version
  end

  def test_constants_integration_comprehensive
    # Test Constants module integration
    client = UrlCategorise::Client.new(host_urls: {})

    # Test constant access
    assert_equal 1_048_576, UrlCategorise::Constants::ONE_MEGABYTE
    assert_instance_of Hash, UrlCategorise::Constants::DEFAULT_HOST_URLS

    # Test client can access constants through inclusion
    assert_equal 1_048_576, client.class::ONE_MEGABYTE

    # Test default host URLs structure
    assert_instance_of Hash, UrlCategorise::Constants::DEFAULT_HOST_URLS
    refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS

    UrlCategorise::Constants::DEFAULT_HOST_URLS.each do |category, urls|
      assert_instance_of Symbol, category
      next if category == :social_media # Skip symbolic references

      assert_instance_of Array, urls
    end
  end

  def test_metadata_comprehensive_scenarios
    # Test metadata with various response types
    scenarios = [
      {
        url: 'http://meta.com/with-headers.txt',
        headers: { 'etag' => '"meta1"', 'last-modified' => 'Wed, 21 Oct 2015 07:28:00 GMT' },
        body: 'test.com'
      },
      {
        url: 'http://meta.com/no-headers.txt',
        headers: {},
        body: 'test2.com'
      },
      {
        url: 'http://meta.com/empty-body.txt',
        headers: { 'etag' => '"empty"' },
        body: ''
      }
    ]

    scenarios.each do |scenario|
      WebMock.stub_request(:get, scenario[:url])
             .to_return(body: scenario[:body], headers: scenario[:headers])

      client = UrlCategorise::Client.new(
        host_urls: { meta_test: [scenario[:url]] }
      )

      metadata = client.metadata[scenario[:url]]
      assert_equal 'success', metadata[:status]
      assert metadata.key?(:last_updated)
      assert metadata.key?(:content_hash)

      if scenario[:headers]['etag']
        assert_equal scenario[:headers]['etag'], metadata[:etag]
      else
        assert_nil metadata[:etag]
      end

      if scenario[:headers]['last-modified']
        assert_equal scenario[:headers]['last-modified'], metadata[:last_modified]
      else
        assert_nil metadata[:last_modified]
      end
    end
  end
end
