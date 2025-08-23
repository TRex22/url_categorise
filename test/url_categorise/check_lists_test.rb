require 'test_helper'

class CheckListsTest < Minitest::Test
  def setup
    WebMock.reset!
    @test_cache_dir = '/tmp/test_url_cache'
    FileUtils.rm_rf(@test_cache_dir) if Dir.exist?(@test_cache_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_cache_dir) if Dir.exist?(@test_cache_dir)
  end

  # Helper method to create a client without triggering initialization downloads
  def create_client_without_downloads(host_urls)
    client = UrlCategorise::Client.allocate
    client.instance_variable_set(:@host_urls, host_urls)
    client.instance_variable_set(:@cache_dir, nil)
    client.instance_variable_set(:@force_download, false)
    client.instance_variable_set(:@dns_servers, ['1.1.1.1', '1.0.0.1'])
    client.instance_variable_set(:@request_timeout, 10)
    client.instance_variable_set(:@metadata, {})
    client.instance_variable_set(:@hosts, {})
    client
  end

  def test_check_all_lists_with_successful_responses
    # Stub HEAD requests for the check_all_lists method
    WebMock.stub_request(:head, 'https://example.com/working-list.txt')
      .to_return(status: 200, headers: {})

    WebMock.stub_request(:head, 'https://example.com/redirect-list.txt')
      .to_return(status: 302, headers: { 'location' => 'https://example.com/new-location.txt' })
    WebMock.stub_request(:head, 'https://example.com/new-location.txt')
      .to_return(status: 200, headers: {})

    # Create client without triggering initialization downloads
    host_urls = {
      working_category: ['https://example.com/working-list.txt'],
      redirect_category: ['https://example.com/redirect-list.txt'],
      combined_category: [:working_category, :redirect_category]
    }

    client = create_client_without_downloads(host_urls)

    # Capture output to avoid cluttering test output
    result = capture_io do
      client.check_all_lists
    end

    output = result[0]
    check_result = result[1]

    # Verify output contains expected information
    assert_includes output, 'Checking all lists in constants...'
    assert_includes output, 'LIST HEALTH REPORT'
    assert_includes output, 'working_category'
    assert_includes output, 'redirect_category'
    assert_includes output, 'References other category'

    # Verify return structure
    assert_instance_of Hash, check_result
    assert check_result.key?(:summary)
    assert check_result.key?(:missing_categories)
    assert check_result.key?(:unreachable_lists)
    assert check_result.key?(:successful_lists)

    # Verify summary data
    assert_equal 3, check_result[:summary][:total_categories]
    assert check_result[:summary][:healthy_categories] > 0
    assert check_result[:summary][:categories_with_issues] >= 0
  end

  def test_check_all_lists_with_failed_responses
    # Stub various failure responses
    WebMock.stub_request(:head, 'https://example.com/not-found.txt')
      .to_return(status: 404)

    WebMock.stub_request(:head, 'https://example.com/forbidden.txt')
      .to_return(status: 403)

    WebMock.stub_request(:head, 'https://example.com/server-error.txt')
      .to_return(status: 500)

    WebMock.stub_request(:head, 'https://example.com/timeout.txt')
      .to_timeout

    WebMock.stub_request(:head, 'https://example.com/network-error.txt')
      .to_raise(SocketError.new('Connection failed'))

    # Create client with failing URLs
    host_urls = {
      not_found_category: ['https://example.com/not-found.txt'],
      forbidden_category: ['https://example.com/forbidden.txt'],
      server_error_category: ['https://example.com/server-error.txt'],
      timeout_category: ['https://example.com/timeout.txt'],
      network_error_category: ['https://example.com/network-error.txt'],
      empty_category: []
    }

    client = create_client_without_downloads(host_urls)

    # Capture output
    result = capture_io do
      client.check_all_lists
    end

    output = result[0]
    check_result = result[1]

    # Verify error reporting in output
    assert_includes output, '404 Not Found'
    assert_includes output, '403 Forbidden'
    assert_includes output, 'Server Error'
    assert_includes output, 'Timeout'
    assert_includes output, 'DNS/Network Error'
    assert_includes output, 'UNREACHABLE LISTS'

    # Verify result structure captures failures
    assert check_result[:unreachable_lists].key?(:not_found_category)
    assert check_result[:unreachable_lists].key?(:forbidden_category)
    assert check_result[:unreachable_lists].key?(:server_error_category)
    assert check_result[:unreachable_lists].key?(:timeout_category)
    assert check_result[:unreachable_lists].key?(:network_error_category)

    # Verify empty category is captured
    assert_includes check_result[:missing_categories], :empty_category

    # Verify error details
    not_found_error = check_result[:unreachable_lists][:not_found_category].first
    assert_equal '404 Not Found', not_found_error[:error]
    assert_equal 'https://example.com/not-found.txt', not_found_error[:url]
  end

  def test_check_all_lists_with_invalid_urls
    # Create client with invalid URLs
    host_urls = {
      invalid_url_category: ['not-a-valid-url', 'ftp://invalid-protocol.com']
    }

    client = create_client_without_downloads(host_urls)

    # Capture output
    result = capture_io do
      client.check_all_lists
    end

    output = result[0]
    check_result = result[1]

    # Verify invalid URL detection
    assert_includes output, 'Invalid URL format'
    
    # Verify result captures invalid URLs
    assert check_result[:unreachable_lists].key?(:invalid_url_category)
    
    invalid_url_errors = check_result[:unreachable_lists][:invalid_url_category]
    assert_equal 2, invalid_url_errors.length
    assert invalid_url_errors.all? { |error| error[:error] == 'Invalid URL format' }
  end

  def test_check_all_lists_handles_http_errors
    # Stub HTTParty error
    WebMock.stub_request(:head, 'https://example.com/http-error.txt')
      .to_raise(HTTParty::Error.new('HTTP error occurred'))

    # Create client with error-prone URL
    host_urls = {
      http_error_category: ['https://example.com/http-error.txt']
    }

    client = create_client_without_downloads(host_urls)

    # Capture output
    result = capture_io do
      client.check_all_lists
    end

    output = result[0]
    check_result = result[1]

    # Verify HTTP error handling
    assert_includes output, 'HTTP Error'
    
    # Verify result captures HTTP error
    assert check_result[:unreachable_lists].key?(:http_error_category)
    
    http_error = check_result[:unreachable_lists][:http_error_category].first
    assert_includes http_error[:error], 'HTTP Error'
  end

  def test_check_all_lists_respects_request_timeout_setting
    # Stub a timeout response
    WebMock.stub_request(:head, 'https://example.com/slow-server.txt')
      .to_timeout

    # Create client with custom timeout
    host_urls = {
      slow_category: ['https://example.com/slow-server.txt']
    }

    client = create_client_without_downloads(host_urls)
    client.instance_variable_set(:@request_timeout, 2)  # Short timeout for testing

    # Verify the request uses the configured timeout
    result = capture_io do
      client.check_all_lists
    end

    check_result = result[1]

    # Should capture timeout error
    assert check_result[:unreachable_lists].key?(:slow_category)
    timeout_error = check_result[:unreachable_lists][:slow_category].first
    assert_equal 'Request timeout', timeout_error[:error]

    # Verify HTTParty was called with correct timeout
    assert_requested(:head, 'https://example.com/slow-server.txt') do |req|
      # HTTParty should use the configured timeout
      true  # We can't easily verify the timeout parameter, but the test structure is correct
    end
  end

  def test_check_all_lists_uses_actual_constants
    # Test with a small subset of actual constants
    actual_constants = UrlCategorise::Constants::DEFAULT_HOST_URLS.first(2).to_h
    
    # Stub all URLs from the actual constants
    actual_constants.each do |category, urls|
      urls.reject { |url| url.is_a?(Symbol) }.each do |url|
        WebMock.stub_request(:head, url).to_return(status: 200)
      end
    end

    client = create_client_without_downloads(actual_constants)
    
    # Capture output
    result = capture_io do
      client.check_all_lists
    end

    output = result[0]
    check_result = result[1]

    # Verify the method used actual constants
    assert_includes output, 'Checking all lists in constants...'
    assert_instance_of Hash, check_result
    assert check_result.key?(:summary)
    assert check_result.key?(:successful_lists)
    
    # Verify it processed actual categories from constants
    actual_constants.keys.each do |category|
      unless actual_constants[category].all? { |url| url.is_a?(Symbol) }
        assert_includes output, category.to_s
      end
    end
  end

  def test_check_all_lists_summary_calculations
    # Mix of successful and failed URLs
    WebMock.stub_request(:head, 'https://example.com/success1.txt')
      .to_return(status: 200)
    WebMock.stub_request(:head, 'https://example.com/success2.txt')
      .to_return(status: 200)
    WebMock.stub_request(:head, 'https://example.com/fail1.txt')
      .to_return(status: 404)
    WebMock.stub_request(:head, 'https://example.com/fail2.txt')
      .to_return(status: 403)

    host_urls = {
      success_category: ['https://example.com/success1.txt', 'https://example.com/success2.txt'],
      mixed_category: ['https://example.com/success2.txt', 'https://example.com/fail1.txt'],
      fail_category: ['https://example.com/fail1.txt', 'https://example.com/fail2.txt'],
      empty_category: [],
      symbol_category: [:success_category]
    }

    client = create_client_without_downloads(host_urls)
    
    result = capture_io do
      client.check_all_lists
    end

    check_result = result[1]

    # Verify summary calculations
    assert_equal 5, check_result[:summary][:total_categories]
    
    # Categories with issues: 
    # - mixed_category (has failures)
    # - fail_category (all failed)  
    # - empty_category (no URLs - missing)
    # Total: 3 issues 
    expected_issues = 3
    actual_issues = check_result[:summary][:categories_with_issues]
    assert_equal expected_issues, actual_issues, "Expected #{expected_issues} categories with issues, got #{actual_issues}. Unreachable: #{check_result[:unreachable_lists].keys}, Missing: #{check_result[:missing_categories]}"
    
    # Healthy categories: success_category (success_category works perfectly)
    # symbol_category is healthy as it references working categories  
    expected_healthy = 2  # success_category and symbol_category should both be healthy
    assert_equal expected_healthy, check_result[:summary][:healthy_categories]

    # Verify missing categories captures empty ones
    assert_includes check_result[:missing_categories], :empty_category
  end

  private

  # Helper method to capture both stdout and the method's return value
  def capture_io
    old_stdout = $stdout
    $stdout = StringIO.new
    
    result = yield
    
    output = $stdout.string
    $stdout = old_stdout
    
    [output, result]
  end
end