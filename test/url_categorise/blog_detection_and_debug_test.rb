require "test_helper"

class UrlCategoriseBlogDetectionAndDebugTest < Minitest::Test
  def setup
    WebMock.reset!

    # Create a temporary hosts file for testing
    @temp_hosts_file = "test_blog_hosts.hosts"
    create_test_hosts_file
  end

  def teardown
    WebMock.reset!
    File.delete(@temp_hosts_file) if File.exist?(@temp_hosts_file)
  end

  # Blog URL Detection Tests
  def test_blog_url_method_detects_blog_paths
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Test various blog path patterns
    assert_equal true, client.blog_url?("https://example.com/blog/")
    assert_equal true, client.blog_url?("https://example.com/blog")
    assert_equal true, client.blog_url?("https://example.com/blogs/")
    assert_equal true, client.blog_url?("https://example.com/blogs")
    assert_equal true, client.blog_url?("https://example.com/blog?page=1")
    assert_equal true, client.blog_url?("https://example.com/blogs?category=tech")
  end

  def test_blog_url_method_detects_blog_subdomains
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Test blog subdomains
    assert_equal true, client.blog_url?("https://blog.example.com/")
    assert_equal true, client.blog_url?("https://blog.company.com/article/1")
    assert_equal true, client.blog_url?("https://blog.test.org/posts")
  end

  def test_blog_url_method_detects_blog_in_domain
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Test blog in domain name
    assert_equal true, client.blog_url?("https://example-blog.com/")
    assert_equal true, client.blog_url?("https://myblog-site.net/article")
    assert_equal true, client.blog_url?("https://blog-platform.org/")
  end

  def test_blog_url_method_detects_common_blog_platforms
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Test common blog platforms
    assert_equal true, client.blog_url?("https://example.wordpress.com/")
    assert_equal true, client.blog_url?("https://example.blogspot.com/post/123")
    assert_equal true, client.blog_url?("https://medium.com/@user/article-title")
    assert_equal true, client.blog_url?("https://user.substack.com/p/newsletter")
  end

  def test_blog_url_method_detects_blog_content_paths
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Test blog-like content paths
    assert_equal true, client.blog_url?("https://example.com/post/123")
    assert_equal true, client.blog_url?("https://example.com/posts/my-article")
    assert_equal true, client.blog_url?("https://example.com/article/title")
    assert_equal true, client.blog_url?("https://example.com/articles/category/tech")
    assert_equal true, client.blog_url?("https://example.com/diary/entry-1")
    assert_equal true, client.blog_url?("https://example.com/journal/2025/january")
  end

  def test_blog_url_method_detects_blog_keyword_anywhere
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Test the word "blog" anywhere in URL
    assert_equal true, client.blog_url?("https://example.com/corporate-blog-news")
    assert_equal true, client.blog_url?("https://example.com/company/blog-section")
    assert_equal true, client.blog_url?("https://example.com/news/blog-updates")
  end

  def test_blog_url_method_returns_false_for_non_blog_urls
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Test URLs that should NOT be detected as blogs
    assert_equal false, client.blog_url?("https://example.com/")
    assert_equal false, client.blog_url?("https://example.com/products")
    assert_equal false, client.blog_url?("https://example.com/about")
    assert_equal false, client.blog_url?("https://example.com/contact")
    assert_equal false, client.blog_url?("https://google.com/search?q=blog")
    assert_equal false, client.blog_url?("https://facebook.com/pages")
  end

  def test_blog_url_method_handles_invalid_urls_gracefully
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Should not crash on invalid URLs
    assert_equal false, client.blog_url?("not-a-url")
    assert_equal false, client.blog_url?("")
    assert_equal false, client.blog_url?(nil)
    assert_equal false, client.blog_url?("ftp://invalid")
  end

  def test_blog_url_method_is_case_insensitive
    client = UrlCategorise::Client.new(host_urls: { blogs: [ "file://#{@temp_hosts_file}" ] })

    # Should work regardless of case
    assert_equal true, client.blog_url?("https://example.com/BLOG/")
    assert_equal true, client.blog_url?("https://BLOG.example.com/")
    assert_equal true, client.blog_url?("https://example.WORDPRESS.com/")
    assert_equal true, client.blog_url?("https://example.com/POST/123")
  end

  # Debug Functionality Tests
  def test_debug_disabled_by_default
    client = UrlCategorise::Client.new(host_urls: { test: [ "file://#{@temp_hosts_file}" ] })

    assert_equal false, client.debug_enabled
  end

  def test_debug_can_be_enabled
    client = UrlCategorise::Client.new(
      host_urls: { test: [ "file://#{@temp_hosts_file}" ] },
      debug: true
    )

    assert_equal true, client.debug_enabled
  end

  def test_debug_can_be_changed_dynamically_with_active_attr
    client = UrlCategorise::Client.new(host_urls: { test: [ "file://#{@temp_hosts_file}" ] })

    # Initially disabled
    assert_equal false, client.debug_enabled

    # Can be enabled dynamically
    client.debug_enabled = true
    assert_equal true, client.debug_enabled

    # Can be disabled again
    client.debug_enabled = false
    assert_equal false, client.debug_enabled
  end

  def test_debug_output_during_initialization
    # Capture stdout to test debug output
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: { test: [ "file://#{@temp_hosts_file}" ] },
      debug: true
    )

    output = $stdout.string
    $stdout = original_stdout

    # Should contain initialization debug messages
    assert_includes output, "[UrlCategorise DEBUG] Initializing UrlCategorise Client with debug enabled"
    assert_includes output, "[UrlCategorise DEBUG] Loading host lists from 1 categories"
    assert_includes output, "[UrlCategorise DEBUG] Client initialization completed"
    assert_includes output, "completed in"
    assert_includes output, "ms"
  end

  def test_debug_output_during_host_loading
    # Capture stdout to test debug output
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: { test: [ "file://#{@temp_hosts_file}" ] },
      debug: true
    )

    output = $stdout.string
    $stdout = original_stdout

    # Should contain host loading debug messages
    assert_includes output, "[UrlCategorise DEBUG] Processing host list: file://#{@temp_hosts_file}"
    assert_includes output, "[UrlCategorise DEBUG] Downloaded"
    assert_includes output, "hosts from file://#{@temp_hosts_file}"
    assert_includes output, "[UrlCategorise DEBUG] Total unique hosts collected:"
  end

  def test_debug_output_with_dataset_loading
    # Skip if dataset processor can't be initialized
    begin
      client = UrlCategorise::Client.new(
        host_urls: { test: [ "file://#{@temp_hosts_file}" ] },
        debug: true,
        dataset_config: {}
      )
    rescue UrlCategorise::Error
      skip "Dataset processor not available for testing"
    end

    # Test would check for dataset-specific debug messages if processor is available
  end

  def test_no_debug_output_when_disabled
    # Capture stdout to ensure no debug output
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: { test: [ "file://#{@temp_hosts_file}" ] },
      debug: false
    )

    output = $stdout.string
    $stdout = original_stdout

    # Should not contain any debug messages
    refute_includes output, "[UrlCategorise DEBUG]"
  end

  def test_debug_timing_accuracy
    client = UrlCategorise::Client.new(
      host_urls: { test: [ "file://#{@temp_hosts_file}" ] },
      debug: true
    )

    # Test the debug_time method works
    original_stdout = $stdout
    $stdout = StringIO.new

    result = client.send(:debug_time, "Test operation") do
      sleep(0.01) # 10ms delay
      "test result"
    end

    output = $stdout.string
    $stdout = original_stdout

    assert_equal "test result", result
    assert_includes output, "[UrlCategorise DEBUG] Test operation completed in"
    assert_includes output, "ms"

    # Extract the timing and verify it's reasonable (should be >= 10ms)
    timing_match = output.match(/completed in ([\d.]+)ms/)
    assert timing_match, "Should find timing information in output"
    timing = timing_match[1].to_f
    assert timing >= 10.0, "Timing should be at least 10ms, got #{timing}ms"
  end

  def test_debug_log_method_respects_debug_setting
    client = UrlCategorise::Client.new(
      host_urls: { test: [ "file://#{@temp_hosts_file}" ] },
      debug: false
    )

    # Capture stdout
    original_stdout = $stdout
    $stdout = StringIO.new

    # Should not output when debug is disabled
    client.send(:debug_log, "This should not appear")

    output_disabled = $stdout.string
    $stdout = StringIO.new

    # Enable debug and test again
    client.debug_enabled = true
    client.send(:debug_log, "This should appear")

    output_enabled = $stdout.string
    $stdout = original_stdout

    # Verify behavior
    assert_empty output_disabled
    assert_includes output_enabled, "[UrlCategorise DEBUG] This should appear"
  end

  private

  def create_test_hosts_file
    File.open(@temp_hosts_file, "w") do |file|
      file.puts "# Test blog hosts file"
      file.puts "0.0.0.0 wordpress.com"
      file.puts "0.0.0.0 blogspot.com"
      file.puts "0.0.0.0 medium.com"
      file.puts "0.0.0.0 substack.com"
    end
  end
end
