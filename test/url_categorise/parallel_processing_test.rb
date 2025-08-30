require 'test_helper'

class UrlCategoriseParallelProcessingTest < Minitest::Test
  def setup
    @temp_hosts_file = 'test_parallel_hosts.hosts'
    File.write(@temp_hosts_file, "0.0.0.0 example.com\n0.0.0.0 malware.example\n0.0.0.0 test.com\n")
  end

  def teardown
    File.delete(@temp_hosts_file) if File.exist?(@temp_hosts_file)
  end

  def test_process_content_with_threads_method
    client = UrlCategorise::Client.new(
      host_urls: { test: ["file://#{@temp_hosts_file}"] },
      max_threads: 2,
      parallel_loading: false  # Force sequential to avoid test environment detection
    )

    # Create downloaded content structure that would be passed to process_content_with_threads
    downloaded_content = {
      "test:file://#{@temp_hosts_file}" => {
        content: File.read(@temp_hosts_file),
        from_cache: false
      }
    }

    # Clear existing hosts to test the method directly
    client.instance_variable_set(:@hosts, {})

    # Call the private method
    client.send(:process_content_with_threads, downloaded_content)

    # Check that hosts were processed
    hosts = client.instance_variable_get(:@hosts)
    assert hosts.key?(:test)
    assert_includes hosts[:test], "example.com"
    assert_includes hosts[:test], "malware.example"
    assert_includes hosts[:test], "test.com"
  end

  def test_process_content_with_ractors_method
    # Only run this test if Ractors are available
    skip "Ractors not available" unless UrlCategorise::Client.ractor_available?

    client = UrlCategorise::Client.new(
      host_urls: { test: ["file://#{@temp_hosts_file}"] },
      max_ractor_workers: 2,
      parallel_loading: false
    )

    downloaded_content = {
      "test:file://#{@temp_hosts_file}" => {
        content: File.read(@temp_hosts_file),
        from_cache: false
      }
    }

    # Clear existing hosts
    client.instance_variable_set(:@hosts, {})

    # Call the private method
    client.send(:process_content_with_ractors, downloaded_content)

    # Check that hosts were processed
    hosts = client.instance_variable_get(:@hosts)
    assert hosts.key?(:test)
    assert_includes hosts[:test], "example.com"
  end

  def test_process_content_with_cached_data
    client = UrlCategorise::Client.new(
      host_urls: {},
      max_threads: 1
    )

    cached_hosts = ["cached.example.com", "another.cached.com"]
    downloaded_content = {
      "test:cached_data" => {
        hosts: cached_hosts,
        from_cache: true
      }
    }

    client.instance_variable_set(:@hosts, {})
    client.send(:process_content_with_threads, downloaded_content)

    hosts = client.instance_variable_get(:@hosts)
    assert hosts.key?(:test)
    assert_equal cached_hosts.sort, hosts[:test].sort
  end

  def test_num_workers_calculation_threads
    client = UrlCategorise::Client.new(host_urls: {}, max_threads: 8)

    # Test with many items
    downloaded_content = {}
    20.times { |i| downloaded_content["test#{i}:url"] = { content: "test", from_cache: false } }

    client.instance_variable_set(:@hosts, {})
    
    # Should use max_threads (8) as the limit
    # We can't directly test the calculation, but we can test that it works
    client.send(:process_content_with_threads, downloaded_content)
    
    # Just verify it completed without error
    assert true
  end

  def test_num_workers_calculation_ractors
    skip "Ractors not available" unless UrlCategorise::Client.ractor_available?
    
    client = UrlCategorise::Client.new(host_urls: {}, max_ractor_workers: 4)

    downloaded_content = {}
    10.times { |i| downloaded_content["test#{i}:url"] = { content: "0.0.0.0 test#{i}.com", from_cache: false } }

    client.instance_variable_set(:@hosts, {})
    client.send(:process_content_with_ractors, downloaded_content)
    
    # Just verify it completed without error
    assert true
  end

  def test_empty_downloaded_content
    client = UrlCategorise::Client.new(host_urls: {})
    
    # Test with empty content
    downloaded_content = {}
    
    client.instance_variable_set(:@hosts, {})
    client.send(:process_content_with_threads, downloaded_content)
    
    hosts = client.instance_variable_get(:@hosts)
    assert_empty hosts
  end

  def test_worker_pool_limits_are_respected
    client = UrlCategorise::Client.new(host_urls: {}, max_threads: 1)
    
    # Create content that would require more than 1 worker if unlimited
    downloaded_content = {
      "test1:url1" => { content: "0.0.0.0 test1.com", from_cache: false },
      "test2:url2" => { content: "0.0.0.0 test2.com", from_cache: false },
      "test3:url3" => { content: "0.0.0.0 test3.com", from_cache: false }
    }
    
    client.instance_variable_set(:@hosts, {})
    
    # This should work with only 1 thread
    client.send(:process_content_with_threads, downloaded_content)
    
    hosts = client.instance_variable_get(:@hosts)
    assert_equal 3, hosts.keys.size  # Should process all 3 categories
  end
end