require 'test_helper'

class UrlCategoriseComprehensiveCoverageTest < Minitest::Test
  def setup
    @temp_hosts_file = 'test_comprehensive_hosts.hosts'
    @temp_regex_file = 'test_regex_patterns.txt'
    
    # Create test host file with various formats
    File.write(@temp_hosts_file, <<~HOSTS
      0.0.0.0 example.com
      0.0.0.0 malware.example.com
      127.0.0.1 localhost.test
      # This is a comment
      
      # Another comment
      blocked-domain.com
    HOSTS
    )
    
    # Create test regex patterns file
    File.write(@temp_regex_file, <<~PATTERNS
      # Source: video_hosting
      .*youtube\\.com/watch\\?v=.*
      vimeo\\.com/\\d+
      
      # Source: social_media
      .*facebook\\.com/.*
      .*twitter\\.com/.*
    PATTERNS
    )
  end

  def teardown
    File.delete(@temp_hosts_file) if File.exist?(@temp_hosts_file)
    File.delete(@temp_regex_file) if File.exist?(@temp_regex_file)
  end

  def test_categorise_ip_method
    client = UrlCategorise::Client.new(
      host_urls: { malware: ["file://#{@temp_hosts_file}"] }
    )

    # Test IP categorization
    result = client.categorise_ip("127.0.0.1")
    # Should not match since our test file has domains, not IPs
    assert_equal [], result
  end

  def test_categorise_ip_with_iab_compliance
    client = UrlCategorise::Client.new(
      host_urls: { malware: ["file://#{@temp_hosts_file}"] },
      iab_compliance: true
    )

    result = client.categorise_ip("127.0.0.1")
    assert_kind_of Array, result
  end

  def test_blog_url_method
    client = UrlCategorise::Client.new(host_urls: {})

    # Test positive cases
    assert_equal true, client.blog_url?("https://example.com/blog/post")
    assert_equal true, client.blog_url?("https://blog.example.com")
    assert_equal true, client.blog_url?("https://myblog-site.com")
    assert_equal true, client.blog_url?("https://wordpress.com/site")
    assert_equal true, client.blog_url?("https://example.blogspot.com")
    assert_equal true, client.blog_url?("https://medium.com/@user/story")
    assert_equal true, client.blog_url?("https://substack.com/post")
    assert_equal true, client.blog_url?("https://example.com/post/123")
    assert_equal true, client.blog_url?("https://example.com/article/title")
    assert_equal true, client.blog_url?("https://my-diary.com")
    assert_equal true, client.blog_url?("https://journal.example.com")

    # Test negative cases
    assert_equal false, client.blog_url?("https://google.com/search?q=blog")
    assert_equal false, client.blog_url?("https://bing.com/search?q=blog+post")
    assert_equal false, client.blog_url?("https://yahoo.com/search?q=blog")
    assert_equal false, client.blog_url?("https://duckduckgo.com/?q=blog")
    assert_equal false, client.blog_url?("")
    assert_equal false, client.blog_url?(nil)
  end

  def test_video_url_method_without_regex_categorization
    client = UrlCategorise::Client.new(
      host_urls: {},
      regex_categorization: false
    )

    # Should return false when regex categorization is disabled
    result = client.video_url?("https://youtube.com/watch?v=abc123")
    assert_equal false, result
  end

  def test_video_url_method_with_regex_categorization
    # Create test video hosting file
    video_hosts_file = 'test_video_hosts.hosts'
    File.write(video_hosts_file, <<~HOSTS
      0.0.0.0 youtube.com
      0.0.0.0 vimeo.com
    HOSTS
    )

    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{video_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # Should detect video URLs based on patterns
    assert_equal true, client.video_url?("https://youtube.com/watch?v=abc123")
    assert_equal true, client.video_url?("https://vimeo.com/123456789")
    assert_equal false, client.video_url?("https://youtube.com/")
    assert_equal false, client.video_url?("https://facebook.com/video")

    # Cleanup
    File.delete(video_hosts_file) if File.exist?(video_hosts_file)
  end

  def test_size_of_data_method
    client = UrlCategorise::Client.new(
      host_urls: { test: ["file://#{@temp_hosts_file}"] }
    )

    size = client.size_of_data
    assert_kind_of Numeric, size
    assert size >= 0
  end

  def test_count_of_categories_method
    client = UrlCategorise::Client.new(
      host_urls: { 
        malware: ["file://#{@temp_hosts_file}"],
        phishing: ["file://#{@temp_hosts_file}"]
      }
    )

    count = client.count_of_categories
    assert_equal 2, count
  end

  def test_count_of_hosts_method
    client = UrlCategorise::Client.new(
      host_urls: { test: ["file://#{@temp_hosts_file}"] }
    )

    count = client.count_of_hosts
    assert_kind_of Integer, count
    assert count > 0
  end

  def test_url_valid_private_method
    client = UrlCategorise::Client.new(host_urls: {})

    # Test valid URLs
    assert_equal true, client.send(:url_valid?, "https://example.com")
    assert_equal true, client.send(:url_valid?, "http://test.org")
    assert_equal true, client.send(:url_valid?, "file://test.txt")

    # Test invalid URLs
    assert_equal false, client.send(:url_valid?, nil)
    assert_equal false, client.send(:url_valid?, "")
    assert_equal false, client.send(:url_valid?, :symbol)
  end

  def test_detect_list_format_method
    client = UrlCategorise::Client.new(host_urls: {})

    # Test hosts format detection
    hosts_content = "0.0.0.0 example.com\n127.0.0.1 test.com"
    assert_equal :hosts, client.send(:detect_list_format, hosts_content)

    # Test dnsmasq format detection
    dnsmasq_content = "address=/example.com/127.0.0.1\naddress=/test.com/127.0.0.1"
    assert_equal :dnsmasq, client.send(:detect_list_format, dnsmasq_content)

    # Test ublock format detection
    ublock_content = "||example.com^\n||test.com^"
    assert_equal :ublock, client.send(:detect_list_format, ublock_content)

    # Test plain format (default)
    plain_content = "example.com\ntest.com"
    assert_equal :plain, client.send(:detect_list_format, plain_content)
  end

  def test_parse_list_content_method_hosts_format
    client = UrlCategorise::Client.new(host_urls: {})
    
    content = "0.0.0.0 example.com\n127.0.0.1 test.com\n# comment\n\n"
    result = client.send(:parse_list_content, content, :hosts)
    
    assert_includes result, "example.com"
    assert_includes result, "test.com"
    refute_includes result, "# comment"
  end

  def test_parse_list_content_method_dnsmasq_format
    client = UrlCategorise::Client.new(host_urls: {})
    
    content = "address=/example.com/127.0.0.1\naddress=/test.com/0.0.0.0"
    result = client.send(:parse_list_content, content, :dnsmasq)
    
    assert_includes result, "example.com"
    assert_includes result, "test.com"
  end

  def test_parse_list_content_method_ublock_format
    client = UrlCategorise::Client.new(host_urls: {})
    
    content = "||example.com^\n||test.com$third-party\n"
    result = client.send(:parse_list_content, content, :ublock)
    
    assert_includes result, "example.com"
    assert_includes result, "test.com"
  end

  def test_parse_list_content_method_plain_format
    client = UrlCategorise::Client.new(host_urls: {})
    
    content = "example.com\ntest.com\n# comment\n\n"
    result = client.send(:parse_list_content, content, :plain)
    
    assert_includes result, "example.com"
    assert_includes result, "test.com"
    refute_includes result, "# comment"
  end

  def test_cache_methods
    skip "Cache methods require file system setup" if ENV['SKIP_FILESYSTEM_TESTS']
    
    cache_dir = "/tmp/test_url_cache"
    Dir.mkdir(cache_dir) unless Dir.exist?(cache_dir)

    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: cache_dir,
      force_download: false
    )

    test_url = "https://example.com/test.txt"
    test_hosts = ["example.com", "test.com"]

    # Mock HTTP HEAD request to avoid network calls
    WebMock.stub_request(:head, test_url)
           .to_return(status: 200, headers: { 'etag' => 'test-etag', 'last-modified' => 'Wed, 01 Jan 2025 00:00:00 GMT' })

    # Stub the metadata
    client.instance_variable_get(:@metadata)[test_url] = { etag: 'test-etag', last_modified: 'Wed, 01 Jan 2025 00:00:00 GMT' }

    # Test save_to_cache
    client.send(:save_to_cache, test_url, test_hosts)

    # Test read_from_cache
    cached_data = client.send(:read_from_cache, test_url)
    assert_equal test_hosts, cached_data

    # Cleanup
    FileUtils.rm_rf(cache_dir)
  end

  def test_build_host_data_with_file_url
    client = UrlCategorise::Client.new(host_urls: {})
    
    result = client.send(:build_host_data, ["file://#{@temp_hosts_file}"])
    
    assert_kind_of Array, result
    assert result.length > 0
    assert_includes result, "example.com"
  end

  def test_build_host_data_with_invalid_file_url
    client = UrlCategorise::Client.new(host_urls: {})
    
    result = client.send(:build_host_data, ["file://nonexistent_file.txt"])
    
    assert_equal [], result
  end

  def test_build_host_data_with_http_url
    # Mock HTTP response
    WebMock.stub_request(:get, "https://test.example.com/test.txt")
      .to_return(body: "example.com\ntest.com", status: 200)

    client = UrlCategorise::Client.new(host_urls: {})
    
    result = client.send(:build_host_data, ["https://test.example.com/test.txt"])
    
    assert_kind_of Array, result
    assert_includes result, "example.com"
    assert_includes result, "test.com"
  end

  def test_build_host_data_with_failed_http_request
    # Mock failed HTTP response
    WebMock.stub_request(:get, "https://test.example.com/failed.txt")
      .to_timeout

    client = UrlCategorise::Client.new(host_urls: {})
    
    result = client.send(:build_host_data, ["https://test.example.com/failed.txt"])
    
    assert_equal [], result
  end

  def test_regex_patterns_loading
    client = UrlCategorise::Client.new(
      host_urls: {},
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    patterns = client.instance_variable_get(:@regex_patterns)
    assert_kind_of Hash, patterns
    assert patterns.key?("video_hosting")
    assert patterns.key?("social_media")
  end

  def test_regex_patterns_loading_with_missing_file
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: {},
      regex_categorization: true,
      regex_patterns_file: "nonexistent_patterns.txt"
    )

    output = $stdout.string
    $stdout = original_stdout

    assert_includes output, "Warning: Regex patterns file not found"
  end

  def test_apply_regex_categorisation_method
    client = UrlCategorise::Client.new(
      host_urls: {},
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # Test URL that matches video hosting pattern
    result = client.send(:apply_regex_categorisation, 
                        "https://youtube.com/watch?v=abc123", 
                        [:existing_category, :video_hosting])
    
    assert_includes result, :existing_category
    assert_includes result, :video_hosting
    assert_includes result, :video_hosting_content
  end

  def test_initialize_smart_rules_method
    client = UrlCategorise::Client.new(host_urls: {})
    
    # Test with nil rules
    result = client.send(:initialize_smart_rules, nil)
    assert_kind_of Hash, result

    # Test with custom rules
    custom_rules = { test_category: ["test.com"] }
    result = client.send(:initialize_smart_rules, custom_rules)
    assert_includes result.keys, :test_category
    assert_equal ["test.com"], result[:test_category]
    # Should also include default rules
    assert_includes result.keys, :social_media_platforms
  end

  def test_categories_with_keys_method
    client = UrlCategorise::Client.new(
      host_urls: { 
        test1: ["file://#{@temp_hosts_file}"],
        test2: [:test1],  # Reference to another category
        test3: ["file://#{@temp_hosts_file}"]
      }
    )

    result = client.send(:categories_with_keys)
    assert_kind_of Hash, result
    assert result.key?(:test2)
  end
end
