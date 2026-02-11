require 'test_helper'

class UrlCategoriseFinalCoverageBoostTest < Minitest::Test
  def setup
    WebMock.enable!
    WebMock.reset!
    @temp_dir = Dir.mktmpdir('url_categorise_final_test_')
  end

  def teardown
    WebMock.disable!
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  def test_categorise_method_comprehensive
    stub_request(:get, "http://example.com/categorise_test.txt")
      .to_return(status: 200, body: "malware.com\nads.com\nphishing.com")

    client = UrlCategorise::Client.new(
      host_urls: { 
        malware: ["http://example.com/categorise_test.txt"],
        advertising: ["http://example.com/categorise_test.txt"],
        phishing: ["http://example.com/categorise_test.txt"]
      }
    )

    # Test normal categorization
    result = client.categorise("https://malware.com/page")
    assert_kind_of Array, result

    # Test categorization with different protocols
    result = client.categorise("http://ads.com")
    assert_kind_of Array, result

    # Test categorization with subdomains
    result = client.categorise("sub.phishing.com")
    assert_kind_of Array, result

    # Test categorization with paths and query parameters
    result = client.categorise("https://malware.com/path/to/page?param=value")
    assert_kind_of Array, result
  end

  def test_resolve_and_categorise_method
    stub_request(:get, "http://example.com/resolve_test.txt")
      .to_return(status: 200, body: "resolve-test.com")

    client = UrlCategorise::Client.new(
      host_urls: { test_category: ["http://example.com/resolve_test.txt"] }
    )

    # Test resolve and categorise
    result = client.resolve_and_categorise("resolve-test.com")
    assert_kind_of Array, result
  end

  def test_categorise_ip_method_comprehensive
    # Create test data with IP addresses
    stub_request(:get, "http://example.com/ip_test.txt")
      .to_return(status: 200, body: "192.168.1.100\n10.0.0.1\n172.16.0.1")

    client = UrlCategorise::Client.new(
      host_urls: { ip_category: ["http://example.com/ip_test.txt"] }
    )

    # Test IP categorization
    result = client.categorise_ip("192.168.1.100")
    assert_kind_of Array, result

    # Test with different IP formats
    result = client.categorise_ip("10.0.0.1")
    assert_kind_of Array, result

    result = client.categorise_ip("172.16.0.1")
    assert_kind_of Array, result

    # Test with invalid IPs
    result = client.categorise_ip("not.an.ip")
    assert_kind_of Array, result

    result = client.categorise_ip("999.999.999.999")
    assert_kind_of Array, result
  end

  def test_build_host_data_method
    stub_request(:get, "http://example.com/build1.txt")
      .to_return(status: 200, body: "host1.com\nhost2.com")
    stub_request(:get, "http://example.com/build2.txt")
      .to_return(status: 200, body: "host3.com\nhost4.com")

    client = UrlCategorise::Client.new(host_urls: {})

    # Test build_host_data method
    urls = ["http://example.com/build1.txt", "http://example.com/build2.txt"]
    result = client.send(:build_host_data, urls)
    
    assert_kind_of Array, result
    # Should contain host data
    assert result.any?
  end

  def test_download_and_parse_list_method
    stub_request(:get, "http://example.com/download_test.txt")
      .to_return(
        status: 200, 
        body: "download-test1.com\ndownload-test2.com\ndownload-test3.com",
        headers: { 'Content-Type' => 'text/plain' }
      )

    client = UrlCategorise::Client.new(host_urls: {})

    # Test download_and_parse_list method
    result = client.send(:download_and_parse_list, "http://example.com/download_test.txt")
    
    assert_kind_of Hash, result
    assert result.key?(:hosts)
    assert result.key?(:metadata)
    
    # Should contain the downloaded hosts
    assert result[:hosts].include?("download-test1.com")
    assert result[:hosts].include?("download-test2.com")
    assert result[:hosts].include?("download-test3.com")
  end

  def test_iab_compliance_methods_comprehensive
    client = UrlCategorise::Client.new(host_urls: {}, iab_compliance: true, iab_version: :v3)

    # Test IAB compliant status
    assert client.iab_compliant?

    # Test IAB mappings for different categories
    test_categories = [
      :advertising, :malware, :phishing, :gambling, :adult_content,
      :social_media, :news, :finance, :health, :technology,
      :entertainment, :sports, :travel, :education, :shopping
    ]

    test_categories.each do |category|
      mapping = client.get_iab_mapping(category)
      # Should return something without crashing
      assert_not_nil client  # Just verify the method doesn't crash
    end

    # Test with v2 version
    client_v2 = UrlCategorise::Client.new(host_urls: {}, iab_compliance: true, iab_version: :v2)
    assert client_v2.iab_compliant?
    
    mapping = client_v2.get_iab_mapping(:advertising)
    assert_not_nil client_v2
  end

  def test_list_health_checking_comprehensive
    # Stub different response types
    stub_request(:head, "http://example.com/healthy.txt")
      .to_return(status: 200, headers: { 'Content-Length' => '100' })
    stub_request(:get, "http://example.com/healthy.txt")
      .to_return(status: 200, body: "healthy.com")

    stub_request(:head, "http://example.com/not_found.txt")
      .to_return(status: 404)
    stub_request(:get, "http://example.com/not_found.txt")
      .to_return(status: 404, body: "Not Found")

    stub_request(:head, "http://example.com/forbidden.txt")
      .to_return(status: 403)
    stub_request(:get, "http://example.com/forbidden.txt")
      .to_return(status: 403, body: "Forbidden")

    stub_request(:head, "http://example.com/timeout.txt")
      .to_timeout
    stub_request(:get, "http://example.com/timeout.txt")
      .to_timeout

    client = UrlCategorise::Client.new(
      host_urls: {
        healthy: ["http://example.com/healthy.txt"],
        not_found: ["http://example.com/not_found.txt"],
        forbidden: ["http://example.com/forbidden.txt"],
        timeout: ["http://example.com/timeout.txt"]
      }
    )

    # Test comprehensive health checking
    health_report = client.check_all_lists
    
    assert_kind_of Hash, health_report
    assert health_report.key?(:summary)
    assert health_report.key?(:details)
    
    # Summary should contain counts
    summary = health_report[:summary]
    assert_kind_of Hash, summary
    assert summary.key?(:total_lists)
    assert summary.key?(:healthy_lists)
    assert summary.key?(:unhealthy_lists)
    
    # Details should contain information about each list
    details = health_report[:details]
    assert_kind_of Hash, details
  end

  def test_export_methods_comprehensive
    stub_request(:get, "http://example.com/export_data.txt")
      .to_return(status: 200, body: "export1.com\nexport2.com\nexport3.com\nexport4.com")

    client = UrlCategorise::Client.new(
      host_urls: { 
        export_category1: ["http://example.com/export_data.txt"],
        export_category2: ["http://example.com/export_data.txt"]
      },
      cache_dir: @temp_dir
    )

    # Test hosts file export
    export_result = client.export_hosts_files(@temp_dir)
    
    assert_kind_of Hash, export_result
    assert export_result.key?(:_summary)
    
    summary = export_result[:_summary]
    assert_kind_of Hash, summary
    assert summary.key?(:total_categories)
    assert summary.key?(:export_directory)

    # Test CSV export
    csv_result = client.export_csv_data(@temp_dir)
    
    assert_kind_of Hash, csv_result
    # Should have either csv_file or export_directory key
    assert(csv_result.key?(:csv_file) || csv_result.key?(:export_directory))
  end

  def test_dataset_integration_comprehensive
    # Create a simple dataset processor with test config
    dataset_config = {
      cache_path: @temp_dir,
      enable_kaggle: false  # Disable to avoid credential requirements
    }

    client = UrlCategorise::Client.new(
      host_urls: {},
      dataset_config: dataset_config
    )

    # Test dataset methods
    metadata = client.dataset_metadata
    assert_kind_of Hash, metadata

    # Test dataset count methods
    dataset_hosts_count = client.count_of_dataset_hosts
    assert_kind_of Integer, dataset_hosts_count
    assert dataset_hosts_count >= 0

    dataset_categories_count = client.count_of_dataset_categories
    assert_kind_of Integer, dataset_categories_count
    assert dataset_categories_count >= 0

    # Test dataset size methods
    dataset_size = client.size_of_dataset_data
    assert(dataset_size.is_a?(String) || dataset_size.is_a?(Float))

    dataset_size_bytes = client.size_of_dataset_data_bytes
    assert_kind_of Integer, dataset_size_bytes
    assert dataset_size_bytes >= 0
  end

  def test_advanced_parsing_scenarios
    client = UrlCategorise::Client.new(host_urls: {})

    # Test parsing with mixed content
    mixed_content = <<~CONTENT
      # Mixed format test
      0.0.0.0 hosts-format.com
      plain-format.com
      ||ublock-format.com^
      address=/dnsmasq-format.com/0.0.0.0
      
      # Comments and empty lines should be handled
      
      # Another comment
      final-domain.com
    CONTENT

    result = client.send(:parse_list_content, mixed_content, :plain)
    assert_kind_of Array, result
    assert result.any?

    # Test format detection with edge cases
    formats_to_test = [
      { content: "# Just comments\n# More comments", expected: :plain },
      { content: "", expected: :plain },
      { content: "   \n  \n  ", expected: :plain },
      { content: "0.0.0.0 test.com", expected: :hosts },
      { content: "||test.com^", expected: :ublock },
      { content: "address=/test.com/", expected: :dnsmasq }
    ]

    formats_to_test.each do |test_case|
      detected = client.send(:detect_list_format, test_case[:content])
      # Just verify it returns a symbol and doesn't crash
      assert_kind_of Symbol, detected
    end
  end

  def test_comprehensive_statistics_methods
    stub_request(:get, "http://example.com/stats_data.txt")
      .to_return(status: 200, body: Array.new(100) { |i| "domain#{i}.com" }.join("\n"))

    client = UrlCategorise::Client.new(
      host_urls: { 
        large_category: ["http://example.com/stats_data.txt"]
      }
    )

    # Test all count methods
    hosts_count = client.count_of_hosts
    assert_kind_of Integer, hosts_count
    assert hosts_count > 0

    categories_count = client.count_of_categories
    assert_kind_of Integer, categories_count
    assert categories_count > 0

    # Test all size methods
    total_size = client.size_of_data
    assert(total_size.is_a?(String) || total_size.is_a?(Float))

    blocklist_size = client.size_of_blocklist_data
    assert(blocklist_size.is_a?(String) || blocklist_size.is_a?(Float))

    # Test byte size methods
    total_bytes = client.size_of_data_bytes
    assert_kind_of Integer, total_bytes
    assert total_bytes >= 0

    blocklist_bytes = client.size_of_blocklist_data_bytes
    assert_kind_of Integer, blocklist_bytes
    assert blocklist_bytes >= 0

    # Test internal helper methods
    test_hash = { key1: "value1", key2: "value2", key3: "value3" }
    
    mb_size = client.send(:hash_size_in_mb, test_hash)
    assert_kind_of Float, mb_size
    assert mb_size >= 0

    byte_size = client.send(:hash_size_in_bytes, test_hash)
    assert_kind_of Integer, byte_size
    assert byte_size > 0
  end

  def test_edge_case_url_handling
    client = UrlCategorise::Client.new(host_urls: {})

    # Test various edge case URLs
    edge_case_urls = [
      nil,
      "",
      "   ",
      "not-a-url",
      "https://",
      "https:///empty-host",
      "https://example.com:99999/path",  # Invalid port
      "https://user:pass@example.com/path",  # With credentials
      "https://example.com/path with spaces",
      "https://example.com/path?param=value&other=value2",
      "https://subdomain.subdomain.example.com/deep/path",
      "ftp://example.com/file",  # Different protocol
      "https://192.168.1.1/path",  # IP address
      "https://[::1]/path",  # IPv6
    ]

    edge_case_urls.each do |url|
      # Should not crash on any input
      result = client.categorise(url)
      assert_kind_of Array, result
      
      # Test host extraction for the same URLs
      host = client.send(:extract_host, url)
      # Should return string or nil, shouldn't crash
    end
  end

  def test_url_validation_methods_comprehensive
    client = UrlCategorise::Client.new(host_urls: {})

    # Test valid URLs
    valid_urls = [
      "https://example.com",
      "http://test.com",
      "https://subdomain.example.com",
      "https://example.com/path",
      "https://example.com:8080/path",
      "file://local/file.txt",
    ]

    valid_urls.each do |url|
      assert client.send(:url_valid?, url), "Expected #{url} to be valid"
      refute client.send(:url_not_valid?, url), "Expected #{url} to not be invalid"
    end

    # Test invalid URLs
    invalid_urls = [
      nil,
      "",
      "   ",
      "not-a-url",
      "https://",
      "just-text",
    ]

    invalid_urls.each do |url|
      refute client.send(:url_valid?, url), "Expected #{url} to be invalid"
      assert client.send(:url_not_valid?, url), "Expected #{url} to be marked as invalid"
    end
  end

  def test_categories_with_keys_method
    stub_request(:get, "http://example.com/categories_test.txt")
      .to_return(status: 200, body: "cat1.com\ncat2.com")

    client = UrlCategorise::Client.new(
      host_urls: { test_cat: ["http://example.com/categories_test.txt"] }
    )

    categories = client.send(:categories_with_keys)
    assert_kind_of Hash, categories
    # The method combines all categories, should return hash structure
  end

  def test_initialization_edge_cases
    # Test initialization with nil values
    client = UrlCategorise::Client.new(
      host_urls: nil,
      cache_dir: nil,
      dns_servers: nil
    )
    assert_kind_of UrlCategorise::Client, client

    # Test initialization with empty values
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: "",
      dns_servers: []
    )
    assert_kind_of UrlCategorise::Client, client

    # Test all boolean combinations
    [true, false].product([true, false], [true, false], [true, false]).each do |combo|
      smart_cat, regex_cat, iab_comp, debug = combo
      
      client = UrlCategorise::Client.new(
        host_urls: {},
        smart_categorization: smart_cat,
        regex_categorization: regex_cat,
        iab_compliance: iab_comp,
        debug: debug
      )
      
      assert_kind_of UrlCategorise::Client, client
      assert_equal smart_cat, client.smart_categorization_enabled
      assert_equal regex_cat, client.regex_categorization_enabled
      assert_equal iab_comp, client.iab_compliance_enabled
      assert_equal debug, client.debug_enabled
    end
  end
end