require 'test_helper'

class BackwardsCompatibilityTest < Minitest::Test
  def setup
    WebMock.reset!

    # Set up various mock responses to test different scenarios
    WebMock.stub_request(:get, 'http://example.com/malware.txt')
           .to_return(body: "0.0.0.0 badsite.com\n0.0.0.0 evilsite.com")
    WebMock.stub_request(:get, 'http://example.com/ads.txt')
           .to_return(body: "0.0.0.0 adsite1.com\n0.0.0.0 adsite2.com")
    WebMock.stub_request(:get, 'http://example.com/phishing.txt')
           .to_return(body: "0.0.0.0 phishsite.com\n0.0.0.0 scamsite.com")
  end

  def test_regular_categorization_unchanged
    # Test that regular categorization without symbol references still works exactly the same
    host_urls = {
      malware: ['http://example.com/malware.txt'],
      ads: ['http://example.com/ads.txt'],
      phishing: ['http://example.com/phishing.txt']
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test each category individually
    malware_categories = client.categorise('badsite.com')
    assert_equal [:malware], malware_categories, 'Regular malware categorization should be unchanged'

    ads_categories = client.categorise('adsite1.com')
    assert_equal [:ads], ads_categories, 'Regular ads categorization should be unchanged'

    phishing_categories = client.categorise('phishsite.com')
    assert_equal [:phishing], phishing_categories, 'Regular phishing categorization should be unchanged'

    # Test non-matching domain
    none_categories = client.categorise('goodsite.com')
    assert_equal [], none_categories, 'Non-matching domains should still return empty array'
  end

  def test_multiple_category_matching_unchanged
    # Test that a domain appearing in multiple separate categories still works
    WebMock.stub_request(:get, 'http://example.com/overlap1.txt')
           .to_return(body: '0.0.0.0 overlap.com')
    WebMock.stub_request(:get, 'http://example.com/overlap2.txt')
           .to_return(body: '0.0.0.0 overlap.com')

    host_urls = {
      category1: ['http://example.com/overlap1.txt'],
      category2: ['http://example.com/overlap2.txt']
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Should appear in both categories (not symbol reference, just overlap)
    overlap_categories = client.categorise('overlap.com')
    assert_equal 2, overlap_categories.length, 'Overlapping domains should be in multiple categories'
    assert_includes overlap_categories, :category1, 'Should be in category1'
    assert_includes overlap_categories, :category2, 'Should be in category2'
  end

  def test_www_prefix_handling_unchanged
    # Test that www prefix handling still works the same
    host_urls = {
      test: ['http://example.com/malware.txt'] # Contains badsite.com
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Both should work the same
    plain_categories = client.categorise('badsite.com')
    www_categories = client.categorise('www.badsite.com')

    assert_equal plain_categories, www_categories, 'www prefix handling should be unchanged'
    assert_includes plain_categories, :test, 'Plain domain should be categorized'
    assert_includes www_categories, :test, 'WWW domain should be categorized'
  end

  def test_subdomain_matching_unchanged
    # Test that subdomain matching still works the same
    host_urls = {
      test: ['http://example.com/malware.txt'] # Contains badsite.com
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test various subdomains
    subdomains = ['badsite.com', 'www.badsite.com', 'mail.badsite.com', 'api.badsite.com']

    subdomains.each do |subdomain|
      categories = client.categorise(subdomain)
      assert_includes categories, :test, "#{subdomain} should be categorized correctly"
    end
  end

  def test_empty_categories_still_work
    # Test that empty categories don't break anything
    host_urls = {
      working: ['http://example.com/malware.txt'],
      empty: []
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Working category should work
    working_categories = client.categorise('badsite.com')
    assert_includes working_categories, :working, 'Working category should function'

    # Empty category should be empty
    assert_equal [], client.hosts[:empty], 'Empty category should have no hosts'
  end

  def test_invalid_urls_still_handled
    # Test that invalid URLs are still handled gracefully
    host_urls = {
      valid: ['http://example.com/malware.txt'],
      invalid: ['not-a-url', 'ftp://invalid.com']
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Valid category should work
    valid_categories = client.categorise('badsite.com')
    assert_includes valid_categories, :valid, 'Valid category should work'

    # Invalid URLs should be ignored, category should exist but be empty
    assert client.hosts[:invalid].empty? || client.hosts[:invalid] == [[]],
           'Invalid URLs should result in empty or [[]] hosts'
  end

  def test_hosts_data_structure_unchanged
    # Test that the internal hosts data structure is still the same format
    host_urls = {
      test: ['http://example.com/malware.txt']
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Check hosts structure
    hosts = client.hosts
    assert_instance_of Hash, hosts, 'Hosts should be a Hash'
    assert_includes hosts.keys, :test, 'Should contain test category'
    assert_instance_of Array, hosts[:test], 'Category hosts should be an Array'
    assert_includes hosts[:test], 'badsite.com', 'Should contain expected host'
    assert_includes hosts[:test], 'evilsite.com', 'Should contain expected host'
  end

  def test_client_public_api_unchanged
    # Test that all public methods still work the same
    host_urls = {
      test: ['http://example.com/malware.txt']
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test public methods return expected types
    assert_instance_of Hash, client.host_urls, 'host_urls should return Hash'
    assert_instance_of Hash, client.hosts, 'hosts should return Hash'
    assert_instance_of Hash, client.metadata, 'metadata should return Hash'
    assert_instance_of Integer, client.count_of_hosts, 'count_of_hosts should return Integer'
    assert_instance_of Integer, client.count_of_categories, 'count_of_categories should return Integer'
    assert client.size_of_data.is_a?(Numeric), 'size_of_data should return Numeric'
    assert_instance_of Array, client.categorise('test.com'), 'categorise should return Array'
    assert_instance_of Array, client.categorise_ip('1.2.3.4'), 'categorise_ip should return Array'
  end

  def test_symbol_references_now_work
    # Test that symbol references now work correctly (the main fix)
    host_urls = {
      base: ['http://example.com/malware.txt'],      # badsite.com, evilsite.com
      extended: ['http://example.com/ads.txt'],      # adsite1.com, adsite2.com
      combined: %i[base extended] # Should include both
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test that combined category has hosts from both referenced categories
    combined_hosts = client.hosts[:combined]
    assert_includes combined_hosts, 'badsite.com', 'Combined should include hosts from base'
    assert_includes combined_hosts, 'evilsite.com', 'Combined should include hosts from base'
    assert_includes combined_hosts, 'adsite1.com', 'Combined should include hosts from extended'
    assert_includes combined_hosts, 'adsite2.com', 'Combined should include hosts from extended'

    # Test categorization works for combined category
    base_categories = client.categorise('badsite.com')
    assert_includes base_categories, :base, 'Should be in base category'
    assert_includes base_categories, :combined, 'Should be in combined category'

    extended_categories = client.categorise('adsite1.com')
    assert_includes extended_categories, :extended, 'Should be in extended category'
    assert_includes extended_categories, :combined, 'Should be in combined category'
  end
end
