require_relative "../test_helper"

class SmartCategorizationTest < Minitest::Test
  def setup
    @cache_dir = "./test/tmp/cache"
    FileUtils.mkdir_p(@cache_dir)

    # Clean up from any previous tests
    FileUtils.rm_rf(Dir.glob("./test/tmp/**/*"))

    # Mock different responses for different URLs
    setup_mock_responses
  end

  def teardown
    FileUtils.rm_rf("./test/tmp") if Dir.exist?("./test/tmp")
  end

  def test_smart_categorization_disabled_by_default
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: nil # Disable cache to avoid HEAD request issues
    )

    assert_equal false, client.smart_categorization_enabled

    # Should get all categories without smart filtering
    categories = client.categorise("reddit.com")
    assert categories.include?(:reddit), "Expected categories to include :reddit, got #{categories.inspect}"
    assert categories.include?(:social_media)
    assert categories.include?(:health_and_fitness), "health_and_fitness should remain without smart processing"
  end

  def test_smart_categorization_enabled_for_reddit
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: nil, # Disable cache to avoid HEAD request issues
      smart_categorization: true
    )

    assert_equal true, client.smart_categorization_enabled

    # Should remove overly broad categories for Reddit
    categories = client.categorise("reddit.com")
    assert categories.include?(:reddit)
    assert categories.include?(:social_media)
    refute categories.include?(:health_and_fitness), "health_and_fitness should be removed by smart categorization"
    refute categories.include?(:forums), "forums should be removed by smart categorization"
  end

  def test_smart_categorization_for_multiple_social_platforms
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls_with_multiple_platforms,
      cache_dir: nil,
      smart_categorization: true
    )

    # Test Facebook
    facebook_categories = client.categorise("facebook.com")
    assert facebook_categories.include?(:facebook)
    assert facebook_categories.include?(:social_media)
    refute facebook_categories.include?(:news), "news should be removed for facebook"

    # Test Twitter/X
    twitter_categories = client.categorise("twitter.com")
    assert twitter_categories.include?(:twitter)
    assert twitter_categories.include?(:social_media)
    refute twitter_categories.include?(:politics), "politics should be removed for twitter"

    # Test YouTube
    youtube_categories = client.categorise("youtube.com")
    assert youtube_categories.include?(:youtube)
    assert youtube_categories.include?(:social_media)
    refute youtube_categories.include?(:education), "education should be removed for youtube"
  end

  def test_smart_categorization_for_search_engines
    client = UrlCategorise::Client.new(
      host_urls: test_search_engine_urls,
      cache_dir: nil,
      smart_categorization: true
    )

    google_categories = client.categorise("google.com")
    assert google_categories.include?(:google)
    refute google_categories.include?(:news), "news should be removed for google"
    refute google_categories.include?(:shopping), "shopping should be removed for google"
  end

  def test_custom_smart_rules
    custom_rules = {
      custom_platform: {
        domains: [ "example.com" ],
        remove_categories: [ :unwanted_category ],
        allowed_categories_only: %i[example test]
      }
    }

    client = UrlCategorise::Client.new(
      host_urls: {
        example: [ "http://example.com/example-list.txt" ],
        test: [ "http://example.com/test-list.txt" ],
        unwanted_category: [ "http://example.com/unwanted-list.txt" ],
        should_be_removed: [ "http://example.com/should-be-removed-list.txt" ]
      },
      cache_dir: nil,
      smart_categorization: true,
      smart_rules: custom_rules
    )

    categories = client.categorise("example.com")
    assert categories.include?(:example)
    assert categories.include?(:test)
    refute categories.include?(:unwanted_category), "unwanted_category should be removed by custom rule"
    refute categories.include?(:should_be_removed),
           "should_be_removed should be filtered out by allowed_categories_only"
  end

  def test_path_based_categorization
    custom_rules = {
      reddit_paths: {
        domains: [ "reddit.com" ],
        remove_categories: %i[health_and_fitness forums],
        add_categories_by_path: {
          %r{/r/fitness} => [ :health_and_fitness ],
          %r{/r/technology} => [ :technology ],
          %r{/r/programming} => %i[technology programming]
        }
      }
    }

    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @cache_dir,
      smart_categorization: true,
      smart_rules: custom_rules
    )

    # Base reddit.com should not have health_and_fitness
    base_categories = client.categorise("reddit.com")
    refute base_categories.include?(:health_and_fitness)

    # reddit.com/r/fitness should have health_and_fitness added back
    fitness_categories = client.categorise("https://reddit.com/r/fitness")
    assert fitness_categories.include?(:reddit)
    assert fitness_categories.include?(:social_media)
    assert fitness_categories.include?(:health_and_fitness), "health_and_fitness should be added for /r/fitness"

    # reddit.com/r/programming should have technology and programming
    programming_categories = client.categorise("https://reddit.com/r/programming")
    assert programming_categories.include?(:technology)
    assert programming_categories.include?(:programming)
  end

  def test_keep_primary_only_rule
    custom_rules = {
      news_aggregator: {
        domains: [ "reddit.com" ],
        keep_primary_only: %i[social_media reddit]
      }
    }

    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @cache_dir,
      smart_categorization: true,
      smart_rules: custom_rules
    )

    categories = client.categorise("reddit.com")
    assert_equal 2, categories.length
    assert categories.include?(:reddit)
    assert categories.include?(:social_media)
    refute categories.include?(:health_and_fitness)
    refute categories.include?(:forums)
  end

  def test_smart_categorization_with_subdomain
    client = UrlCategorise::Client.new(
      host_urls: {
        reddit: [ "http://example.com/reddit-list.txt" ],
        social_media: [ "http://example.com/social-media-list.txt" ],
        health_and_fitness: [ "http://example.com/health-list.txt" ]
      },
      cache_dir: nil,
      smart_categorization: true
    )

    # Test that subdomains are properly handled
    categories = client.categorise("old.reddit.com")
    assert categories.include?(:reddit)
    assert categories.include?(:social_media)
    refute categories.include?(:health_and_fitness), "health_and_fitness should be removed for subdomain"
  end

  def test_smart_categorization_with_iab_compliance
    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @cache_dir,
      smart_categorization: true,
      iab_compliance: true,
      iab_version: :v3
    )

    categories = client.categorise("reddit.com")

    # Should be IAB codes after smart processing
    assert categories.is_a?(Array)
    # The exact IAB codes depend on the mapping, but should not include removed categories
    refute categories.empty?, "Should have some IAB categories after smart processing"
  end

  def test_smart_categorization_preserves_non_social_media_sites
    client = UrlCategorise::Client.new(
      host_urls: {
        malware: [ "http://example.com/malware-list.txt" ],
        phishing: [ "http://example.com/phishing-list.txt" ]
      },
      cache_dir: nil,
      smart_categorization: true
    )

    # Non-social media sites should not be affected
    categories = client.categorise("badsite.com")
    assert categories.include?(:malware)
    assert categories.include?(:phishing)
  end

  def test_smart_rules_merge_with_defaults
    custom_rules = {
      my_custom_rule: {
        domains: [ "custom.com" ],
        remove_categories: [ :unwanted ]
      }
    }

    client = UrlCategorise::Client.new(
      host_urls: test_host_urls,
      cache_dir: @cache_dir,
      smart_categorization: true,
      smart_rules: custom_rules
    )

    # Should have both default and custom rules
    assert client.smart_rules.key?(:social_media_platforms) # Default rule
    assert client.smart_rules.key?(:my_custom_rule) # Custom rule
  end

  def test_smart_categorization_edge_cases
    client = UrlCategorise::Client.new(
      host_urls: {
        reddit: [ "reddit.com" ],
        social_media: [ "reddit.com" ]
      },
      cache_dir: @cache_dir,
      smart_categorization: true
    )

    # Test with malformed URL
    categories = client.categorise("not-a-valid-url")
    assert categories.is_a?(Array)

    # Test with empty categories
    empty_categories = client.categorise("nonexistent-domain.com")
    assert_empty empty_categories

    # Test with nil/empty input should be handled gracefully by parent method
  end

  private

  def setup_mock_responses
    WebMock.reset!

    # Fallback GET stub - must be FIRST so specific ones can override
    WebMock.stub_request(:get, /.*/)
           .to_return(status: 200, body: "0.0.0.0 blocked-domain.com")

    # HEAD request stubs - also first for same reason
    WebMock.stub_request(:head, /.*/)
           .to_return(status: 200)

    # Now set up exact URL stubs that will override the fallback
    WebMock.stub_request(:get, "http://example.com/reddit-list.txt")
           .to_return(status: 200, body: "0.0.0.0 reddit.com")
    WebMock.stub_request(:get, "http://example.com/social-media-list.txt")
           .to_return(status: 200, body: "0.0.0.0 reddit.com\n0.0.0.0 facebook.com\n0.0.0.0 twitter.com\n0.0.0.0 youtube.com")
    WebMock.stub_request(:get, "http://example.com/health-list.txt")
           .to_return(status: 200, body: "0.0.0.0 reddit.com")
    WebMock.stub_request(:get, "http://example.com/forums-list.txt")
           .to_return(status: 200, body: "0.0.0.0 reddit.com")
    WebMock.stub_request(:get, "http://example.com/facebook-list.txt")
           .to_return(status: 200, body: "0.0.0.0 facebook.com")
    WebMock.stub_request(:get, "http://example.com/twitter-list.txt")
           .to_return(status: 200, body: "0.0.0.0 twitter.com")
    WebMock.stub_request(:get, "http://example.com/youtube-list.txt")
           .to_return(status: 200, body: "0.0.0.0 youtube.com")
    WebMock.stub_request(:get, "http://example.com/news-list.txt")
           .to_return(status: 200, body: "0.0.0.0 facebook.com\n0.0.0.0 twitter.com\n0.0.0.0 google.com")
    WebMock.stub_request(:get, "http://example.com/politics-list.txt")
           .to_return(status: 200, body: "0.0.0.0 twitter.com")
    WebMock.stub_request(:get, "http://example.com/education-list.txt")
           .to_return(status: 200, body: "0.0.0.0 youtube.com")
    WebMock.stub_request(:get, "http://example.com/google-list.txt")
           .to_return(status: 200, body: "0.0.0.0 google.com")
    WebMock.stub_request(:get, "http://example.com/shopping-list.txt")
           .to_return(status: 200, body: "0.0.0.0 google.com")

    # Additional stubs for custom rules test
    WebMock.stub_request(:get, "http://example.com/example-list.txt")
           .to_return(status: 200, body: "0.0.0.0 example.com")
    WebMock.stub_request(:get, "http://example.com/test-list.txt")
           .to_return(status: 200, body: "0.0.0.0 example.com")
    WebMock.stub_request(:get, "http://example.com/unwanted-list.txt")
           .to_return(status: 200, body: "0.0.0.0 example.com")
    WebMock.stub_request(:get, "http://example.com/should-be-removed-list.txt")
           .to_return(status: 200, body: "0.0.0.0 example.com")

    # Additional stubs for non-social media test
    WebMock.stub_request(:get, "http://example.com/malware-list.txt")
           .to_return(status: 200, body: "0.0.0.0 badsite.com")
    WebMock.stub_request(:get, "http://example.com/phishing-list.txt")
           .to_return(status: 200, body: "0.0.0.0 badsite.com")

    # Pattern matching stubs for other test URLs - be more specific to avoid conflicts
    WebMock.stub_request(:get, /malware/)
           .to_return(status: 200, body: "0.0.0.0 badsite.com")
    WebMock.stub_request(:get, /phishing/)
           .to_return(status: 200, body: "0.0.0.0 badsite.com")
  end

  def test_host_urls
    {
      reddit: [ "http://example.com/reddit-list.txt" ],
      social_media: [ "http://example.com/social-media-list.txt" ],
      health_and_fitness: [ "http://example.com/health-list.txt" ],
      forums: [ "http://example.com/forums-list.txt" ]
    }
  end

  def test_host_urls_with_multiple_platforms
    {
      facebook: [ "http://example.com/facebook-list.txt" ],
      twitter: [ "http://example.com/twitter-list.txt" ],
      youtube: [ "http://example.com/youtube-list.txt" ],
      social_media: [ "http://example.com/social-media-list.txt" ],
      news: [ "http://example.com/news-list.txt" ],
      politics: [ "http://example.com/politics-list.txt" ],
      education: [ "http://example.com/education-list.txt" ]
    }
  end

  def test_search_engine_urls
    {
      google: [ "http://example.com/google-list.txt" ],
      news: [ "http://example.com/news-list.txt" ],
      shopping: [ "http://example.com/shopping-list.txt" ],
      health_and_fitness: [ "http://example.com/health-list.txt" ]
    }
  end

  def generate_test_blocklist_content
    "0.0.0.0 blocked-domain.com\n0.0.0.0 another-blocked.com"
  end
end
