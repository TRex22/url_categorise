# UrlCategorise

A comprehensive Ruby gem for categorizing URLs and domains based on various security and content blocklists. It downloads and processes multiple types of lists to provide domain categorization across many categories including malware, phishing, advertising, tracking, gambling, and more.

## Features

- **Comprehensive Coverage**: 60+ high-quality categories including security, content, and specialized lists
- **Video Content Detection**: Advanced regex-based categorization with `video_url?` method to distinguish video content from other website resources
- **Custom Video Lists**: Generate and maintain comprehensive video hosting domain lists using yt-dlp extractors
- **Kaggle Dataset Integration**: Automatic loading and processing of machine learning datasets from Kaggle
- **Multiple Data Sources**: Supports blocklists, CSV datasets, and Kaggle ML datasets  
- **Multiple List Formats**: Supports hosts files, pfSense, AdSense, uBlock Origin, dnsmasq, and plain text formats
- **Intelligent Caching**: Hash-based file update detection with configurable local cache
- **DNS Resolution**: Resolve domains to IPs and check against IP-based blocklists  
- **High-Quality Sources**: Integrates lists from HaGeZi, StevenBlack, The Block List Project, and specialized security feeds
- **ActiveRecord Integration**: Optional database storage for high-performance lookups
- **IP Categorization**: Support for IP address and subnet-based categorization
- **Metadata Tracking**: Track last update times, ETags, and content hashes
- **Health Monitoring**: Automatic detection and removal of broken blocklist sources
- **List Validation**: Built-in tools to verify all configured URLs are accessible
- **Auto-Loading Datasets**: Automatic processing of predefined datasets during client initialization
- **ActiveAttr Settings**: In-memory modification of client settings using attribute setters
- **Data Export**: Export categorized data as hosts files per category or comprehensive CSV exports
- **CLI Commands**: Command-line utilities for data export and list checking

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'url_categorise'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install url_categorise

## Basic Usage

```ruby
require 'url_categorise'

# Initialize with default lists (60+ categories)
client = UrlCategorise::Client.new

# Get basic statistics
puts "Total hosts: #{client.count_of_hosts}"
puts "Categories: #{client.count_of_categories}"  
puts "Data size: #{client.size_of_data} MB"

# Get detailed size breakdown
puts "Total data size: #{client.size_of_data} MB (#{client.size_of_data_bytes} bytes)"
puts "Blocklist data size: #{client.size_of_blocklist_data} MB (#{client.size_of_blocklist_data_bytes} bytes)"
puts "Dataset data size: #{client.size_of_dataset_data} MB (#{client.size_of_dataset_data_bytes} bytes)"

# Get dataset-specific statistics (if datasets are loaded)
puts "Dataset hosts: #{client.count_of_dataset_hosts}"
puts "Dataset categories: #{client.count_of_dataset_categories}"

# Categorize a URL or domain
categories = client.categorise("badsite.com")
puts "Categories: #{categories}" # => [:malware, :phishing]

# Check if domain resolves to suspicious IPs
categories = client.resolve_and_categorise("suspicious-domain.com")
puts "Domain + IP categories: #{categories}"

# Categorize an IP address directly
ip_categories = client.categorise_ip("192.168.1.100") 
puts "IP categories: #{ip_categories}"
```

## New Features

### Dynamic Settings with ActiveAttr

The Client class now supports in-memory modification of settings using ActiveAttr:

```ruby
client = UrlCategorise::Client.new

# Modify settings dynamically
client.smart_categorization_enabled = true
client.iab_compliance_enabled = true
client.iab_version = :v2
client.request_timeout = 30
client.dns_servers = ['8.8.8.8', '8.8.4.4']

# Settings take effect immediately - no need to recreate the client
categories = client.categorise('reddit.com') # Uses new smart categorization rules
```

### Data Export Features

#### Hosts File Export

Export all categorized domains as separate hosts files per category:

```ruby
# Export to default location
result = client.export_hosts_files

# Export to custom location
result = client.export_hosts_files('/custom/export/path')

# Result includes file information and summary
puts "Exported #{result[:_summary][:total_categories]} categories"
puts "Total domains: #{result[:_summary][:total_domains]}"
puts "Files saved to: #{result[:_summary][:export_directory]}"
```

Each category gets its own hosts file (e.g., `malware.hosts`, `advertising.hosts`) with proper headers and sorted domains.

#### CSV Data Export

Export all data as a single comprehensive CSV file for AI training and analysis:

```ruby
# Export to default location
result = client.export_csv_data

# Export to custom location with IAB compliance
client.iab_compliance_enabled = true
result = client.export_csv_data('/custom/export/path')

# Returns information about created files:
# {
#   csv_file: '/path/url_categorise_comprehensive_export_20231201_143022.csv',
#   summary_file: '/path/export_summary_20231201_143022.json',
#   total_entries: 50000,
#   summary: { ... },
#   export_directory: '/path'
# }
```

**Single comprehensive CSV file contains:**

- **Domain Categorization Data**: All processed domains with categories, source types, IAB mappings
- **Raw Dataset Content**: Original dataset entries with titles, descriptions, text, summaries, and all available fields
- **Dynamic Headers**: Automatically adapts to include all available data fields
- **Data Type Column**: Distinguishes between 'domain_categorization', 'raw_dataset_content', etc.

**Key Features:**
- Everything in one file for easy analysis and AI/ML training
- Rich textual content from original datasets
- IAB Content Taxonomy compliance mapping
- Smart categorization metadata
- Source type tracking (dataset vs blocklist)

#### CLI Commands

Command-line utilities for data export:

```bash
# Export hosts files
$ bundle exec export_hosts --output /tmp/hosts --verbose

# Export CSV data with all features enabled
$ bundle exec export_csv --output /tmp/csv --iab-compliance --smart-categorization --auto-load-datasets --verbose

# Generate updated video hosting lists
$ ruby bin/generate_video_lists

# Check health of all blocklist URLs
$ bundle exec check_lists

# Export with custom Kaggle credentials
$ bundle exec export_csv --auto-load-datasets --kaggle-credentials ~/my-kaggle.json --verbose

# Basic export (domains only)
$ bundle exec export_csv --output /tmp/csv

# Check URL health (existing command)
$ bundle exec check_lists
```

**Key CLI Options:**
- `--auto-load-datasets`: Load datasets from constants to include rich text content
- `--kaggle-credentials FILE`: Specify custom Kaggle credentials file
- `--iab-compliance`: Enable IAB Content Taxonomy mapping
- `--smart-categorization`: Enable intelligent category filtering

## Advanced Configuration

### File Caching

Enable local file caching to improve performance and reduce bandwidth:

```ruby
# Cache files locally and check for updates
client = UrlCategorise::Client.new(
  cache_dir: "./url_cache",
  force_download: false  # Use cache when available
)

# Force fresh download ignoring cache
client = UrlCategorise::Client.new(
  cache_dir: "./url_cache", 
  force_download: true
)
```

### Custom DNS Servers

Configure custom DNS servers for domain resolution:

```ruby
client = UrlCategorise::Client.new(
  dns_servers: ['8.8.8.8', '8.8.4.4']  # Default: ['1.1.1.1', '1.0.0.1']
)
```

### Request Timeout Configuration

Configure HTTP request timeout for downloading blocklists:

```ruby
# Default timeout is 10 seconds
client = UrlCategorise::Client.new(
  request_timeout: 30  # 30 second timeout for slow networks
)

# For faster networks or when you want quick failures
client = UrlCategorise::Client.new(
  request_timeout: 5   # 5 second timeout
)
```

### Complete Configuration Example

Here's a comprehensive example with all available options:

```ruby
client = UrlCategorise::Client.new(
  host_urls: UrlCategorise::Constants::DEFAULT_HOST_URLS,  # Use default or custom lists
  cache_dir: "./url_cache",                                # Enable local caching
  force_download: false,                                   # Use cache when available
  dns_servers: ['1.1.1.1', '1.0.0.1'],                   # Cloudflare DNS servers
  request_timeout: 15,                                     # 15 second HTTP timeout
  iab_compliance: true,                                    # Enable IAB compliance
  iab_version: :v3,                                        # Use IAB Content Taxonomy v3.0
  auto_load_datasets: false,                               # Disable automatic dataset loading (default)
  smart_categorization: false                              # Disable smart post-processing (default)
)
```

### Custom Lists

Use your own curated lists or subset of categories:

```ruby
# Custom host list configuration
host_urls = {
  malware: ["https://example.com/malware-domains.txt"],
  phishing: ["https://example.com/phishing-domains.txt"],
  combined_bad: [:malware, :phishing]  # Combine categories
}

client = UrlCategorise::Client.new(host_urls: host_urls)
```

### Video Content Detection

The gem includes advanced regex-based categorization specifically for video hosting platforms. This helps distinguish between actual video content URLs and other resources like homepages, user profiles, playlists, or community content.

#### Video Hosting Domains

The gem maintains a comprehensive list of video hosting domains extracted from yt-dlp (YouTube-dl fork) extractors:

```ruby
# Generate/update video hosting lists
system("ruby bin/generate_video_lists")

# Use video hosting categorization
client = UrlCategorise::Client.new
categories = client.categorise("youtube.com")
# => [:video_hosting]
```

#### Video Content vs Other Resources

Enable regex categorization to distinguish video content from other resources:

```ruby
client = UrlCategorise::Client.new(
  regex_categorization: true  # Uses remote video patterns by default
)

# Regular homepage gets basic category
client.categorise("https://youtube.com")
# => [:video_hosting]

# Actual video URL gets enhanced categorization
client.categorise("https://youtube.com/watch?v=dQw4w9WgXcQ") 
# => [:video_hosting, :video_hosting_content]

# User profile page - no content enhancement
client.categorise("https://youtube.com/@username")
# => [:video_hosting]
```

#### Direct Video URL Detection

Use the `video_url?` method to check if a URL is a direct link to video content:

```ruby
client = UrlCategorise::Client.new(regex_categorization: true)

# Check if URLs are direct video content links
client.video_url?("https://youtube.com/watch?v=dQw4w9WgXcQ")  # => true
client.video_url?("https://youtube.com")                     # => false
client.video_url?("https://youtube.com/@channel")            # => false
client.video_url?("https://vimeo.com/123456789")            # => true
client.video_url?("https://tiktok.com/@user/video/123")     # => true

# Works with various video hosting platforms
client.video_url?("https://dailymotion.com/video/x7abc123") # => true
client.video_url?("https://twitch.tv/videos/1234567890")    # => true

# Returns false for non-video domains
client.video_url?("https://google.com/search?q=cats")       # => false
```

**How it works:**
1. First checks if the URL is from a known video hosting domain
2. Then uses regex patterns to determine if it's a direct video content URL
3. Returns `true` only if both conditions are met
4. Handles invalid URLs gracefully (returns `false`)

#### Additional Video URL Helper Methods

The gem provides specialized helper methods for different types of video content:

```ruby
client = UrlCategorise::Client.new(regex_categorization: true)

# Detect short-form video content
client.shorts_url?("https://youtube.com/shorts/abc123defgh")     # => true
client.shorts_url?("https://tiktok.com/@user/video/123456789")  # => true
client.shorts_url?("https://youtube.com/watch?v=test123")       # => false

# Detect playlist URLs
client.playlist_url?("https://youtube.com/playlist?list=PLtest123")        # => true
client.playlist_url?("https://youtube.com/watch?v=abc123&list=PLtest123")  # => true
client.playlist_url?("https://vimeo.com/album/123456")                     # => true
client.playlist_url?("https://youtube.com/watch?v=test123")                # => false

# Detect music content (works with video platforms hosting music)
client.music_url?("https://music.youtube.com/watch?v=abc123")              # => true
client.music_url?("https://youtube.com/watch?v=abc123defgh&list=PLmusic")  # => true
client.music_url?("https://youtube.com/c/musicchannel")                    # => true
client.music_url?("https://youtube.com/watch?v=regularvideo")              # => false

# Detect channel/profile URLs
client.channel_url?("https://youtube.com/@channelname")       # => true
client.channel_url?("https://tiktok.com/@username")           # => true
client.channel_url?("https://twitch.tv/streamername")         # => true
client.channel_url?("https://youtube.com/watch?v=test123")    # => false

# Detect live stream URLs
client.live_stream_url?("https://youtube.com/live/streamid")      # => true
client.live_stream_url?("https://twitch.tv/streamername")         # => true
client.live_stream_url?("https://youtube.com/watch?v=test123")    # => false
```

**All helper methods:**
- Require `regex_categorization: true` to be enabled
- First verify the URL is from a video hosting domain
- Use specific regex patterns for accurate detection
- Handle invalid URLs gracefully (return `false`)
- Work across multiple video platforms (YouTube, TikTok, Vimeo, Twitch, etc.)

#### Maintaining Video Lists

The gem includes a script to generate and maintain comprehensive video hosting lists:

```bash
# Generate updated video hosting lists
ruby bin/generate_video_lists

# This creates:
# - lists/video_hosting_domains.hosts (PiHole compatible)  
# - lists/video_url_patterns.txt (Regex patterns for content detection)
```

The script fetches data from yt-dlp extractors and combines it with manually curated major platforms to ensure comprehensive coverage.

### Smart Categorization (Post-Processing)

Smart categorization solves the problem of overly broad domain-level categorization. For example, `reddit.com` might appear in health & fitness blocklists, but not all Reddit content is health-related.

#### The Problem

```ruby
# Without smart categorization
client.categorise("reddit.com")
# => [:reddit, :social_media, :health_and_fitness, :forums]  # Too broad!

client.categorise("reddit.com/r/technology") 
# => [:reddit, :social_media, :health_and_fitness, :forums]  # Still wrong!
```

#### The Solution

```ruby
# Enable smart categorization
client = UrlCategorise::Client.new(
  smart_categorization: true  # Remove overly broad categories
)

client.categorise("reddit.com")
# => [:reddit, :social_media]  # Much more accurate!
```

#### How It Works

Smart categorization automatically removes overly broad categories for known platforms:

- **Social Media Platforms** (Reddit, Facebook, Twitter, etc.): Removes categories like `:health_and_fitness`, `:forums`, `:news`, `:technology`, `:education`
- **Search Engines** (Google, Bing, etc.): Removes categories like `:news`, `:shopping`, `:travel`
- **Video Platforms** (YouTube, Vimeo, etc.): Removes categories like `:education`, `:entertainment`, `:music`

#### Custom Smart Rules

You can define custom rules for specific domains or URL patterns:

```ruby
custom_rules = {
  reddit_subreddits: {
    domains: ['reddit.com'],
    remove_categories: [:health_and_fitness, :forums],
    add_categories_by_path: {
      /\/r\/fitness/ => [:health_and_fitness],      # Add back for /r/fitness
      /\/r\/technology/ => [:technology],           # Add technology for /r/technology 
      /\/r\/programming/ => [:technology, :programming]
    }
  },
  my_company_domains: {
    domains: ['mycompany.com'],
    allowed_categories_only: [:business, :technology]  # Only allow specific categories
  }
}

client = UrlCategorise::Client.new(
  smart_categorization: true,
  smart_rules: custom_rules
)

# Now path-based categorization works
client.categorise('reddit.com')           # => [:reddit, :social_media]
client.categorise('reddit.com/r/fitness') # => [:reddit, :social_media, :health_and_fitness]
client.categorise('reddit.com/r/technology') # => [:reddit, :social_media, :technology]
```

#### Available Rule Types

- **`remove_categories`**: Remove specific categories for domains
- **`keep_primary_only`**: Keep only specified categories, remove others
- **`allowed_categories_only`**: Only allow specific categories, block all others
- **`add_categories_by_path`**: Add categories based on URL path patterns

#### Smart Rules with IAB Compliance

Smart categorization works seamlessly with IAB compliance:

```ruby
client = UrlCategorise::Client.new(
  smart_categorization: true,
  iab_compliance: true,
  iab_version: :v3
)

# Returns clean IAB codes after smart processing
categories = client.categorise("reddit.com")  # => ["14"] (Society - Social Media)
```

## IAB Content Taxonomy Compliance

UrlCategorise supports IAB (Interactive Advertising Bureau) Content Taxonomy compliance for standardized content categorization:

### Basic IAB Compliance

```ruby
# Enable IAB v3.0 compliance (default)
client = UrlCategorise::Client.new(
  iab_compliance: true,
  iab_version: :v3
)

# Enable IAB v2.0 compliance
client = UrlCategorise::Client.new(
  iab_compliance: true,
  iab_version: :v2
)

# Categorization returns IAB codes instead of custom categories
categories = client.categorise("badsite.com")
puts categories # => ["626"] (IAB v3 code for illegal content)

# Check IAB compliance status
puts client.iab_compliant? # => true

# Get IAB mapping for a specific category
puts client.get_iab_mapping(:malware) # => "626" (v3) or "IAB25" (v2)
```

### IAB Category Mappings

The gem maps security and content categories to appropriate IAB codes:

**IAB Content Taxonomy v3.0 (recommended):**
- `malware`, `phishing`, `illegal` → `626` (Illegal Content)
- `advertising`, `mobile_ads` → `3` (Advertising)
- `gambling` → `7-39` (Gambling)
- `pornography` → `626` (Adult Content)
- `social_media` → `14` (Society)
- `technology` → `19` (Technology & Computing)

**IAB Content Taxonomy v2.0:**
- `malware`, `phishing` → `IAB25` (Non-Standard Content)
- `advertising` → `IAB3` (Advertising)
- `gambling` → `IAB7-39` (Gambling)
- `pornography` → `IAB25-3` (Pornography)

### Integration with Datasets

IAB compliance works seamlessly with dataset processing:

```ruby
client = UrlCategorise::Client.new(
  iab_compliance: true,
  iab_version: :v3,
  dataset_config: {
    kaggle: { username: 'user', api_key: 'key' }
  },
  auto_load_datasets: true  # Automatically load predefined datasets with IAB mapping
)

# Load additional datasets - categories will be mapped to IAB codes
client.load_kaggle_dataset('owner', 'dataset-name')
client.load_csv_dataset('https://example.com/data.csv')

# All categorization methods return IAB codes
categories = client.categorise("example.com") # => ["3", "626"]
```

## Available Categories

### Security & Threat Intelligence
- **malware**, **phishing**, **threat_indicators** - Core security threats
- **cryptojacking**, **phishing_extended** - Advanced security categories  
- **threat_intelligence** - HaGeZi threat intelligence feeds
- **sanctions_ips**, **compromised_ips**, **tor_exit_nodes**, **open_proxy_ips** - IP-based security lists

### Content Filtering  
- **advertising**, **tracking**, **gambling**, **pornography** - Content categories
- **social_media**, **gaming**, **dating_services** - Platform-specific lists
- **hate_and_junk**, **fraud**, **scam**, **redirect** - Unwanted content

### Network Security
- **top_attack_sources**, **suspicious_domains** - Network threat feeds
- **dns_over_https_bypass** - DNS-over-HTTPS and VPN bypass detection
- **dyndns**, **badware_hoster** - Infrastructure-based threats

### Corporate & Platform Lists
- **google**, **facebook**, **microsoft**, **apple** - Major tech platforms
- **youtube**, **tiktok**, **twitter**, **instagram** - Social media platforms
- **amazon**, **adobe**, **cloudflare** - Service providers

### Specialized & Regional
- **newly_registered_domains** - Recently registered domains (high risk)
- **most_abused_tlds** - Most abused top-level domains
- **chinese_ad_hosts**, **korean_ad_hosts** - Regional advertising
- **mobile_ads**, **smart_tv_ads** - Device-specific advertising
- **news**, **fakenews** - News and misinformation

### Content Categories
- **piracy**, **torrent**, **drugs**, **vaping** - Restricted content
- **crypto**, **nsa** - Specialized blocking lists

## Health Monitoring

The gem includes built-in health monitoring to ensure all blocklist sources remain accessible:

```ruby
# Check health of all configured lists
client = UrlCategorise::Client.new
health_report = client.check_all_lists

puts "Healthy categories: #{health_report[:summary][:healthy_categories]}"
puts "Categories with issues: #{health_report[:summary][:categories_with_issues]}"

# View detailed issues
health_report[:unreachable_lists].each do |category, failures|
  puts "#{category}: #{failures.map { |f| f[:error] }.join(', ')}"
end
```

Use the included script to check all URLs:
```bash
# Check all URLs in constants
ruby bin/check_lists
```

[View all 60+ categories in constants.rb](lib/url_categorise/constants.rb)

## Dataset Processing

UrlCategorise supports processing external datasets from Kaggle and CSV files to expand categorization data beyond traditional blocklists. This allows integration of machine learning datasets and custom URL classification data:

### Automatic Dataset Loading

Enable automatic loading of predefined datasets during client initialization:

```ruby
# Enable automatic dataset loading from constants
client = UrlCategorise::Client.new(
  dataset_config: {
    kaggle: {
      username: ENV['KAGGLE_USERNAME'], 
      api_key: ENV['KAGGLE_API_KEY']
    },
    cache_path: './dataset_cache',
    download_path: './downloads'
  },
  auto_load_datasets: true  # Automatically loads all predefined datasets
)

# Datasets are now automatically integrated and ready for use
categories = client.categorise('https://example.com')
puts "Dataset categories loaded: #{client.count_of_dataset_categories}"
puts "Dataset hosts: #{client.count_of_dataset_hosts}"
```

The gem includes predefined high-quality datasets in constants:
- **`shaurov/website-classification-using-url`** - Comprehensive URL classification dataset
- **`hetulmehta/website-classification`** - Website categorization with cleaned text data  
- **`shawon10/url-classification-dataset-dmoz`** - DMOZ-based URL classification
- **Data.world CSV dataset** - Additional URL categorization data

### Manual Dataset Loading

You can also load datasets manually for more control over the process:

#### Kaggle Dataset Integration

Load datasets directly from Kaggle using three authentication methods:

```ruby
# Method 1: Environment variables (KAGGLE_USERNAME, KAGGLE_KEY)
client = UrlCategorise::Client.new(
  dataset_config: {
    kaggle: {}  # Will use environment variables
  }
)

# Method 2: Explicit credentials
client = UrlCategorise::Client.new(
  dataset_config: {
    kaggle: {
      username: 'your_username',
      api_key: 'your_api_key'
    }
  }
)

# Method 3: Credentials file (~/.kaggle/kaggle.json or custom path)
client = UrlCategorise::Client.new(
  dataset_config: {
    kaggle: {
      credentials_file: '/path/to/kaggle.json'
    }
  }
)

# Load and integrate a Kaggle dataset
client.load_kaggle_dataset('owner', 'dataset-name', {
  use_cache: true,  # Cache processed data
  category_mappings: {
    url_column: 'website',      # Column containing URLs/domains
    category_column: 'type',    # Column containing categories
    category_map: {
      'malicious' => 'malware', # Map dataset categories to your categories
      'spam' => 'phishing'
    }
  }
})

# Check categorization with dataset data
categories = client.categorise('https://example.com')
```

#### CSV Dataset Processing

Load datasets from direct CSV URLs:

```ruby
client = UrlCategorise::Client.new(
  dataset_config: {
    download_path: './datasets',
    cache_path: './dataset_cache'
  }
)

# Load CSV dataset
client.load_csv_dataset('https://example.com/url-classification.csv', {
  use_cache: true,
  category_mappings: {
    url_column: 'url',
    category_column: 'category'
  }
})
```

### Dataset Configuration Options

```ruby
dataset_config = {
  # Kaggle functionality control
  enable_kaggle: true,              # Set to false to disable Kaggle entirely (default: true)
  
  # Kaggle authentication (optional - will try env vars and default file)
  kaggle: {
    username: 'kaggle_username',     # Or use KAGGLE_USERNAME env var
    api_key: 'kaggle_api_key',       # Or use KAGGLE_KEY env var
    credentials_file: '~/.kaggle/kaggle.json'  # Optional custom path
  },
  
  # File paths
  download_path: './downloads',      # Where to store downloads
  cache_path: './cache',            # Where to cache processed data
  timeout: 30                       # HTTP timeout for downloads
}

client = UrlCategorise::Client.new(
  dataset_config: dataset_config,
  auto_load_datasets: true          # Enable automatic loading of predefined datasets
)
```

### Disabling Kaggle Functionality

You can completely disable Kaggle functionality if you only need CSV processing:

```ruby
# Disable Kaggle - only CSV datasets will work
client = UrlCategorise::Client.new(
  dataset_config: {
    enable_kaggle: false,
    download_path: './datasets',
    cache_path: './dataset_cache'
  }
)

# This will raise an error
# client.load_kaggle_dataset('owner', 'dataset')  # Error!

# But CSV datasets still work
client.load_csv_dataset('https://example.com/data.csv')
```

### Working with Cached Datasets

If you have cached datasets, you can access them even without Kaggle credentials:

```ruby
# No credentials provided, but cached data will work
client = UrlCategorise::Client.new(
  dataset_config: {
    kaggle: {},  # Empty config - will show warning but continue
    download_path: './datasets',
    cache_path: './cache'
  }
)

# Will work if data is cached, otherwise will show helpful error message
client.load_kaggle_dataset('owner', 'dataset', use_cache: true)
```

### Dataset Metadata and Hashing

The system automatically tracks dataset metadata and generates content hashes:

```ruby
# Get dataset metadata
metadata = client.dataset_metadata
metadata.each do |data_hash, meta|
  puts "Dataset hash: #{data_hash}"
  puts "Processed at: #{meta[:processed_at]}"
  puts "Total entries: #{meta[:total_entries]}"
end

# Reload client with fresh dataset integration
client.reload_with_datasets
```

## ActiveRecord Integration

For high-performance applications, enable database storage:

```ruby
# Add to Gemfile
gem 'activerecord'
gem 'sqlite3'  # or your preferred database

# Generate migration
puts UrlCategorise::Models.generate_migration

# Use ActiveRecord client (automatically populates database)
client = UrlCategorise::ActiveRecordClient.new(
  cache_dir: "./cache",
  use_database: true
)

# Database-backed lookups (much faster for repeated queries)
categories = client.categorise("example.com")

# Get database statistics  
stats = client.database_stats
# => { domains: 50000, ip_addresses: 15000, categories: 45, list_metadata: 90, dataset_metadata: 5 }

# Direct model access
domain_record = UrlCategorise::Models::Domain.find_by(domain: "example.com")
ip_record = UrlCategorise::Models::IpAddress.find_by(ip_address: "1.2.3.4")

# Dataset integration with ActiveRecord
client = UrlCategorise::ActiveRecordClient.new(
  use_database: true,
  dataset_config: {
    kaggle: { username: 'user', api_key: 'key' }
  }
)

# Load datasets - automatically stored in database
client.load_kaggle_dataset('owner', 'dataset')
client.load_csv_dataset('https://example.com/data.csv')

# View dataset history
history = client.dataset_history(limit: 5)
# => [{ source_type: 'kaggle', identifier: 'owner/dataset', total_entries: 1000, processed_at: ... }]

# Filter by source type
kaggle_history = client.dataset_history(source_type: 'kaggle')
csv_history = client.dataset_history(source_type: 'csv')
```

## Rails Integration

### Installation

Add to your Gemfile:

```ruby
gem 'url_categorise'
# Optional for database integration
gem 'activerecord'  # Usually already included in Rails
```

### Generate Migration

```bash
# Generate the migration file
rails generate migration CreateUrlCategoriseTables

# Replace the generated migration content with:
```

```ruby
class CreateUrlCategoriseTables < ActiveRecord::Migration[7.0]
  def change
    create_table :url_categorise_list_metadata do |t|
      t.string :name, null: false, index: { unique: true }
      t.string :url, null: false
      t.text :categories, null: false
      t.string :file_path
      t.datetime :fetched_at
      t.string :file_hash
      t.datetime :file_updated_at
      t.timestamps
    end

    create_table :url_categorise_domains do |t|
      t.string :domain, null: false, index: { unique: true }
      t.text :categories, null: false
      t.timestamps
    end
    
    add_index :url_categorise_domains, :domain
    add_index :url_categorise_domains, :categories

    create_table :url_categorise_ip_addresses do |t|
      t.string :ip_address, null: false, index: { unique: true }
      t.text :categories, null: false
      t.timestamps
    end
    
    add_index :url_categorise_ip_addresses, :ip_address
    add_index :url_categorise_ip_addresses, :categories

    create_table :url_categorise_dataset_metadata do |t|
      t.string :source_type, null: false, index: true
      t.string :identifier, null: false
      t.string :data_hash, null: false, index: { unique: true }
      t.integer :total_entries, null: false
      t.text :category_mappings
      t.text :processing_options
      t.datetime :processed_at
      t.timestamps
    end
    
    add_index :url_categorise_dataset_metadata, :source_type
    add_index :url_categorise_dataset_metadata, :identifier
    add_index :url_categorise_dataset_metadata, :processed_at
  end
end
```

```bash
# Run the migration
rails db:migrate
```

### Service Class Example

Create a service class for URL categorization:

```ruby
# app/services/url_categorizer_service.rb
class UrlCategorizerService
  include Singleton

  def initialize
    @client = UrlCategorise::ActiveRecordClient.new(
      cache_dir: Rails.root.join('tmp', 'url_cache'),
      use_database: true,
      force_download: Rails.env.development?,
      request_timeout: Rails.env.production? ? 30 : 10,  # Longer timeout in production
      iab_compliance: Rails.env.production?,              # Enable IAB compliance in production
      iab_version: :v3,                                   # Use IAB Content Taxonomy v3.0
      auto_load_datasets: Rails.env.production?,          # Auto-load datasets in production
      dataset_config: {
        kaggle: {
          username: ENV['KAGGLE_USERNAME'],
          api_key: ENV['KAGGLE_API_KEY']
        },
        cache_path: Rails.root.join('tmp', 'dataset_cache'),
        download_path: Rails.root.join('tmp', 'dataset_downloads')
      }
    )
  end

  def categorise(url)
    Rails.cache.fetch("url_category_#{url}", expires_in: 1.hour) do
      @client.categorise(url)
    end
  end

  def categorise_with_ip_resolution(url)
    Rails.cache.fetch("url_ip_category_#{url}", expires_in: 1.hour) do
      @client.resolve_and_categorise(url)
    end
  end

  def categorise_ip(ip_address)
    Rails.cache.fetch("ip_category_#{ip_address}", expires_in: 6.hours) do
      @client.categorise_ip(ip_address)
    end
  end

  def stats
    base_stats = @client.database_stats
    base_stats.merge({
      dataset_hosts: @client.count_of_dataset_hosts,
      dataset_categories: @client.count_of_dataset_categories,
      iab_compliant: @client.iab_compliant?,
      iab_version: @client.iab_version
    })
  end

  def refresh_lists!
    @client.update_database
  end

  def load_dataset(type, identifier, options = {})
    case type.to_s
    when 'kaggle'
      owner, dataset = identifier.split('/')
      @client.load_kaggle_dataset(owner, dataset, options)
    when 'csv'
      @client.load_csv_dataset(identifier, options)
    else
      raise ArgumentError, "Unsupported dataset type: #{type}"
    end
  end

  def get_iab_mapping(category)
    @client.get_iab_mapping(category)
  end
end
```

### Controller Example

```ruby
# app/controllers/api/v1/url_categorization_controller.rb
class Api::V1::UrlCategorizationController < ApplicationController
  before_action :authenticate_api_key  # Your authentication method

  def categorise
    url = params[:url]
    
    if url.blank?
      render json: { error: 'URL parameter is required' }, status: :bad_request
      return
    end

    begin
      categories = UrlCategorizerService.instance.categorise(url)
      
      render json: {
        url: url,
        categories: categories,
        risk_level: calculate_risk_level(categories),
        timestamp: Time.current
      }
    rescue => e
      Rails.logger.error "URL categorization failed for #{url}: #{e.message}"
      render json: { error: 'Categorization failed' }, status: :internal_server_error
    end
  end

  def categorise_with_ip
    url = params[:url]
    
    begin
      categories = UrlCategorizerService.instance.categorise_with_ip_resolution(url)
      
      render json: {
        url: url,
        categories: categories,
        includes_ip_check: true,
        risk_level: calculate_risk_level(categories),
        timestamp: Time.current
      }
    rescue => e
      Rails.logger.error "URL+IP categorization failed for #{url}: #{e.message}"
      render json: { error: 'Categorization failed' }, status: :internal_server_error
    end
  end

  def stats
    render json: UrlCategorizerService.instance.stats
  end

  private

  def calculate_risk_level(categories)
    high_risk = [:malware, :phishing, :threat_indicators, :cryptojacking, :phishing_extended]
    medium_risk = [:gambling, :pornography, :tor_exit_nodes, :compromised_ips, :suspicious_domains]
    
    return 'high' if (categories & high_risk).any?
    return 'medium' if (categories & medium_risk).any?
    return 'low' if categories.any?
    'unknown'
  end
end
```

### Model Integration Example

Add URL categorization to your existing models:

```ruby
# app/models/website.rb
class Website < ApplicationRecord
  validates :url, presence: true, uniqueness: true
  
  after_create :categorize_url
  
  def categories
    super || categorize_url
  end
  
  def risk_level
    high_risk_categories = [:malware, :phishing, :threat_indicators, :cryptojacking]
    return 'high' if (categories & high_risk_categories).any?
    return 'medium' if categories.include?(:gambling) || categories.include?(:pornography)
    return 'low' if categories.any?
    'unknown'
  end
  
  def is_safe?
    risk_level == 'low' || risk_level == 'unknown'
  end
  
  private
  
  def categorize_url
    cats = UrlCategorizerService.instance.categorise(url)
    update_column(:categories, cats) if persisted?
    cats
  end
end
```

### Background Job Example

For processing large batches of URLs:

```ruby
# app/jobs/url_categorization_job.rb
class UrlCategorizationJob < ApplicationJob
  queue_as :default
  
  def perform(batch_id, urls)
    service = UrlCategorizerService.instance
    
    results = urls.map do |url|
      begin
        categories = service.categorise_with_ip_resolution(url)
        { url: url, categories: categories, status: 'success' }
      rescue => e
        Rails.logger.error "Failed to categorize #{url}: #{e.message}"
        { url: url, error: e.message, status: 'failed' }
      end
    end
    
    # Store results in your preferred way (database, Redis, etc.)
    BatchResult.create!(
      batch_id: batch_id,
      results: results,
      completed_at: Time.current
    )
  end
end

# Usage:
urls = ['http://example.com', 'http://suspicious-site.com']
UrlCategorizationJob.perform_later('batch_123', urls)
```

### Configuration

```ruby
# config/initializers/url_categorise.rb
Rails.application.configure do
  config.after_initialize do
    # Warm up the categorizer on app start
    UrlCategorizerService.instance if Rails.env.production?
  end
end
```

### Rake Tasks

```ruby
# lib/tasks/url_categorise.rake
namespace :url_categorise do
  desc "Update all categorization lists"
  task refresh_lists: :environment do
    puts "Refreshing URL categorization lists..."
    UrlCategorizerService.instance.refresh_lists!
    puts "Lists refreshed successfully!"
    puts "Stats: #{UrlCategorizerService.instance.stats}"
  end
  
  desc "Show categorization statistics"
  task stats: :environment do
    stats = UrlCategorizerService.instance.stats
    puts "URL Categorization Statistics:"
    puts "  Domains: #{stats[:domains]}"
    puts "  IP Addresses: #{stats[:ip_addresses]}"
    puts "  Categories: #{stats[:categories]}"
    puts "  List Metadata: #{stats[:list_metadata]}"
  end
end
```

### Cron Job Setup

Add to your crontab or use whenever gem:

```ruby
# config/schedule.rb (if using whenever gem)
every 1.day, at: '2:00 am' do
  rake 'url_categorise:refresh_lists'
end
```

This Rails integration provides enterprise-level URL categorization with caching, background processing, and comprehensive error handling.

## List Format Support

The gem automatically detects and parses multiple blocklist formats:

### Hosts File Format
```
0.0.0.0 badsite.com
127.0.0.1 malware.com  
```

### Plain Text Format
```
badsite.com
malware.com
```

### dnsmasq Format  
```
address=/badsite.com/0.0.0.0
address=/malware.com/0.0.0.0
```

### uBlock Origin Format
```
||badsite.com^
||malware.com^$important
```

## Performance Tips

1. **Use Caching**: Enable `cache_dir` for faster subsequent runs
2. **Database Storage**: Use `ActiveRecordClient` for applications with frequent lookups  
3. **Selective Categories**: Only load categories you need for better performance
4. **Batch Processing**: Process multiple URLs in batches when possible

## Metadata and Updates

Access detailed metadata about downloaded lists:

```ruby
client = UrlCategorise::Client.new(cache_dir: "./cache")

# Access metadata for each list
client.metadata.each do |url, meta|
  puts "URL: #{url}"
  puts "Last updated: #{meta[:last_updated]}"  
  puts "ETag: #{meta[:etag]}"
  puts "Content hash: #{meta[:content_hash]}"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Tests
To run tests execute:

    $ rake test

### Test Coverage
The gem includes comprehensive test coverage using SimpleCov. To generate coverage reports:

    $ rake test

Coverage reports are generated in the `coverage/` directory. The gem maintains a minimum coverage threshold of 80% to ensure code quality and reliability.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trex22/url_categorise. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the UrlCategorise: project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/trex22/url_categorise/blob/master/CODE_OF_CONDUCT.md).
