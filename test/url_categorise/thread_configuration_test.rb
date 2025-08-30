require 'test_helper'

class UrlCategoriseThreadConfigurationTest < Minitest::Test
  def test_max_threads_default_value
    client = UrlCategorise::Client.new(host_urls: {})
    assert_equal 8, client.max_threads
  end

  def test_max_ractor_workers_default_value
    client = UrlCategorise::Client.new(host_urls: {})
    expected_value = [4, Etc.nprocessors].max
    assert_equal expected_value, client.max_ractor_workers
  end

  def test_max_threads_custom_value
    client = UrlCategorise::Client.new(host_urls: {}, max_threads: 16)
    assert_equal 16, client.max_threads
  end

  def test_max_ractor_workers_custom_value
    client = UrlCategorise::Client.new(host_urls: {}, max_ractor_workers: 12)
    assert_equal 12, client.max_ractor_workers
  end

  def test_active_attr_attribute_modification
    client = UrlCategorise::Client.new(host_urls: {})
    
    # Test modifying max_threads
    client.max_threads = 32
    assert_equal 32, client.max_threads
    
    # Test modifying max_ractor_workers
    client.max_ractor_workers = 16
    assert_equal 16, client.max_ractor_workers
  end

  def test_parallel_loading_enabled_default
    client = UrlCategorise::Client.new(host_urls: {})
    # Should be true if Ractors available, false otherwise
    expected = UrlCategorise::Client.ractor_available?
    assert_equal expected, client.parallel_loading_enabled
  end

  def test_parallel_loading_enabled_custom
    client = UrlCategorise::Client.new(host_urls: {}, parallel_loading: false)
    assert_equal false, client.parallel_loading_enabled
    
    client = UrlCategorise::Client.new(host_urls: {}, parallel_loading: true)
    assert_equal true, client.parallel_loading_enabled
  end

  def test_debug_enabled_attribute
    client = UrlCategorise::Client.new(host_urls: {}, debug: true)
    assert_equal true, client.debug_enabled
    
    client.debug_enabled = false
    assert_equal false, client.debug_enabled
  end

  def test_ractor_available_method
    # This method should return true/false without error
    result = UrlCategorise::Client.ractor_available?
    assert_includes [true, false], result
  end

  def test_test_environment_detection_method
    client = UrlCategorise::Client.new(host_urls: {})
    
    # Should detect test environment
    result = client.send(:test_environment?)
    assert_equal true, result, "Should detect test environment during tests"
  end

  def test_debug_time_helper_without_debug
    client = UrlCategorise::Client.new(host_urls: {}, debug: false)
    
    result = client.send(:debug_time, "Test operation") do
      "test_result"
    end
    
    assert_equal "test_result", result
  end

  def test_debug_time_helper_with_debug
    original_stdout = $stdout
    $stdout = StringIO.new

    client = UrlCategorise::Client.new(host_urls: {}, debug: true)
    
    result = client.send(:debug_time, "Test operation") do
      "test_result"
    end
    
    output = $stdout.string
    $stdout = original_stdout
    
    assert_equal "test_result", result
    assert_includes output, "Test operation completed in"
    assert_includes output, "ms"
  end
end