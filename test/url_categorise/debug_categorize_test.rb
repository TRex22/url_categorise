require 'test_helper'

class UrlCategoriseDebugCategorizeTest < Minitest::Test
  def setup
    @temp_hosts_file = 'test_debug_hosts.hosts'
    File.write(@temp_hosts_file, "0.0.0.0 example.com\n0.0.0.0 malware.example\n")
  end

  def teardown
    File.delete(@temp_hosts_file) if File.exist?(@temp_hosts_file)
  end

  def test_debug_categorize_method
    # Capture stdout to test debug output
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: { malware: ["file://#{@temp_hosts_file}"] },
      debug: true
    )

    # Test categorization with debug
    client.categorise("https://example.com/path")

    output = $stdout.string
    $stdout = original_stdout

    # Should contain categorization debug messages
    assert_includes output, "[UrlCategorise DEBUG] 🔍 Starting categorization for URL: https://example.com/path"
    assert_includes output, "[UrlCategorise DEBUG] 📌 Extracted host: example.com"
    assert_includes output, "[UrlCategorise DEBUG] 📋 Basic categorization matches: [:malware]"
    assert_includes output, "[UrlCategorise DEBUG] ✅ Final categories: [:malware]"
    assert_includes output, "Categorizing 'https://example.com/path' completed in"
  end

  def test_debug_categorize_with_smart_categorization
    # Capture stdout to test debug output
    original_stdout = $stdout  
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: { malware: ["file://#{@temp_hosts_file}"] },
      debug: true,
      smart_categorization: true
    )

    # Use a URL that should match our test host
    client.categorise("https://example.com/path")

    output = $stdout.string
    $stdout = original_stdout

    # Should contain smart categorization debug messages
    assert_includes output, "[UrlCategorise DEBUG] 🧠 Applying smart categorization"
    assert_includes output, "[UrlCategorise DEBUG] 📋 After smart categorization:"
  end

  def test_debug_categorize_with_regex_categorization
    # Create a test regex patterns file
    regex_file = 'test_regex_patterns.txt'
    File.write(regex_file, "video_hosting:\n.*\\.youtube\\.com/watch\\?v=.*\nvimeo\\.com/\\d+")

    # Capture stdout to test debug output
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      debug: true,
      regex_categorization: true,
      regex_patterns_file: regex_file
    )

    client.categorise("https://youtube.com/watch?v=abc123")

    output = $stdout.string
    $stdout = original_stdout

    # Should contain regex categorization debug messages
    assert_includes output, "[UrlCategorise DEBUG] 🔗 Applying regex categorization"
    assert_includes output, "[UrlCategorise DEBUG] 📋 After regex categorization:"

    File.delete(regex_file) if File.exist?(regex_file)
  end

  def test_debug_categorize_with_iab_compliance
    # Capture stdout to test debug output
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: { malware: ["file://#{@temp_hosts_file}"] },
      debug: true,
      iab_compliance: true
    )

    client.categorise("https://example.com/path")

    output = $stdout.string
    $stdout = original_stdout

    # Should contain IAB compliance debug messages
    assert_includes output, "[UrlCategorise DEBUG] 🏢 Applying IAB compliance mapping"
    assert_includes output, "[UrlCategorise DEBUG] 📋 Final IAB categories:"
  end

  def test_debug_categorize_with_no_matches
    # Capture stdout to test debug output
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(
      host_urls: { malware: ["file://#{@temp_hosts_file}"] },
      debug: true
    )

    client.categorise("https://nomatch.com/path")

    output = $stdout.string
    $stdout = original_stdout

    # Should contain debug messages showing no matches
    assert_includes output, "[UrlCategorise DEBUG] 🔍 Starting categorization for URL: https://nomatch.com/path"
    assert_includes output, "[UrlCategorise DEBUG] 📌 Extracted host: nomatch.com"
    assert_includes output, "[UrlCategorise DEBUG] 📋 Basic categorization matches: []"
    assert_includes output, "[UrlCategorise DEBUG] ✅ Final categories: []"
  end
end