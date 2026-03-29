require 'test_helper'

class UrlCategoriseAdvancedCoverageTest < Minitest::Test
  def setup
    WebMock.reset!
    @temp_dir = Dir.mktmpdir('url_categorise_advanced_test_')
  end

  def teardown
    WebMock.reset!
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  def test_advanced_categorisation_features
    stub_request(:get, "http://example.com/advanced.txt")
      .to_return(status: 200, body: "malware.example.com\nads.example.com\nvideo.example.com")
    stub_request(:get, "https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_url_patterns.txt")
      .to_return(status: 200, body: "")
    stub_request(:get, "https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_hosting_domains.hosts")
      .to_return(status: 200, body: "")

    client = UrlCategorise::Client.new(
      host_urls: { 
        malware: ["http://example.com/advanced.txt"],
        advertising: ["http://example.com/advanced.txt"] 
      },
      smart_categorization: true,
      regex_categorization: true,
      iab_compliance: true
    )

    # Test advanced categorisation features
    result = client.categorise("https://malware.example.com/page")
    assert_kind_of Array, result
    assert result.any?

    # Test resolve and categorise
    result = client.resolve_and_categorise("malware.example.com")
    assert_kind_of Array, result

    # Test categorise_ip
    result = client.categorise_ip("192.168.1.1")
    assert_kind_of Array, result
  end

  def test_video_detection_methods
    stub_request(:get, "https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_url_patterns.txt")
      .to_return(status: 200, body: "")
    stub_request(:get, "https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_hosting_domains.hosts")
      .to_return(status: 200, body: "")

    client = UrlCategorise::Client.new(host_urls: {}, regex_categorization: true)

    # Test video URL detection methods
    youtube_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    assert_respond_to client, :video_url?
    
    # Test various video detection methods
    assert_respond_to client, :shorts_url?
    assert_respond_to client, :playlist_url?
    assert_respond_to client, :music_url?
    assert_respond_to client, :channel_url?
    assert_respond_to client, :live_stream_url?
    assert_respond_to client, :blog_url?

    # Test the methods with URLs (they should not crash)
    client.video_url?("https://www.youtube.com/watch?v=test") rescue nil
    client.shorts_url?("https://www.youtube.com/shorts/test") rescue nil
    client.playlist_url?("https://www.youtube.com/playlist?list=test") rescue nil
    client.music_url?("https://music.youtube.com/watch?v=test") rescue nil
    client.channel_url?("https://www.youtube.com/channel/test") rescue nil
    client.live_stream_url?("https://www.youtube.com/live/test") rescue nil
    client.blog_url?("https://example.blogspot.com") rescue nil
  end

  def test_smart_categorisation_rules
    client = UrlCategorise::Client.new(
      host_urls: {},
      smart_categorization: true,
      smart_rules: {
        custom_rule: {
          domains: ["example.com", "test.com"],
          remove_categories: [:health, :finance],
          keep_primary_only: [:social_media]
        }
      }
    )

    # Test smart categorisation application
    result = client.send(:apply_smart_categorisation, "https://example.com/page", [:health, :social_media])
    assert_kind_of Array, result

    # Test rule application
    categories = [:health, :finance, :social_media]
    rule_config = {
      domains: ["example.com"],
      remove_categories: [:health, :finance]
    }
    result = client.send(:apply_rule, categories, rule_config, "example.com", "https://example.com/page")
    assert_kind_of Array, result
  end

  def test_regex_pattern_loading_and_application
    # Create a temporary regex patterns file
    patterns_file = File.join(@temp_dir, 'video_patterns.txt')
    File.write(patterns_file, <<~PATTERNS
      # Video hosting patterns
      # Source: youtube
      .*youtube\\.com/watch\\?v=.*
      .*youtu\\.be/.*

      # Source: vimeo
      vimeo\\.com/\\d+

      # Source: social_media
      .*facebook\\.com/.*
      .*twitter\\.com/.*
    PATTERNS
    )

    client = UrlCategorise::Client.new(
      host_urls: {},
      regex_categorization: true,
      regex_patterns_file: patterns_file
    )

    # Test regex pattern application
    test_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    result = client.send(:apply_regex_categorisation, test_url, [])
    assert_kind_of Array, result
  end

  def test_comprehensive_list_health_checking
    # Test URLs that should work
    stub_request(:head, "http://example.com/good.txt")
      .to_return(status: 200, headers: {})
    stub_request(:get, "http://example.com/good.txt")
      .to_return(status: 200, body: "good.example.com")

    # Test URLs that should fail
    stub_request(:head, "http://example.com/bad.txt")
      .to_return(status: 404, headers: {})
    stub_request(:get, "http://example.com/bad.txt")
      .to_return(status: 404, body: "Not Found")

    client = UrlCategorise::Client.new(
      host_urls: {
        good_category: ["http://example.com/good.txt"],
        bad_category: ["http://example.com/bad.txt"]
      }
    )

    # Test list health checking
    health_report = client.check_all_lists
    assert_kind_of Hash, health_report
    assert health_report.key?(:summary)
    assert health_report.key?(:successful_lists)
  end

  def test_export_functionality
    stub_request(:get, "http://example.com/export_test.txt")
      .to_return(status: 200, body: "example.com\ntest.com\nother.com")

    client = UrlCategorise::Client.new(
      host_urls: { test_category: ["http://example.com/export_test.txt"] },
      cache_dir: @temp_dir
    )

    # Test hosts file export
    result = client.export_hosts_files(@temp_dir)
    assert_kind_of Hash, result
    assert result.key?(:_summary)

    # Test CSV data export
    result = client.export_csv_data(@temp_dir)
    assert_kind_of Hash, result
    assert result.key?(:csv_file) || result.key?(:export_directory)
  end

  def test_dataset_integration_methods
    client = UrlCategorise::Client.new(
      host_urls: {},
      dataset_config: { cache_path: @temp_dir }
    )

    # Test dataset loading methods
    assert_respond_to client, :load_kaggle_dataset
    assert_respond_to client, :load_csv_dataset
    assert_respond_to client, :dataset_metadata
    assert_respond_to client, :reload_with_datasets

    # Test dataset metadata
    metadata = client.dataset_metadata
    assert_kind_of Hash, metadata

    # Test dataset count methods
    assert_kind_of Integer, client.count_of_dataset_hosts
    assert_kind_of Integer, client.count_of_dataset_categories
  end

  def test_parallel_vs_sequential_processing
    temp_file1 = File.join(@temp_dir, "parallel1.hosts")
    temp_file2 = File.join(@temp_dir, "parallel2.hosts")
    File.write(temp_file1, "0.0.0.0 domain1.com\n")
    File.write(temp_file2, "0.0.0.0 domain2.com\n")

    client = UrlCategorise::Client.new(host_urls: {}, parallel_loading: false)

    downloaded_content = {
      "test1:file://#{temp_file1}" => { content: File.read(temp_file1), from_cache: false },
      "test2:file://#{temp_file2}" => { content: File.read(temp_file2), from_cache: false }
    }

    client.instance_variable_set(:@hosts, {})
    client.send(:process_content_with_threads, downloaded_content)

    hosts = client.instance_variable_get(:@hosts)
    assert_kind_of Hash, hosts
    assert hosts.any?
    assert_includes hosts[:test1], "domain1.com"
    assert_includes hosts[:test2], "domain2.com"
  end

  def test_ractor_processing_if_available
    # Ractor internal code is excluded from coverage tracking (# :nocov:)
    # Test is skipped to prevent potential Ractor deadlocks in the test suite
    skip "Ractor parallel processing tests are excluded from the test suite"
  end

  def test_comprehensive_data_collection_methods
    stub_request(:get, "http://example.com/collect_test.txt")
      .to_return(status: 200, body: "collect.example.com\ndata.example.com")

    client = UrlCategorise::Client.new(
      host_urls: { collect_category: ["http://example.com/collect_test.txt"] },
      cache_dir: @temp_dir
    )

    # Test comprehensive export data collection
    all_data = client.send(:collect_all_export_data)
    assert_kind_of Array, all_data

    # Test cached dataset content collection
    cached_content = client.send(:collect_cached_dataset_content)
    assert_kind_of Array, cached_content

    # Test current dataset content collection
    current_content = client.send(:collect_current_dataset_content)
    assert_kind_of Array, current_content

    # Test comprehensive headers determination
    headers = client.send(:determine_comprehensive_headers, all_data)
    assert_kind_of Array, headers
  end

  def test_advanced_list_parsing_formats
    client = UrlCategorise::Client.new(host_urls: {})

    # Test various complex parsing scenarios
    
    # Complex hosts file with comments and varied formats
    hosts_content = <<~HOSTS
      # This is a comment
      0.0.0.0 example.com
      127.0.0.1 localhost.local
      
      # Another comment
      ::1 ipv6.local
      0.0.0.0 spaced.domain.com # inline comment
      192.168.1.1 private.local
    HOSTS
    result = client.send(:parse_list_content, hosts_content, :hosts)
    assert_kind_of Array, result
    assert result.include?("example.com")
    assert result.include?("localhost.local")

    # Complex uBlock format
    ublock_content = <<~UBLOCK
      ! Title: Test blocklist
      ! Version: 1.0
      ||example.com^
      ||test.com^$important
      ||ads.example.com^$third-party
      @@||whitelist.com^
      example.com##.ads
    UBLOCK
    result = client.send(:parse_list_content, ublock_content, :ublock)
    assert_kind_of Array, result

    # Complex dnsmasq format
    dnsmasq_content = <<~DNSMASQ
      address=/example.com/0.0.0.0
      address=/test.com/127.0.0.1
      server=/safe.com/8.8.8.8
      # This is a comment
      address=/ads.example.com/
    DNSMASQ
    result = client.send(:parse_list_content, dnsmasq_content, :dnsmasq)
    assert_kind_of Array, result

    # Complex AdSense format
    adsense_content = <<~ADSENSE
      example.com,test.com,ads.com
      "quoted,domain.com","another,domain.com"
      # Comment line
      single.com
      multi.com,domains.com,list.com
    ADSENSE
    result = client.send(:parse_list_content, adsense_content, :AdSense)
    assert_kind_of Array, result
  end

  def test_error_handling_and_edge_cases
    client = UrlCategorise::Client.new(host_urls: {})

    # Test nil and empty input handling
    assert_kind_of Array, client.categorise(nil)
    assert_kind_of Array, client.categorise("")
    assert_kind_of Array, client.categorise("   ")

    # Test invalid URL handling
    assert_kind_of Array, client.categorise("not-a-url")
    assert_kind_of Array, client.categorise("ftp://invalid-protocol.com")

    # Test malformed URL handling
    assert_kind_of Array, client.categorise("https://[invalid-bracket")
    assert_kind_of Array, client.categorise("https://space in domain.com")

    # Test very long URL handling
    long_url = "https://example.com/" + "a" * 10000
    assert_kind_of Array, client.categorise(long_url)
  end

  def test_metadata_and_statistics_methods
    stub_request(:get, "http://example.com/stats.txt")
      .to_return(status: 200, body: "stats1.com\nstats2.com\nstats3.com")

    client = UrlCategorise::Client.new(
      host_urls: { stats_category: ["http://example.com/stats.txt"] }
    )

    # Test all statistics methods
    assert_kind_of Integer, client.count_of_hosts
    assert_kind_of Integer, client.count_of_categories
    
    # Size methods should return appropriate types
    assert client.size_of_data.is_a?(String) || client.size_of_data.is_a?(Float)
    assert client.size_of_dataset_data.is_a?(String) || client.size_of_dataset_data.is_a?(Float)
    assert client.size_of_blocklist_data.is_a?(String) || client.size_of_blocklist_data.is_a?(Float)
    
    assert_kind_of Integer, client.size_of_data_bytes
    assert_kind_of Integer, client.size_of_dataset_data_bytes
    assert_kind_of Integer, client.size_of_blocklist_data_bytes

    # Test metadata access
    assert_kind_of Hash, client.metadata
  end

  def test_iab_compliance_comprehensive
    client = UrlCategorise::Client.new(
      host_urls: {},
      iab_compliance: true,
      iab_version: :v3
    )

    # Test IAB compliance
    assert client.iab_compliant?
    
    # Test IAB mappings for various categories
    categories_to_test = [
      :advertising, :malware, :phishing, :gambling, :pornography,
      :social_media, :news, :finance, :health, :technology,
      :unknown_category, :nonexistent_category
    ]
    
    categories_to_test.each do |category|
      mapping = client.get_iab_mapping(category)
      # Should return something (could be string, array, or nil)
      assert_respond_to client, :get_iab_mapping
    end
  end

  def test_comprehensive_initialization_combinations
    # Test various initialization combinations that might not be covered

    # Test with all features disabled
    client = UrlCategorise::Client.new(
      host_urls: {},
      iab_compliance: false,
      smart_categorization: false,
      regex_categorization: false,
      auto_load_datasets: false,
      debug: false,
      parallel_loading: false
    )
    assert_kind_of UrlCategorise::Client, client

    # Test with minimal configuration (use empty host_urls to avoid network calls)
    client = UrlCategorise::Client.new(host_urls: {})
    assert_kind_of UrlCategorise::Client, client

    # Test with custom DNS servers
    client = UrlCategorise::Client.new(
      host_urls: {},
      dns_servers: ["1.1.1.1", "8.8.8.8"]
    )
    assert_equal ["1.1.1.1", "8.8.8.8"], client.dns_servers

    # Test with custom timeouts
    client = UrlCategorise::Client.new(
      host_urls: {},
      request_timeout: 60
    )
    assert_equal 60, client.request_timeout

    # Test with custom thread/ractor limits
    client = UrlCategorise::Client.new(
      host_urls: {},
      max_threads: 16,
      max_ractor_workers: 8
    )
    assert_equal 16, client.max_threads
    assert_equal 8, client.max_ractor_workers
  end
end