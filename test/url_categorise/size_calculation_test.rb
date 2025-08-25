require_relative '../test_helper'
require 'json'

class SizeCalculationTest < Minitest::Test
  def setup
    @cache_dir = './test/tmp/cache'
    FileUtils.mkdir_p(@cache_dir)

    # Clean up from any previous tests
    FileUtils.rm_rf(Dir.glob('./test/tmp/**/*'))

    # Mock data for default host URLs to avoid network calls
    stub_request(:head, /.*/)
      .to_return(status: 200)
    stub_request(:get, /.*/)
      .to_return(status: 200, body: generate_test_blocklist_content)
  end

  def teardown
    FileUtils.rm_rf('./test/tmp') if Dir.exist?('./test/tmp')
  end

  def test_size_of_data_includes_all_data
    client = UrlCategorise::Client.new(
      host_urls: { malware: ['https://example.com/malware.txt'] },
      cache_dir: @cache_dir
    )

    # Add some dataset data
    client.hosts[:dataset_category] = generate_test_domains(50)
    client.instance_variable_get(:@dataset_categories).add(:dataset_category)

    total_size_bytes = client.size_of_data_bytes
    dataset_size_bytes = client.size_of_dataset_data_bytes
    blocklist_size_bytes = client.size_of_blocklist_data_bytes

    # Total size should equal dataset + blocklist sizes
    assert_equal total_size_bytes, dataset_size_bytes + blocklist_size_bytes
    assert total_size_bytes > 0, 'Total data size should be greater than 0 bytes'

    # MB versions should also work (though they may be 0.0 for small data)
    total_size_mb = client.size_of_data
    dataset_size_mb = client.size_of_dataset_data
    blocklist_size_mb = client.size_of_blocklist_data

    assert_in_delta total_size_mb, dataset_size_mb + blocklist_size_mb, 0.01
  end

  def test_size_of_dataset_data_only_includes_dataset_categories
    client = UrlCategorise::Client.new(
      host_urls: { malware: ['https://example.com/malware.txt'] },
      cache_dir: @cache_dir
    )

    # Initially should be 0 - no datasets loaded
    assert_equal 0, client.size_of_dataset_data_bytes
    assert_equal 0.0, client.size_of_dataset_data

    # Add dataset category
    dataset_domains = generate_test_domains(100)
    client.hosts[:dataset_test] = dataset_domains
    client.instance_variable_get(:@dataset_categories).add(:dataset_test)

    dataset_size_bytes = client.size_of_dataset_data_bytes
    assert dataset_size_bytes > 0, 'Dataset size should be greater than 0 bytes after adding dataset'

    # Add another regular blocklist category - should not affect dataset size
    client.hosts[:regular_category] = generate_test_domains(50)

    assert_equal dataset_size_bytes, client.size_of_dataset_data_bytes,
                 'Dataset size should remain the same when adding non-dataset categories'
  end

  def test_size_of_blocklist_data_only_includes_blocklist_categories
    client = UrlCategorise::Client.new(
      host_urls: { malware: ['https://example.com/malware.txt'] },
      cache_dir: @cache_dir
    )

    initial_blocklist_size_bytes = client.size_of_blocklist_data_bytes
    assert initial_blocklist_size_bytes > 0, 'Initial blocklist size should be greater than 0 bytes'

    # Add dataset category - should not affect blocklist size
    dataset_domains = generate_test_domains(100)
    client.hosts[:dataset_test] = dataset_domains
    client.instance_variable_get(:@dataset_categories).add(:dataset_test)

    assert_equal initial_blocklist_size_bytes, client.size_of_blocklist_data_bytes,
                 'Blocklist size should remain the same when adding dataset categories'

    # Add regular category - should increase blocklist size
    client.hosts[:new_blocklist] = generate_test_domains(50)
    new_blocklist_size_bytes = client.size_of_blocklist_data_bytes

    assert new_blocklist_size_bytes > initial_blocklist_size_bytes,
           'Blocklist size should increase when adding new blocklist categories'
  end

  def test_size_calculations_with_empty_categories
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @cache_dir
    )

    assert_equal 0, client.size_of_data_bytes
    assert_equal 0, client.size_of_dataset_data_bytes
    assert_equal 0, client.size_of_blocklist_data_bytes
    assert_equal 0.0, client.size_of_data
    assert_equal 0.0, client.size_of_dataset_data
    assert_equal 0.0, client.size_of_blocklist_data
  end

  def test_size_calculations_with_mixed_data
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @cache_dir
    )

    # Add blocklist categories
    client.hosts[:malware] = generate_test_domains(50, 'malware-domain-')
    client.hosts[:phishing] = generate_test_domains(30, 'phishing-domain-')

    # Add dataset categories
    client.hosts[:dataset_malware] = generate_test_domains(40, 'dataset-malware-')
    client.hosts[:dataset_phishing] = generate_test_domains(20, 'dataset-phishing-')

    dataset_categories = client.instance_variable_get(:@dataset_categories)
    dataset_categories.add(:dataset_malware)
    dataset_categories.add(:dataset_phishing)

    total_size_bytes = client.size_of_data_bytes
    dataset_size_bytes = client.size_of_dataset_data_bytes
    blocklist_size_bytes = client.size_of_blocklist_data_bytes

    assert total_size_bytes > 0, 'Total size should be greater than 0 bytes'
    assert dataset_size_bytes > 0, 'Dataset size should be greater than 0 bytes'
    assert blocklist_size_bytes > 0, 'Blocklist size should be greater than 0 bytes'

    # Total should equal the sum of parts
    assert_equal total_size_bytes, dataset_size_bytes + blocklist_size_bytes

    # MB versions
    total_size_mb = client.size_of_data
    dataset_size_mb = client.size_of_dataset_data
    blocklist_size_mb = client.size_of_blocklist_data
    assert_in_delta total_size_mb, dataset_size_mb + blocklist_size_mb, 0.01

    # Verify counts match expectations
    assert_equal 2, client.count_of_dataset_categories
    assert_equal 60, client.count_of_dataset_hosts # 40 + 20
    assert_equal 80, client.count_of_hosts - client.count_of_dataset_hosts # Total - dataset = blocklist
  end

  def test_size_calculations_with_large_domains
    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: @cache_dir
    )

    # Add domains with longer names to test size calculation accuracy
    long_domains = [
      'very-long-malicious-domain-name-for-testing-size-calculation-accuracy.com',
      'another-extremely-long-domain-name-that-should-contribute-significantly-to-data-size.org',
      'third-long-domain-with-many-subdomains.subdomain1.subdomain2.subdomain3.example.com'
    ] * 100 # Multiply to get more data

    client.hosts[:large_dataset] = long_domains
    client.instance_variable_get(:@dataset_categories).add(:large_dataset)

    dataset_size_bytes = client.size_of_dataset_data_bytes
    total_size_bytes = client.size_of_data_bytes

    assert dataset_size_bytes > 1000, 'Dataset with long domains should have measurable size (>1000 bytes)'
    assert_equal total_size_bytes, dataset_size_bytes, 'Total size should equal dataset size when only datasets present'

    # MB versions should also work and be measurable now
    dataset_size_mb = client.size_of_dataset_data
    total_size_mb = client.size_of_data
    assert dataset_size_mb > 0, 'Dataset MB size should be measurable with large domains'
    assert_equal total_size_mb, dataset_size_mb, 'Total MB size should equal dataset MB size'
  end

  def test_size_calculation_consistency_after_reload
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    # Manually add dataset data to simulate loaded datasets
    client.hosts[:test_dataset] = generate_test_domains(50)
    client.instance_variable_get(:@dataset_categories).add(:test_dataset)

    original_total_size_bytes = client.size_of_data_bytes
    original_dataset_size_bytes = client.size_of_dataset_data_bytes

    # Reload should preserve dataset data sizes
    reloaded_client = client.reload_with_datasets

    assert_equal original_total_size_bytes, reloaded_client.size_of_data_bytes,
                 'Total size should remain consistent after reload'
    assert_equal original_dataset_size_bytes, reloaded_client.size_of_dataset_data_bytes,
                 'Dataset size should remain consistent after reload'
    # NOTE: blocklist size might change due to fresh downloads, so we don't test it here
  end

  def test_size_calculation_with_csv_dataset_integration
    dataset_config = {
      download_path: './test/tmp/downloads',
      cache_path: './test/tmp/datasets'
    }

    client = UrlCategorise::Client.new(
      host_urls: { test: ['https://example.com/list.txt'] },
      cache_dir: @cache_dir,
      dataset_config: dataset_config
    )

    csv_content = generate_csv_dataset_content(100)
    stub_request(:get, 'https://example.com/dataset.csv')
      .to_return(status: 200, body: csv_content)

    initial_dataset_size_bytes = client.size_of_dataset_data_bytes
    initial_total_size_bytes = client.size_of_data_bytes

    # Load CSV dataset
    client.load_csv_dataset('https://example.com/dataset.csv')

    new_dataset_size_bytes = client.size_of_dataset_data_bytes
    new_total_size_bytes = client.size_of_data_bytes

    assert new_dataset_size_bytes > initial_dataset_size_bytes,
           'Dataset size should increase after loading CSV dataset'
    assert new_total_size_bytes > initial_total_size_bytes,
           'Total size should increase after loading CSV dataset'

    # Dataset categories should be tracked
    refute_empty client.dataset_categories,
                 'Dataset categories should be tracked after loading CSV'
  end

  private

  def generate_test_blocklist_content
    domains = generate_test_domains(20, 'blocklist-domain-')
    domains.map { |domain| "0.0.0.0 #{domain}" }.join("\n")
  end

  def generate_test_domains(count, prefix = 'test-domain-')
    (1..count).map { |i| "#{prefix}#{i}.com" }
  end

  def generate_csv_dataset_content(count)
    header = "url,category\n"
    rows = (1..count).map do |i|
      "https://csv-test-domain-#{i}.com,malware"
    end
    header + rows.join("\n")
  end
end
