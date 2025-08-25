require 'test_helper'

class UrlCategoriseClientDatasetMethodsTest < Minitest::Test
  def setup
    WebMock.stub_request(:get, 'http://example.com/malware.txt')
           .to_return(body: "0.0.0.0 badsite.com\n0.0.0.0 evilsite.com")
    WebMock.stub_request(:get, 'http://example.com/ads.txt')
           .to_return(body: "0.0.0.0 adsite1.com\n0.0.0.0 adsite2.com")

    @client = UrlCategorise::Client.new(host_urls: test_host_urls)
  end

  def test_count_of_dataset_hosts_with_no_datasets
    assert_equal 0, @client.count_of_dataset_hosts
  end

  def test_count_of_dataset_categories_with_no_datasets
    assert_equal 0, @client.count_of_dataset_categories
  end

  def test_count_of_hosts_includes_dns_lists_only
    # Total hosts from DNS lists only
    expected_count = 4 # 2 from malware + 2 from ads
    assert_equal expected_count, @client.count_of_hosts
  end

  def test_count_of_categories_includes_dns_lists_only
    assert_equal 2, @client.count_of_categories # malware and advertising
  end

  def test_dataset_categories_tracks_dataset_categories
    # Initially empty
    assert_instance_of Set, @client.dataset_categories
    assert_equal 0, @client.dataset_categories.size

    # Simulate adding dataset categories by directly manipulating the instance
    # This tests the tracking mechanism
    @client.dataset_categories.add(:test_dataset_category)
    @client.instance_variable_get(:@hosts)[:test_dataset_category] = ['dataset.example.com', 'dataset2.example.com']

    assert_equal 1, @client.count_of_dataset_categories
    assert_equal 2, @client.count_of_dataset_hosts

    # Total counts should include both DNS lists and datasets
    assert_equal 6, @client.count_of_hosts # 4 + 2
    assert_equal 3, @client.count_of_categories # 2 + 1
  end

  def test_dataset_categories_with_multiple_dataset_categories
    # Add multiple dataset categories
    @client.dataset_categories.add(:dataset_category_1)
    @client.dataset_categories.add(:dataset_category_2)

    @client.instance_variable_get(:@hosts)[:dataset_category_1] = ['site1.com', 'site2.com', 'site3.com']
    @client.instance_variable_get(:@hosts)[:dataset_category_2] = ['site4.com']

    assert_equal 2, @client.count_of_dataset_categories
    assert_equal 4, @client.count_of_dataset_hosts
  end

  def test_dataset_categories_with_empty_category
    # Add dataset category with no hosts
    @client.dataset_categories.add(:empty_dataset_category)
    @client.instance_variable_get(:@hosts)[:empty_dataset_category] = []

    assert_equal 1, @client.count_of_dataset_categories
    assert_equal 0, @client.count_of_dataset_hosts
  end

  def test_dataset_categories_with_nil_category
    # Add dataset category that doesn't exist in hosts
    @client.dataset_categories.add(:nonexistent_category)

    assert_equal 1, @client.count_of_dataset_categories
    assert_equal 0, @client.count_of_dataset_hosts # Should handle nil gracefully
  end

  def test_dataset_categories_integration_with_existing_methods
    # Test that existing methods still work correctly when datasets are present
    @client.dataset_categories.add(:test_integration)
    @client.instance_variable_get(:@hosts)[:test_integration] = ['integration.example.com']

    # size_of_data should work with dataset categories
    data_size = @client.size_of_data
    assert_kind_of Numeric, data_size
    assert_operator data_size, :>=, 0
  end

  private

  def test_host_urls
    {
      malware: ['http://example.com/malware.txt'],
      advertising: ['http://example.com/ads.txt']
    }
  end
end
