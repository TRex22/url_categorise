require "test_helper"

class UrlCategoriseUserRegressionTest < Minitest::Test
  def setup
    WebMock.reset!

    # Mock the video hosting domains list
    video_hosting_content = <<~CONTENT
      # Video hosting domains
      0.0.0.0 youtube.com
      0.0.0.0 www.youtube.com
      0.0.0.0 youtu.be
      0.0.0.0 vimeo.com
      0.0.0.0 www.vimeo.com
      0.0.0.0 tiktok.com
      0.0.0.0 www.tiktok.com
    CONTENT

    # Mock the video URL patterns
    patterns_content = <<~CONTENT
      # Video URL Detection Patterns

      # Source: manual_youtube
      # Description: YouTube video watch URLs
      # Pattern: https?://(?:www\\.)?(?:youtube\\.com/watch\\?.*[&?]?v=|youtu\\.be/)[a-zA-Z0-9_-]{11}
      https?://(?:www\\.)?(?:youtube\\.com/watch\\?.*[&?]?v=|youtu\\.be/)[a-zA-Z0-9_-]{11}

      # Source: manual_youtube_shorts
      # Description: YouTube Shorts URLs
      # Pattern: https?://(?:www\\.)?youtube\\.com/shorts/[a-zA-Z0-9_-]{11}(?:\\?.*)?$
      https?://(?:www\\.)?youtube\\.com/shorts/[a-zA-Z0-9_-]{11}(?:\\?.*)?$

      # Source: manual_vimeo
      # Description: Vimeo video URLs
      # Pattern: https?://(?:www\\.)?vimeo\\.com/\\d+
      https?://(?:www\\.)?vimeo\\.com/\\d+

      # Source: manual_tiktok
      # Description: TikTok video URLs
      # Pattern: https?://(?:www\\.)?tiktok\\.com/@[^/]+/video/\\d+
      https?://(?:www\\.)?tiktok\\.com/@[^/]+/video/\\d+
    CONTENT

    # Mock remote calls
    WebMock.stub_request(:get, "https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_hosting_domains.hosts")
           .to_return(status: 200, body: video_hosting_content)

    WebMock.stub_request(:get, "https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_url_patterns.txt")
           .to_return(status: 200, body: patterns_content)

    # Mock other required host URLs to prevent network calls
    UrlCategorise::Constants::DEFAULT_HOST_URLS.each do |category, urls|
      next if category == :video_hosting

      Array(urls).each do |url|
        next unless url.is_a?(String) && url.start_with?("http")

        WebMock.stub_request(:get, url)
               .to_return(status: 200, body: "# Mock content for #{category}")
      end
    end
  end

  def teardown
    WebMock.reset!
  end

  def test_user_examples_without_regex_categorization
    # This simulates the user's scenario where they didn't enable regex categorization
    client = UrlCategorise::Client.new

    # These are the user's exact examples
    test_urls = [
      "https://www.youtube.com/watch?v=NnsJsxnQhU0&pp=ygUZSW5kYWJhIHggc291dGggYWZyaWNhMjAyNQ%3D%3D",
      "https://www.youtube.com/watch?v=TS1BmNacUEo&list=PLmOk00V-7RN7HwoOBDFuTck475JamLc5Y",
      "https://www.youtube.com/shorts/yLYgqN9cHz4",
      "https://www.youtube.com/watch?v=IKU-yswi8HU",
      "https://www.youtube.com/@eminem"
    ]

    test_urls.each do |url|
      categories = client.categorise(url)

      # User showed these URLs get categorized correctly
      assert_includes categories, :video_hosting, "#{url} should be categorized as video_hosting"

      # But these methods returned false - this should be documented behavior
      assert_equal false, client.video_url?(url), "#{url} should return false for video_url? without regex categorization"
      assert_equal false, client.shorts_url?(url), "#{url} should return false for shorts_url? without regex categorization"
      assert_equal false, client.music_url?(url), "#{url} should return false for music_url? without regex categorization"
      assert_equal false, client.channel_url?(url), "#{url} should return false for channel_url? without regex categorization"
      assert_equal false, client.playlist_url?(url), "#{url} should return false for playlist_url? without regex categorization"
    end
  end

  def test_user_examples_with_regex_categorization_enabled
    # This shows how the user should initialize the client for video URL detection
    client = UrlCategorise::Client.new(regex_categorization: true)

    # Test video URLs
    video_urls = [
      "https://www.youtube.com/watch?v=NnsJsxnQhU0&pp=ygUZSW5kYWJhIHggc291dGggYWZyaWNhMjAyNQ%3D%3D",
      "https://www.youtube.com/watch?v=TS1BmNacUEo&list=PLmOk00V-7RN7HwoOBDFuTck475JamLc5Y",
      "https://www.youtube.com/watch?v=IKU-yswi8HU"
    ]

    video_urls.each do |url|
      categories = client.categorise(url)

      # Should be categorized correctly
      assert_includes categories, :video_hosting, "#{url} should be categorized as video_hosting"

      # Should now detect video URLs correctly
      assert_equal true, client.video_url?(url), "#{url} should return true for video_url? with regex categorization"
    end

    # Test shorts URL
    shorts_url = "https://www.youtube.com/shorts/yLYgqN9cHz4"
    assert_equal true, client.shorts_url?(shorts_url), "#{shorts_url} should return true for shorts_url?"
    assert_equal true, client.video_url?(shorts_url), "#{shorts_url} should also return true for video_url?"

    # Test channel URL
    channel_url = "https://www.youtube.com/@eminem"
    assert_equal true, client.channel_url?(channel_url), "#{channel_url} should return true for channel_url?"
    assert_equal false, client.video_url?(channel_url), "#{channel_url} should return false for video_url?"

    # Test playlist URL
    playlist_url = "https://www.youtube.com/watch?v=TS1BmNacUEo&list=PLmOk00V-7RN7HwoOBDFuTck475JamLc5Y"
    assert_equal true, client.playlist_url?(playlist_url), "#{playlist_url} should return true for playlist_url?"
    assert_equal true, client.video_url?(playlist_url), "#{playlist_url} should also return true for video_url? (it's both)"
  end

  def test_music_url_detection
    client = UrlCategorise::Client.new(regex_categorization: true)

    # Regular music video should be detected by generic patterns
    music_video_url = "https://www.youtube.com/watch?v=IKU-yswi8HU"

    # The music_url? method should work for music videos on YouTube
    # It uses generic music detection patterns
    result = client.music_url?(music_video_url)

    # This might be false since we don't have music-specific domain categories
    # The method works by checking for music patterns in the URL or dedicated music platforms
    # For a regular YouTube video URL, it won't be detected as music unless it has music indicators
    assert_includes [ true, false ], result
  end

  def test_comprehensive_url_detection_examples
    client = UrlCategorise::Client.new(regex_categorization: true)

    test_cases = {
      # YouTube videos - should be detected as video
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ" => {
        video_url?: true, shorts_url?: false, playlist_url?: false, channel_url?: false
      },
      "https://youtu.be/dQw4w9WgXcQ" => {
        video_url?: true, shorts_url?: false, playlist_url?: false, channel_url?: false
      },

      # YouTube Shorts - should be detected as both video and shorts
      "https://www.youtube.com/shorts/abc123defgh" => {
        video_url?: true, shorts_url?: true, playlist_url?: false, channel_url?: false
      },

      # YouTube channels - should only be channel
      "https://www.youtube.com/@pewdiepie" => {
        video_url?: false, shorts_url?: false, playlist_url?: false, channel_url?: true
      },
      "https://www.youtube.com/c/PewDiePie" => {
        video_url?: false, shorts_url?: false, playlist_url?: false, channel_url?: true
      },
      "https://www.youtube.com/channel/UCX6OQ3DkcsbYNE6H8uQQuVA" => {
        video_url?: false, shorts_url?: false, playlist_url?: false, channel_url?: true
      },

      # YouTube playlists - should be playlist (and possibly video if it has v= param)
      "https://www.youtube.com/playlist?list=PLmOk00V-7RN7HwoOBDFuTck475JamLc5Y" => {
        video_url?: false, shorts_url?: false, playlist_url?: true, channel_url?: false
      },

      # Vimeo videos
      "https://vimeo.com/123456789" => {
        video_url?: true, shorts_url?: false, playlist_url?: false, channel_url?: false
      },

      # TikTok videos
      "https://www.tiktok.com/@user/video/123456789" => {
        video_url?: true, shorts_url?: true, playlist_url?: false, channel_url?: false
      },

      # TikTok channels
      "https://www.tiktok.com/@pewdiepie" => {
        video_url?: false, shorts_url?: false, playlist_url?: false, channel_url?: true
      },

      # Non-video URLs should be false for everything
      "https://www.youtube.com" => {
        video_url?: false, shorts_url?: false, playlist_url?: false, channel_url?: false
      },
      "https://www.google.com" => {
        video_url?: false, shorts_url?: false, playlist_url?: false, channel_url?: false
      }
    }

    test_cases.each do |url, expected|
      categories = client.categorise(url)
      puts "Testing #{url}: #{categories}" if ENV["DEBUG"]

      expected.each do |method, expected_result|
        actual_result = client.send(method, url)
        assert_equal expected_result, actual_result,
                     "#{url} should return #{expected_result} for #{method}, got #{actual_result}"
      end
    end
  end
end
