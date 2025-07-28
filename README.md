# UrlCategorise

A comprehensive Ruby gem for categorizing URLs and domains based on various security and content blocklists. It downloads and processes multiple types of lists to provide domain categorization across many categories including malware, phishing, advertising, tracking, gambling, and more.

## Features

- **Comprehensive Coverage**: Over 90 categories including security, content, and specialized lists
- **Multiple List Formats**: Supports hosts files, pfSense, AdSense, uBlock Origin, dnsmasq, and plain text formats
- **Intelligent Caching**: Hash-based file update detection with configurable local cache
- **DNS Resolution**: Resolve domains to IPs and check against IP-based blocklists  
- **High-Quality Sources**: Integrates lists from HaGeZi, StevenBlack, The Block List Project, and Abuse.ch
- **ActiveRecord Integration**: Optional database storage for high-performance lookups
- **IP Categorization**: Support for IP address and subnet-based categorization
- **Metadata Tracking**: Track last update times, ETags, and content hashes

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

# Initialize with default lists (90+ categories)
client = UrlCategorise::Client.new

# Get basic statistics
puts "Total hosts: #{client.count_of_hosts}"
puts "Categories: #{client.count_of_categories}"  
puts "Data size: #{client.size_of_data} MB"

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

## Available Categories

### Security Lists
- **malware**, **phishing**, **ransomware**, **botnet_c2** - Malicious domains and IPs
- **abuse_ch_feodo**, **abuse_ch_malware_bazaar** - Abuse.ch threat feeds
- **hagezi_threat_intelligence** - HaGeZi threat intelligence
- **sanctions_ips**, **compromised_ips** - IP-based sanctions and compromised hosts

### Content Filtering  
- **advertising**, **tracking**, **gambling**, **pornography** - Content categories
- **social_media**, **gaming**, **dating_services** - Platform-specific lists
- **hagezi_gambling**, **stevenblack_social** - High-quality content filters

### Privacy & Security
- **tor_exit_nodes**, **open_proxy_ips** - Anonymization services
- **hagezi_doh_vpn_proxy_bypass** - DNS-over-HTTPS and VPN bypass
- **cryptojacking** - Cryptocurrency mining scripts

### Specialized Lists
- **hagezi_newly_registered_domains** - Recently registered domains (high risk)
- **hagezi_most_abused_tlds** - Most abused top-level domains
- **mobile_ads**, **smart_tv_ads** - Device-specific advertising

[View all 90+ categories in constants.rb](lib/url_categorise/constants.rb)

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
# => { domains: 50000, ip_addresses: 15000, categories: 45, list_metadata: 90 }

# Direct model access
domain_record = UrlCategorise::Models::Domain.find_by(domain: "example.com")
ip_record = UrlCategorise::Models::IpAddress.find_by(ip_address: "1.2.3.4")
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
      force_download: Rails.env.development?
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
    @client.database_stats
  end

  def refresh_lists!
    @client.update_database
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
    high_risk = [:malware, :phishing, :ransomware, :botnet_c2, :abuse_ch_feodo]
    medium_risk = [:gambling, :pornography, :tor_exit_nodes, :compromised_ips]
    
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
    high_risk_categories = [:malware, :phishing, :ransomware, :botnet_c2]
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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trex22/url_categorise. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the UrlCategorise: project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/trex22/url_categorise/blob/master/CODE_OF_CONDUCT.md).
