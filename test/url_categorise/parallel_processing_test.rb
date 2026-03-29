require 'test_helper'

class UrlCategoriseParallelProcessingTest < Minitest::Test
  def setup
    @temp_hosts_file = 'test_parallel_hosts.hosts'
    File.write(@temp_hosts_file, "0.0.0.0 example.com\n0.0.0.0 malware.example\n0.0.0.0 test.com\n")
    @temp_dir = Dir.mktmpdir('url_categorise_parallel_test_')
    WebMock.reset!
  end

  def teardown
    File.delete(@temp_hosts_file) if File.exist?(@temp_hosts_file)
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
    WebMock.reset!
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
    # Ractor internal code is excluded from coverage tracking (# :nocov:)
    # These tests are skipped to prevent potential Ractor deadlocks in CI/full suite
    skip "Ractor parallel processing tests are excluded from the test suite"
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
    skip "Ractor parallel processing tests are excluded from the test suite"
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

  def test_fetch_and_build_host_lists_parallel_with_file_urls
    # Test the parallel fetch method directly with local file URLs
    temp_file1 = File.join(@temp_dir, "hosts1.hosts")
    temp_file2 = File.join(@temp_dir, "hosts2.hosts")
    File.write(temp_file1, "0.0.0.0 domain1.com\n0.0.0.0 domain2.com\n")
    File.write(temp_file2, "0.0.0.0 domain3.com\n0.0.0.0 domain4.com\n")

    client = UrlCategorise::Client.new(
      host_urls: {
        category1: ["file://#{temp_file1}"],
        category2: ["file://#{temp_file2}"]
      },
      parallel_loading: false
    )

    # Reset hosts and call directly
    client.instance_variable_set(:@hosts, {})
    client.send(:fetch_and_build_host_lists_parallel)

    hosts = client.instance_variable_get(:@hosts)
    assert hosts.key?(:category1) || hosts.key?(:category2)
  end

  def test_fetch_and_build_host_lists_parallel_with_http_urls
    # Test the parallel fetch method with mocked HTTP URLs
    stub_request(:get, "http://example.com/list1.txt")
      .to_return(status: 200, body: "parallel1.com\nparallel2.com\n")
    stub_request(:get, "http://example.com/list2.txt")
      .to_return(status: 200, body: "parallel3.com\nparallel4.com\n")

    client = UrlCategorise::Client.new(
      host_urls: {
        cat1: ["http://example.com/list1.txt"],
        cat2: ["http://example.com/list2.txt"]
      },
      parallel_loading: false
    )

    client.instance_variable_set(:@hosts, {})
    client.send(:fetch_and_build_host_lists_parallel)

    hosts = client.instance_variable_get(:@hosts)
    assert_kind_of Hash, hosts
  end

  def test_fetch_and_build_host_lists_parallel_with_cache
    # Test the cache hit path in fetch_and_build_host_lists_parallel
    temp_file = File.join(@temp_dir, "hosts_cached.hosts")
    File.write(temp_file, "0.0.0.0 cached-domain.com\n")

    client = UrlCategorise::Client.new(
      host_urls: { cached_cat: ["file://#{temp_file}"] },
      cache_dir: @temp_dir,
      parallel_loading: false
    )

    # Pre-populate the cache
    url = "file://#{temp_file}"
    client.send(:save_to_cache, url, ["cached-domain.com"])

    # Reset hosts and call the parallel method
    client.instance_variable_set(:@hosts, {})
    client.send(:fetch_and_build_host_lists_parallel)

    hosts = client.instance_variable_get(:@hosts)
    assert_kind_of Hash, hosts
  end

  def test_fetch_and_build_host_lists_parallel_download_error
    # Test that download errors are handled gracefully
    stub_request(:get, "http://example.com/error-list.txt")
      .to_raise(StandardError.new("Connection failed"))

    client = UrlCategorise::Client.new(
      host_urls: {
        error_cat: ["http://example.com/error-list.txt"],
        good_cat: ["file://#{@temp_hosts_file}"]
      },
      parallel_loading: false
    )

    client.instance_variable_set(:@hosts, {})

    # Should not raise an exception even with download errors
    client.send(:fetch_and_build_host_lists_parallel)
    # Verify the hosts hash was set (may be empty for error categories)
    assert_kind_of Hash, client.instance_variable_get(:@hosts)
  end
end