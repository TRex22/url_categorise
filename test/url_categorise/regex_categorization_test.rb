require 'test_helper'

class UrlCategoriseRegexCategorizationTest < Minitest::Test
  def setup
    WebMock.reset!

    # Create a temporary hosts file for testing
    @temp_hosts_file = 'test_video_hosts.hosts'
    create_test_hosts_file

    # Create a temporary regex patterns file
    @temp_regex_file = 'test_video_patterns.txt'
    create_test_regex_file
  end

  def teardown
    WebMock.reset!
    File.delete(@temp_regex_file) if File.exist?(@temp_regex_file)
    File.delete(@temp_hosts_file) if File.exist?(@temp_hosts_file)
  end

  def test_regex_categorization_disabled_by_default
    client = UrlCategorise::Client.new(host_urls: { video: ["file://#{@temp_hosts_file}"] })

    assert_equal false, client.regex_categorization_enabled
    assert_equal UrlCategorise::Constants::VIDEO_URL_PATTERNS_FILE, client.regex_patterns_file
  end

  def test_regex_categorization_can_be_enabled
    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    assert_equal true, client.regex_categorization_enabled
    assert_equal @temp_regex_file, client.regex_patterns_file
  end

  def test_regex_patterns_loaded_when_file_exists
    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    refute_nil client.regex_patterns
    assert_kind_of Hash, client.regex_patterns
    assert client.regex_patterns.key?('youtube')
  end

  def test_categorization_without_regex
    client = UrlCategorise::Client.new(host_urls: { video: ["file://#{@temp_hosts_file}"] })

    categories = client.categorise('https://youtube.com')
    assert_includes categories, :video
    refute_includes categories, :video_content
  end

  def test_video_url_gets_content_category_with_regex
    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # Test a URL that should match the YouTube video pattern
    categories = client.categorise('https://youtube.com/watch?v=dQw4w9WgXcQ')

    # Should get both the domain-based category and the regex-enhanced category
    assert_includes categories, :video
    assert_includes categories, :video_content
  end

  def test_non_video_url_on_video_domain_without_content_category
    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # Test a URL that's on YouTube but doesn't match the video pattern (e.g., homepage)
    categories = client.categorise('https://youtube.com')

    # Should get the domain-based category but not the content-specific category
    assert_includes categories, :video
    refute_includes categories, :video_content
  end

  def test_regex_categorization_with_invalid_patterns_file
    invalid_file = 'nonexistent_patterns.txt'

    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: invalid_file
    )

    # Should not crash and should still work without regex categorization
    categories = client.categorise('https://youtube.com')
    assert_includes categories, :video
  end

  def test_video_url_method_returns_false_when_regex_disabled
    client = UrlCategorise::Client.new(host_urls: { video: ["file://#{@temp_hosts_file}"] })

    # Even if it's a video URL, should return false when regex categorization is disabled
    result = client.video_url?('https://youtube.com/watch?v=dQw4w9WgXcQ')
    assert_equal false, result
  end

  def test_video_url_method_returns_false_for_non_video_domain
    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # Non-video domain should return false
    result = client.video_url?('https://google.com/search?q=cats')
    assert_equal false, result
  end

  def test_video_url_method_returns_false_for_video_domain_without_video_content
    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # Video domain but non-video URL should return false
    result = client.video_url?('https://youtube.com')
    assert_equal false, result

    result = client.video_url?('https://youtube.com/channel/UCtest')
    assert_equal false, result
  end

  def test_video_url_method_returns_true_for_video_urls
    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # YouTube video URLs should return true
    assert_equal true, client.video_url?('https://youtube.com/watch?v=dQw4w9WgXcQ')
    assert_equal true, client.video_url?('https://www.youtube.com/watch?v=abcd1234')

    # Vimeo video URLs should return true
    assert_equal true, client.video_url?('https://vimeo.com/123456789')
    assert_equal true, client.video_url?('https://www.vimeo.com/987654321')
  end

  def test_video_url_method_with_video_hosting_category
    # Test with video_hosting category instead of video category
    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # Should work with video_hosting category too
    assert_equal true, client.video_url?('https://youtube.com/watch?v=test123')
    assert_equal false, client.video_url?('https://youtube.com')
  end

  def test_video_url_method_handles_invalid_urls_gracefully
    client = UrlCategorise::Client.new(
      host_urls: { video: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # Should not crash on invalid URLs
    assert_equal false, client.video_url?('not-a-url')
    assert_equal false, client.video_url?('')
    assert_equal false, client.video_url?(nil)
  end

  def test_remote_regex_patterns_file_fallback
    # Test that remote file access works (mock the HTTP request)
    remote_patterns_content = create_remote_patterns_content

    stub_request(:get, 'https://example.com/test_patterns.txt')
      .to_return(status: 200, body: remote_patterns_content)

    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: 'https://example.com/test_patterns.txt'
    )

    # Should load patterns from remote URL
    refute_empty client.regex_patterns
    assert_equal true, client.video_url?('https://youtube.com/watch?v=test123')
  end

  def test_remote_regex_patterns_file_failure_fallback
    # Test graceful failure when remote file is not accessible
    stub_request(:get, 'https://example.com/missing_patterns.txt')
      .to_return(status: 404)

    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: 'https://example.com/missing_patterns.txt'
    )

    # Should handle failure gracefully
    assert_empty client.regex_patterns
    assert_equal false, client.video_url?('https://youtube.com/watch?v=test123')
  end

  def test_shorts_url_detection
    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # YouTube Shorts
    assert_equal true, client.shorts_url?('https://youtube.com/shorts/abc123defgh')
    assert_equal true, client.shorts_url?('https://www.youtube.com/shorts/xyz789mnopq')

    # TikTok videos
    assert_equal true, client.shorts_url?('https://tiktok.com/@user/video/123456789')
    assert_equal true, client.shorts_url?('https://www.tiktok.com/@testuser/video/987654321')

    # Regular videos should return false
    assert_equal false, client.shorts_url?('https://youtube.com/watch?v=test123')
    assert_equal false, client.shorts_url?('https://youtube.com')

    # Non-video domains should return false
    assert_equal false, client.shorts_url?('https://google.com')
  end

  def test_playlist_url_detection
    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # YouTube playlists
    assert_equal true, client.playlist_url?('https://youtube.com/playlist?list=PLtest123')
    assert_equal true, client.playlist_url?('https://youtube.com/watch?v=abc123&list=PLtest123')
    assert_equal true, client.playlist_url?('https://www.youtube.com/watch?v=xyz789&t=30s&list=UUtest123')

    # Vimeo albums
    assert_equal true, client.playlist_url?('https://vimeo.com/album/123456')
    assert_equal true, client.playlist_url?('https://www.vimeo.com/showcase/789012')

    # Regular videos should return false
    assert_equal false, client.playlist_url?('https://youtube.com/watch?v=test123')
    assert_equal false, client.playlist_url?('https://youtube.com')

    # Non-video domains should return false
    assert_equal false, client.playlist_url?('https://google.com')
  end

  def test_music_url_detection
    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # YouTube Music
    assert_equal true, client.music_url?('https://music.youtube.com/watch?v=abc123')
    assert_equal true, client.music_url?('https://music.youtube.com/playlist?list=PLtest')

    # YouTube music playlists
    assert_equal true, client.music_url?('https://youtube.com/watch?v=abc123defgh&list=PLmusic123')
    assert_equal true, client.music_url?('https://youtube.com/watch?v=xyz789mnopq&list=RDtest123456789')

    # Music channels/content
    assert_equal true, client.music_url?('https://youtube.com/c/musicchannel')
    assert_equal true, client.music_url?('https://youtube.com/user/musicuser')

    # Regular videos should return false
    assert_equal false, client.music_url?('https://youtube.com/watch?v=test123')
    assert_equal false, client.music_url?('https://youtube.com')

    # Non-video domains should return false
    assert_equal false, client.music_url?('https://google.com')
  end

  def test_channel_url_detection
    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # YouTube channels
    assert_equal true, client.channel_url?('https://youtube.com/@testchannel')
    assert_equal true, client.channel_url?('https://www.youtube.com/c/TestChannel')
    assert_equal true, client.channel_url?('https://youtube.com/channel/UCtest123')
    assert_equal true, client.channel_url?('https://youtube.com/user/testuser')

    # TikTok profiles
    assert_equal true, client.channel_url?('https://tiktok.com/@testuser')
    assert_equal true, client.channel_url?('https://www.tiktok.com/@test.user')

    # Twitch channels
    assert_equal true, client.channel_url?('https://twitch.tv/teststreamer')
    assert_equal true, client.channel_url?('https://www.twitch.tv/test_streamer')

    # Regular videos should return false
    assert_equal false, client.channel_url?('https://youtube.com/watch?v=test123')
    assert_equal false, client.channel_url?('https://youtube.com')

    # Non-video domains should return false
    assert_equal false, client.channel_url?('https://google.com')
  end

  def test_live_stream_url_detection
    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # YouTube live streams
    assert_equal true, client.live_stream_url?('https://youtube.com/watch?v=test123&live=1')
    assert_equal true, client.live_stream_url?('https://youtube.com/live/test123')

    # Twitch streams (channels are typically live)
    assert_equal true, client.live_stream_url?('https://twitch.tv/teststreamer')
    assert_equal true, client.live_stream_url?('https://www.twitch.tv/test_streamer')

    # Generic live patterns
    assert_equal true, client.live_stream_url?('https://youtube.com/watch?v=test123&live_stream=1')

    # Regular videos should return false
    assert_equal false, client.live_stream_url?('https://youtube.com/watch?v=test123')
    assert_equal false, client.live_stream_url?('https://youtube.com')

    # Non-video domains should return false
    assert_equal false, client.live_stream_url?('https://google.com')
  end

  def test_helper_methods_with_disabled_regex_categorization
    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: false
    )

    # All methods should return false when regex categorization is disabled
    assert_equal false, client.shorts_url?('https://youtube.com/shorts/abc123')
    assert_equal false, client.playlist_url?('https://youtube.com/playlist?list=PLtest')
    assert_equal false, client.channel_url?('https://youtube.com/@test')
    assert_equal false, client.live_stream_url?('https://twitch.tv/streamer')

    # Music detection doesn't require regex categorization for dedicated platforms
    # but should still return false for video platform URLs without regex enabled
    assert_equal false, client.music_url?('https://youtube.com/c/music')
  end

  def test_helper_methods_with_invalid_urls
    client = UrlCategorise::Client.new(
      host_urls: { video_hosting: ["file://#{@temp_hosts_file}"] },
      regex_categorization: true,
      regex_patterns_file: @temp_regex_file
    )

    # All methods should handle invalid URLs gracefully
    [nil, '', 'not-a-url', 'ftp://invalid'].each do |invalid_url|
      assert_equal false, client.shorts_url?(invalid_url)
      assert_equal false, client.playlist_url?(invalid_url)
      assert_equal false, client.music_url?(invalid_url)
      assert_equal false, client.channel_url?(invalid_url)
      assert_equal false, client.live_stream_url?(invalid_url)
    end
  end

  private

  def create_test_hosts_file
    File.open(@temp_hosts_file, 'w') do |file|
      file.puts '# Test video hosts file'
      file.puts '0.0.0.0 youtube.com'
      file.puts '0.0.0.0 vimeo.com'
      file.puts '0.0.0.0 tiktok.com'
      file.puts '0.0.0.0 twitch.tv'
      file.puts '0.0.0.0 dailymotion.com'
    end
  end

  def create_test_regex_file
    File.open(@temp_regex_file, 'w') do |file|
      file.puts '# Video URL Detection Patterns'
      file.puts '# Generated for testing'
      file.puts ''
      file.puts '# Source: youtube'
      file.puts '# Description: YouTube video URLs'
      file.puts "# Pattern: https?://(?:www\.)?youtube\.com/watch"
      file.puts 'https?://(?:www\\.)?youtube\\.com/watch'
      file.puts ''
      file.puts '# Source: vimeo'
      file.puts '# Description: Vimeo video URLs'
      file.puts "# Pattern: https?://(?:www\.)?vimeo\.com/\\d+"
      file.puts 'https?://(?:www\\.)?vimeo\\.com/\\d+'
      file.puts ''
    end
  end

  def create_remote_patterns_content
    <<~CONTENT
      # Video URL Detection Patterns
      # Generated for testing remote fetch

      # Source: youtube
      # Description: YouTube video URLs
      # Pattern: https?://(?:www\.)?youtube\.com/watch
      https?://(?:www\\.)?youtube\\.com/watch

      # Source: vimeo#{'  '}
      # Description: Vimeo video URLs
      # Pattern: https?://(?:www\.)?vimeo\.com/\\d+
      https?://(?:www\\.)?vimeo\\.com/\\d+
    CONTENT
  end
end
