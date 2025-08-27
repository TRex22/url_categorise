# Video URL Detection Feature

## Overview

The UrlCategorise gem now includes advanced video URL detection capabilities that allow you to determine if a URL is a direct link to video content, rather than just a homepage, profile page, or other non-video resource on a video hosting domain.

## Key Features

### 🎬 Direct Video URL Detection

New `video_url?` method provides precise detection of video content URLs:

```ruby
client = UrlCategorise::Client.new(regex_categorization: true)

# Direct video content URLs return true
client.video_url?("https://youtube.com/watch?v=dQw4w9WgXcQ")  # => true
client.video_url?("https://vimeo.com/123456789")            # => true
client.video_url?("https://tiktok.com/@user/video/123")     # => true
client.video_url?("https://dailymotion.com/video/x7abc123") # => true

# Non-video URLs return false
client.video_url?("https://youtube.com")                    # => false
client.video_url?("https://youtube.com/@channel")           # => false
client.video_url?("https://google.com/search?q=cats")       # => false
```

### 📡 Comprehensive Video Hosting Lists

- **3,500+ video hosting domains** extracted from yt-dlp (YouTube-dl fork) extractors
- **50+ regex patterns** for identifying video content URLs
- **Automatic generation** using `bin/generate_video_lists` script
- **Remote list fetching** from GitHub repository

### 🔗 Remote Pattern Files

Video patterns are automatically fetched from remote GitHub repository:

- **Video domains**: `https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_hosting_domains.hosts`
- **URL patterns**: `https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_url_patterns.txt`

### 🧠 Enhanced Categorization

Regex categorization provides more specific categorization for video URLs:

```ruby
client = UrlCategorise::Client.new(regex_categorization: true)

# Basic domain categorization
client.categorise('https://youtube.com') # => [:video_hosting]

# Enhanced content detection for actual video URLs
client.categorise('https://youtube.com/watch?v=abc123') # => [:video_hosting, :video_hosting_content]
```

## Technical Implementation

### Constants Updates

New constants in `UrlCategorise::Constants`:

```ruby
# Remote video URL patterns file
VIDEO_URL_PATTERNS_FILE = 'https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_url_patterns.txt'.freeze

# Updated video hosting category to use remote list
video_hosting: ['https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_hosting_domains.hosts']
```

### Client Enhancements

New `Client` class features:

```ruby
# Default regex patterns file now uses remote URL
attribute :regex_patterns_file, default: -> { VIDEO_URL_PATTERNS_FILE }

# New video URL detection method
def video_url?(url)
  # 1. Check if URL is valid and not empty
  # 2. Ensure regex categorization is enabled
  # 3. Verify URL is from a video hosting domain
  # 4. Check if URL matches video content patterns
  # 5. Return true only if all conditions are met
end

# Enhanced pattern fetching supports remote URLs
def fetch_regex_patterns_content
  # Supports HTTP/HTTPS, file://, and direct file paths
  # Graceful error handling for network failures
end
```

### Pattern Generation

The `bin/generate_video_lists` script has been enhanced:

- **Fixed terminal output** - Clean progress display without character overlap
- **Suppressed regex warnings** - No more nested operator warnings
- **Improved domain extraction** - More comprehensive pattern matching
- **Manual high-priority patterns** - Curated YouTube, Vimeo, TikTok patterns
- **3,500+ domains extracted** - Up from 96 domains previously

## Usage Examples

### Basic Video URL Detection

```ruby
require 'url_categorise'

# Initialize client with regex categorization
client = UrlCategorise::Client.new(regex_categorization: true)

# Test various video URLs
urls = [
  'https://youtube.com/watch?v=dQw4w9WgXcQ',  # YouTube video
  'https://youtube.com',                      # YouTube homepage
  'https://youtube.com/@pewdiepie',           # YouTube channel
  'https://vimeo.com/123456789',             # Vimeo video
  'https://tiktok.com/@user/video/123',      # TikTok video
  'https://google.com/search?q=cats'         # Non-video site
]

urls.each do |url|
  is_video = client.video_url?(url)
  categories = client.categorise(url)
  puts "#{url} -> video: #{is_video}, categories: #{categories}"
end
```

### Content Filtering Application

```ruby
class ContentFilter
  def initialize
    @client = UrlCategorise::Client.new(regex_categorization: true)
  end

  def filter_video_content(urls)
    results = {
      video_content: [],
      video_sites: [],
      other: []
    }

    urls.each do |url|
      if @client.video_url?(url)
        results[:video_content] << url
      elsif @client.categorise(url).include?(:video_hosting)
        results[:video_sites] << url
      else
        results[:other] << url
      end
    end

    results
  end
end

# Usage
filter = ContentFilter.new
results = filter.filter_video_content([
  'https://youtube.com/watch?v=abc',   # -> :video_content
  'https://youtube.com/@channel',      # -> :video_sites
  'https://example.com'                # -> :other
])
```

### Rails Integration

```ruby
# app/services/video_url_service.rb
class VideoUrlService
  include Singleton

  def initialize
    @client = UrlCategorise::Client.new(
      regex_categorization: true,
      cache_dir: Rails.root.join('tmp', 'url_cache')
    )
  end

  def video_content?(url)
    Rails.cache.fetch("video_content_#{Digest::MD5.hexdigest(url)}", expires_in: 1.hour) do
      @client.video_url?(url)
    end
  end

  def categorize_video_url(url)
    categories = @client.categorise(url)
    is_video_content = @client.video_url?(url)
    
    {
      url: url,
      categories: categories,
      is_video_content: is_video_content,
      risk_level: calculate_risk_level(categories)
    }
  end

  private

  def calculate_risk_level(categories)
    return 'safe' if categories.empty?
    return 'blocked' if (categories & [:malware, :phishing]).any?
    return 'restricted' if (categories & [:pornography, :gambling]).any?
    'allowed'
  end
end

# Usage in controllers
class VideosController < ApplicationController
  def check
    url = params[:url]
    result = VideoUrlService.instance.categorize_video_url(url)
    render json: result
  end
end
```

## Testing

Comprehensive test suite with 15 new tests covering:

### Core Functionality Tests

- Video URL detection when regex categorization is disabled/enabled
- Detection of video vs non-video domains  
- Video content URLs vs homepage/profile URLs
- Multiple video hosting categories (`video`, `video_hosting`, etc.)
- Graceful handling of invalid URLs

### Network and Error Handling Tests

- Remote pattern file fetching with mocked HTTP requests
- Graceful failure when remote files are not accessible
- Timeout and network error handling
- Invalid regex pattern handling

### Test Results

- ✅ **383 tests, 2,729 assertions, 0 failures, 0 errors**
- ✅ **92.88% line coverage** (926/997 lines)
- ✅ All video URL detection functionality fully tested

## Performance Considerations

### Caching

- Pattern files are cached locally when `cache_dir` is specified
- Remote patterns are only fetched once per session
- Client-side caching recommended for high-traffic applications

### Memory Usage

- Regex patterns are compiled once during client initialization
- Minimal memory overhead for video URL detection
- Efficient Set-based domain lookups

### Network Optimization

- Remote pattern files are small (~50KB total)
- Graceful fallback to local files if remote fetch fails
- HTTP timeout configuration supported

## Migration Guide

### From Previous Versions

No breaking changes - video URL detection is entirely optional:

```ruby
# Existing code continues to work unchanged
client = UrlCategorise::Client.new
categories = client.categorise('youtube.com')

# Enable video URL detection when needed
client_with_video = UrlCategorise::Client.new(regex_categorization: true)
is_video = client_with_video.video_url?('https://youtube.com/watch?v=abc')
```

### Enabling Video Detection

To use video URL detection in existing applications:

1. **Enable regex categorization**: `regex_categorization: true`
2. **Use the new method**: `client.video_url?(url)`
3. **Optional configuration**: Custom pattern files, caching

### Configuration Options

```ruby
# Default configuration (recommended)
client = UrlCategorise::Client.new(regex_categorization: true)

# Custom pattern file (local)
client = UrlCategorise::Client.new(
  regex_categorization: true,
  regex_patterns_file: 'path/to/custom/patterns.txt'
)

# Custom pattern file (remote)
client = UrlCategorise::Client.new(
  regex_categorization: true,
  regex_patterns_file: 'https://example.com/patterns.txt'
)

# With caching
client = UrlCategorise::Client.new(
  regex_categorization: true,
  cache_dir: './cache'
)
```

## Maintenance

### Updating Video Lists

The video hosting lists are automatically maintained in the GitHub repository. To generate updated lists locally:

```bash
# Generate fresh video hosting lists
ruby bin/generate_video_lists

# This creates/updates:
# - lists/video_hosting_domains.hosts (3,500+ domains)
# - lists/video_url_patterns.txt (50+ patterns)
```

### Manual Pattern Curation

High-priority patterns are manually curated in the generation script:

- YouTube video and Shorts URLs
- Vimeo video URLs  
- Dailymotion video URLs
- Twitch video URLs
- TikTok video URLs

### List Health Monitoring

Use the existing health monitoring for video hosting lists:

```ruby
client = UrlCategorise::Client.new
report = client.check_all_lists

# Check video hosting category specifically
video_status = report[:successful_lists][:video_hosting]
puts "Video hosting lists: #{video_status&.length || 0} URLs working"
```

This feature provides enterprise-grade video URL detection while maintaining the gem's focus on performance, reliability, and ease of use.