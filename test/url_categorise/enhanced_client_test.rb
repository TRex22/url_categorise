require "test_helper"

class UrlCategoriseEnhancedClientTest < Minitest::Test
  def setup
    @temp_cache_dir = Dir.mktmpdir
    WebMock.stub_request(:get, "http://example.com/malware.txt")
           .to_return(
             body: "0.0.0.0 badsite.com\n0.0.0.0 evilsite.com",
             headers: { 'etag' => '"abc123"', 'last-modified' => 'Wed, 21 Oct 2015 07:28:00 GMT' }
           )
    WebMock.stub_request(:head, "http://example.com/malware.txt")
           .to_return(
             headers: { 'etag' => '"abc123"', 'last-modified' => 'Wed, 21 Oct 2015 07:28:00 GMT' }
           )
  end

  def teardown
    FileUtils.rm_rf(@temp_cache_dir)
  end

  def test_client_with_cache_directory
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir
    )
    
    assert_instance_of Hash, client.hosts
    assert Dir.exist?(@temp_cache_dir)
    
    # Check cache files were created
    cache_files = Dir.glob(File.join(@temp_cache_dir, "*.cache"))
    refute_empty cache_files
  end

  def test_client_reads_from_cache_on_second_initialization
    # First initialization creates cache
    UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir
    )
    
    # Second initialization should read from cache
    # Keep HEAD stub for cache validation, but ensure GET request fails if called
    WebMock.stub_request(:get, "http://example.com/malware.txt")
           .to_raise(StandardError.new("Should not make GET request when using cache"))
    
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir
    )
    
    assert_instance_of Hash, client.hosts
    refute_empty client.hosts
  end

  def test_force_download_option
    # First create cache
    UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir
    )
    
    # Force download should ignore cache
    WebMock.stub_request(:get, "http://example.com/malware.txt")
           .to_return(body: "0.0.0.0 newbadsite.com")
    
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @temp_cache_dir,
      force_download: true
    )
    
    assert_includes client.hosts[:malware], "newbadsite.com"
  end

  def test_categorise_ip_method
    client = UrlCategorise::Client.new(host_urls: test_host_urls)
    
    # Test with IP that's not in any list
    categories = client.categorise_ip("192.168.1.1")
    assert_empty categories
    
    # Test with IP that would be in a sanctions list (mocked)
    WebMock.stub_request(:get, "http://example.com/sanctions.txt")
           .to_return(body: "192.168.1.100\n10.0.0.1")
    
    client_with_ip = UrlCategorise::Client.new(
      host_urls: { sanctions: ["http://example.com/sanctions.txt"] }
    )
    
    categories = client_with_ip.categorise_ip("192.168.1.100")
    assert_includes categories, :sanctions
  end

  def test_resolve_and_categorise_method
    # Mock DNS resolution
    resolver = mock('resolver')
    resolver.expects(:getaddresses).with('badsite.com').returns([IPAddr.new('192.168.1.100')])
    Resolv::DNS.expects(:new).with(nameserver: ['1.1.1.1', '1.0.0.1']).returns(resolver)
    
    # Mock IP in sanctions list
    WebMock.stub_request(:get, "http://example.com/sanctions.txt")
           .to_return(body: "192.168.1.100")
    
    client = UrlCategorise::Client.new(
      host_urls: { 
        malware: ["http://example.com/malware.txt"],
        sanctions: ["http://example.com/sanctions.txt"]
      }
    )
    
    categories = client.resolve_and_categorise('badsite.com')
    assert_includes categories, :malware
    assert_includes categories, :sanctions
  end

  def test_different_list_formats
    # Test hosts format
    WebMock.stub_request(:get, "http://example.com/hosts.txt")
           .to_return(body: "0.0.0.0 badsite.com\n127.0.0.1 localhost")
    
    # Test plain format
    WebMock.stub_request(:get, "http://example.com/plain.txt")
           .to_return(body: "badsite.com\ngoodsite.com")
    
    # Test dnsmasq format
    WebMock.stub_request(:get, "http://example.com/dnsmasq.txt")
           .to_return(body: "address=/badsite.com/0.0.0.0\naddress=/evilsite.com/0.0.0.0")
    
    # Test ublock format
    WebMock.stub_request(:get, "http://example.com/ublock.txt")
           .to_return(body: "||badsite.com^\n||evilsite.com^$important")
    
    client = UrlCategorise::Client.new(
      host_urls: {
        hosts_format: ["http://example.com/hosts.txt"],
        plain_format: ["http://example.com/plain.txt"],
        dnsmasq_format: ["http://example.com/dnsmasq.txt"],
        ublock_format: ["http://example.com/ublock.txt"]
      }
    )
    
    # Check that badsite.com appears in all categories
    %i[hosts_format plain_format dnsmasq_format ublock_format].each do |category|
      assert_includes client.hosts[category], "badsite.com"
    end
  end

  def test_metadata_storage
    client = UrlCategorise::Client.new(host_urls: test_host_urls)
    
    assert_instance_of Hash, client.metadata
    refute_empty client.metadata
    
    # Check metadata contains expected fields
    metadata = client.metadata.values.first
    assert metadata.key?(:last_updated)
    assert metadata.key?(:etag)
    assert metadata.key?(:content_hash)
  end

  def test_custom_dns_servers
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      dns_servers: ['8.8.8.8', '8.8.4.4']
    )
    
    assert_equal ['8.8.8.8', '8.8.4.4'], client.dns_servers
  end

  private

  def test_host_urls
    {
      malware: ["http://example.com/malware.txt"]
    }
  end
end