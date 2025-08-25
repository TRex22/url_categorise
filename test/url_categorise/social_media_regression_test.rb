require 'test_helper'

class SocialMediaRegressionTest < Minitest::Test
  def setup
    WebMock.reset!

    # Mock various social media lists
    WebMock.stub_request(:get, 'http://example.com/reddit.txt')
           .to_return(body: "0.0.0.0 reddit.com\n0.0.0.0 www.reddit.com")
    WebMock.stub_request(:get, 'http://example.com/facebook.txt')
           .to_return(body: "0.0.0.0 facebook.com\n0.0.0.0 www.facebook.com")
    WebMock.stub_request(:get, 'http://example.com/twitter.txt')
           .to_return(body: "0.0.0.0 twitter.com\n0.0.0.0 t.co")
    WebMock.stub_request(:get, 'http://example.com/malware.txt')
           .to_return(body: "0.0.0.0 badsite.com\n0.0.0.0 evilsite.com")
  end

  def test_social_media_category_resolution_comprehensive
    # Test comprehensive social media setup similar to real constants
    host_urls = {
      reddit: ['http://example.com/reddit.txt'],
      facebook: ['http://example.com/facebook.txt'],
      twitter: ['http://example.com/twitter.txt'],
      malware: ['http://example.com/malware.txt'],
      social_media: %i[reddit facebook twitter] # References multiple categories
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test that social_media includes hosts from all referenced categories
    social_hosts = client.hosts[:social_media]
    assert_includes social_hosts, 'reddit.com', 'social_media should include reddit.com'
    assert_includes social_hosts, 'facebook.com', 'social_media should include facebook.com'
    assert_includes social_hosts, 'twitter.com', 'social_media should include twitter.com'
    assert_includes social_hosts, 't.co', 'social_media should include t.co from twitter list'

    # Test that non-social categories are not affected
    malware_hosts = client.hosts[:malware]
    assert_includes malware_hosts, 'badsite.com', 'malware category should work normally'
    refute_includes malware_hosts, 'reddit.com', 'malware should not include social media hosts'

    # Test categorization returns both specific and general categories for social media
    reddit_categories = client.categorise('reddit.com')
    assert_includes reddit_categories, :reddit, 'reddit.com should be categorized as :reddit'
    assert_includes reddit_categories, :social_media, 'reddit.com should be categorized as :social_media'
    assert_equal 2, reddit_categories.length, 'reddit.com should be in exactly 2 categories'

    facebook_categories = client.categorise('facebook.com')
    assert_includes facebook_categories, :facebook, 'facebook.com should be categorized as :facebook'
    assert_includes facebook_categories, :social_media, 'facebook.com should be categorized as :social_media'

    twitter_categories = client.categorise('t.co')
    assert_includes twitter_categories, :twitter, 't.co should be categorized as :twitter'
    assert_includes twitter_categories, :social_media, 't.co should be categorized as :social_media'

    # Test non-social media categorization is unaffected
    malware_categories = client.categorise('badsite.com')
    assert_includes malware_categories, :malware, 'badsite.com should be categorized as :malware'
    refute_includes malware_categories, :social_media, 'badsite.com should NOT be in social_media'
    assert_equal 1, malware_categories.length, 'badsite.com should be in exactly 1 category'
  end

  def test_nested_symbol_references
    # Test that symbol references can reference other symbol references
    host_urls = {
      facebook: ['http://example.com/facebook.txt'],
      twitter: ['http://example.com/twitter.txt'],
      meta_platforms: [:facebook], # References facebook
      social_media: %i[meta_platforms twitter] # References both meta_platforms and twitter
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test that nested references work
    social_hosts = client.hosts[:social_media]
    assert_includes social_hosts, 'facebook.com', 'social_media should include facebook.com through meta_platforms'
    assert_includes social_hosts, 'twitter.com', 'social_media should include twitter.com directly'

    meta_hosts = client.hosts[:meta_platforms]
    assert_includes meta_hosts, 'facebook.com', 'meta_platforms should include facebook.com'
    refute_includes meta_hosts, 'twitter.com', 'meta_platforms should NOT include twitter.com'

    # Test categorization
    facebook_categories = client.categorise('facebook.com')
    expected_categories = %i[facebook meta_platforms social_media]
    expected_categories.each do |category|
      assert_includes facebook_categories, category, "facebook.com should be in #{category}"
    end
  end

  def test_empty_and_mixed_symbol_references
    # Test edge cases with empty references and mixed URL/symbol arrays
    host_urls = {
      reddit: ['http://example.com/reddit.txt'],
      empty_category: [], # Empty array
      mixed_category: ['http://example.com/facebook.txt', :reddit], # Mixed URLs and symbols
      social_media: %i[reddit empty_category] # References empty category
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test that empty categories don't break anything
    assert_equal [], client.hosts[:empty_category], 'empty_category should have no hosts'

    # Test mixed category works
    mixed_hosts = client.hosts[:mixed_category]
    assert_includes mixed_hosts, 'facebook.com', 'mixed_category should include facebook.com from URL'
    assert_includes mixed_hosts, 'reddit.com', 'mixed_category should include reddit.com from symbol'

    # Test that social_media handles references to empty categories gracefully
    social_hosts = client.hosts[:social_media]
    assert_includes social_hosts, 'reddit.com', 'social_media should include reddit.com'
    # Should not crash or include anything from empty_category
  end

  def test_symbol_references_with_www_prefix
    # Test that www prefixes are handled correctly in symbol references
    WebMock.stub_request(:get, 'http://example.com/reddit.txt')
           .to_return(body: "reddit.com\nwww.reddit.com\nold.reddit.com") # Various subdomains

    host_urls = {
      reddit: ['http://example.com/reddit.txt'],
      social_media: [:reddit]
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test that all variants are included
    social_hosts = client.hosts[:social_media]
    ['reddit.com', 'www.reddit.com', 'old.reddit.com'].each do |domain|
      assert_includes social_hosts, domain, "social_media should include #{domain}"
    end

    # Test categorization works for all variants
    ['reddit.com', 'www.reddit.com', 'old.reddit.com'].each do |domain|
      categories = client.categorise(domain)
      assert_includes categories, :reddit, "#{domain} should be in reddit category"
      assert_includes categories, :social_media, "#{domain} should be in social_media category"
    end

    # Test that categorisation removes www prefix correctly
    www_categories = client.categorise('www.reddit.com')
    plain_categories = client.categorise('reddit.com')
    assert_equal www_categories.sort, plain_categories.sort, 'www.reddit.com and reddit.com should have same categories'
  end

  def test_backwards_compatibility_with_non_symbol_categories
    # Test that regular categories without symbol references continue to work
    host_urls = {
      malware: ['http://example.com/malware.txt'],
      ads: ['http://example.com/reddit.txt'] # Using reddit list for ads (doesn't matter for test)
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test regular categorization
    malware_categories = client.categorise('badsite.com')
    assert_includes malware_categories, :malware, 'Regular categorization should work'
    assert_equal 1, malware_categories.length, 'Should only be in one category'

    ads_categories = client.categorise('reddit.com')
    assert_includes ads_categories, :ads, 'Regular categorization should work for ads'
    assert_equal 1, ads_categories.length, 'Should only be in one category'
  end

  def test_symbol_reference_performance
    # Test that symbol references don't cause excessive duplication
    host_urls = {
      platform1: ['http://example.com/reddit.txt'],    # reddit.com, www.reddit.com
      platform2: ['http://example.com/facebook.txt'],  # facebook.com, www.facebook.com
      social_media: %i[platform1 platform2]
    }

    client = UrlCategorise::Client.new(host_urls: host_urls)

    # Test that hosts are properly deduplicated
    social_hosts = client.hosts[:social_media]

    # Count occurrences - each domain should appear exactly once
    social_hosts.each do |host|
      occurrences = social_hosts.count(host)
      assert_equal 1, occurrences, "#{host} should appear exactly once in social_media, found #{occurrences}"
    end

    # Test expected hosts are present
    expected_hosts = ['reddit.com', 'www.reddit.com', 'facebook.com', 'www.facebook.com']
    expected_hosts.each do |host|
      assert_includes social_hosts, host, "social_media should include #{host}"
    end

    assert_equal expected_hosts.sort, social_hosts.sort, 'social_media should have exactly the expected hosts'
  end
end
