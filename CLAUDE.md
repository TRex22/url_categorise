# UrlCategorise Development Guidelines

## Overview
UrlCategorise is a Ruby gem for categorizing URLs and domains based on various security and content blocklists. It downloads and processes multiple types of lists to provide comprehensive domain categorization.

## Development Requirements

### Testing Standards
- **ALL new changes MUST include new tests**
- **Test coverage MUST be 90% or higher**
- **NEVER delete, skip, or environment-check tests to make them pass**
- **Tests MUST pass because the underlying code works correctly**
- Use minitest for all testing
- Use WebMock for HTTP request stubbing in tests
- Run tests with: `bundle exec rake test`
- SimpleCov integration is mandatory for coverage tracking

### Dependencies and Rails Support
- **MUST use the latest stable versions of gems**
- Ruby >= 3.0.0 (currently using 3.4+)
- **MUST use minitest and rake** for testing and build automation
- **Rails compatibility MUST support Rails 8.x** and current stable versions
- Dependencies are managed via Gemfile and gemspec
- ActiveRecord integration must be optional and backward compatible

#### Rails 8 Integration
- ActiveRecord models use `coder: JSON` for serialization (Rails 8 compatible)
- Migration version set to `ActiveRecord::Migration[8.0]` 
- Optional database integration with automatic fallback to memory-based categorization
- Installation: Generate migration with `UrlCategorise::Models.generate_migration`
- Usage: Use `UrlCategorise::ActiveRecordClient` instead of `UrlCategorise::Client`

### Code Quality
- Follow Ruby best practices and conventions
- Use meaningful variable and method names
- Add appropriate error handling
- Ensure thread safety where applicable

### Supported List Formats
The gem supports multiple blocklist formats:
- Standard hosts files (0.0.0.0 domain.com)
- pfSense format
- AdSense lists  
- uBlock Origin files
- dnsmasq format
- Plain text domain lists

### Category Management Guidelines
- **Category names MUST be human-readable and intuitive**
- **NEVER add combined/meta lists as categories** (e.g., hagezi_light, stevenblack_all)
- **First try to add new lists to existing categories** before creating new ones
- **Use descriptive names instead of provider prefixes**:
  - ❌ Bad: `abuse_ch_feodo`, `dshield_block_list`, `botnet_c2`, `doh_vpn_proxy_bypass`
  - ✅ Good: `banking_trojans`, `suspicious_domains`, `botnet_command_control`, `dns_over_https_bypass`
- **Logical category organization**:
  - Security threats: `malware`, `phishing`, `threat_indicators`, `cryptojacking`, `phishing_extended`
  - Content filtering: `advertising`, `gambling`, `pornography`, `social_media`
  - Network security: `suspicious_domains`, `threat_intelligence`, `dns_over_https_bypass`
  - Geographic/specialized: `sanctions_ips`, `newly_registered_domains`, `chinese_ad_hosts`, `korean_ad_hosts`
  - IP-based security: `compromised_ips`, `tor_exit_nodes`, `open_proxy_ips`, `top_attack_sources`
  - Content categories: `news`, `fakenews` (remaining active categories)
  - Mobile/TV: `mobile_ads`, `smart_tv_ads`

### URL Health Monitoring and Cleanup
The gem includes automatic monitoring and cleanup of broken URLs:
- **Automatic removal of broken URLs**: Categories with URLs returning 403, 404, or persistent errors are commented out
- **Health checking tools**: Use `bin/check_lists` to verify all URLs in constants
- **Programmatic checking**: The `Client#check_all_lists` method provides detailed health reports
- **Recently removed categories**: Categories like `botnet_command_control` (403 Forbidden), `blogs`, `forums`, `educational`, `health`, `finance`, `streaming`, `shopping`, `business`, `technology`, `government` (404 Not Found) have been commented out until working URLs are found

### Core Features
- Domain/URL categorization
- Multiple list format parsing
- Hash-based file update detection
- Optional local file caching
- IP sanctions list checking
- DNS resolution for domain-to-IP mapping
- ActiveRecord/Rails integration (optional)
- URL health monitoring and reporting
- Automatic cleanup of broken blocklist sources
- **Dataset Processing**: Kaggle and CSV dataset integration with three auth methods
- **Optional Kaggle**: Can disable Kaggle functionality entirely while keeping CSV processing
- **Smart Caching**: Cached datasets work without credentials, avoiding unnecessary authentication
- **Data Hashing**: SHA256 content hashing for dataset change detection
- **Category Mapping**: Flexible column detection and category mapping for datasets
- **Credential Warnings**: Helpful warnings when Kaggle credentials are missing but functionality continues
- **IAB Compliance**: Full support for IAB Content Taxonomy v2.0 and v3.0 standards
- **Dataset-Specific Metrics**: Separate counting methods for dataset vs DNS list categorization
- **Enhanced Statistics**: Extended helper methods for comprehensive data insights
- **ActiveAttr Settings**: In-memory modification of client settings using attribute setters
- **Data Export**: Multiple export formats including hosts files per category and CSV data exports
- **CLI Commands**: Command-line utilities for data export and list checking

### Architecture
- `Client` class: Main interface for categorization with IAB compliance support and ActiveAttr attributes
- `DatasetProcessor` class: Handles Kaggle and CSV dataset processing
- `IabCompliance` module: Maps categories to IAB Content Taxonomy v2.0/v3.0 standards
- `Constants` module: Contains default list URLs and categories
- `ActiveRecordClient` class: Database-backed client with dataset history
- Modular design allows extending with new list sources and datasets
- Support for custom list directories, caching, dataset integration, IAB compliance, and data export
- ActiveAttr integration for dynamic setting modification and attribute validation

### New Features (Latest Version)

#### Video Hosting Detection and Regex Categorization
Advanced video content detection system with:

- **Comprehensive Video Hosting Lists**: Generate PiHole-compatible hosts files from yt-dlp extractors  
- **Regex-Based Content Detection**: Distinguish between video content URLs vs homepages/profiles/playlists
- **Direct Video URL Detection**: `video_url?` method to check if URLs are direct video content links
- **Automatic List Generation**: `bin/generate_video_lists` script fetches and processes yt-dlp data
- **Video Hosting Category**: Separate `video_hosting` category with 3,500+ domains
- **Smart Content Categorization**: URLs matching video patterns get `*_content` suffix categories
- **Remote Pattern Files**: Automatically downloads video patterns from GitHub repository

```ruby
# Enable regex categorization for video content detection (uses remote patterns by default)
client = UrlCategorise::Client.new(regex_categorization: true)

# Basic domain categorization
client.categorise('https://youtube.com') # => [:video_hosting]

# Enhanced content detection  
client.categorise('https://youtube.com/watch?v=abc123') # => [:video_hosting, :video_hosting_content]

# Direct video URL detection
client.video_url?('https://youtube.com/watch?v=abc123')  # => true
client.video_url?('https://youtube.com')                # => false
client.video_url?('https://vimeo.com/123456789')       # => true
client.video_url?('https://tiktok.com/@user/video/123') # => true
```

#### Dynamic Settings with ActiveAttr
The Client class now uses ActiveAttr to provide dynamic attribute modification:

```ruby
client = UrlCategorise::Client.new

# Modify settings in-memory
client.smart_categorization_enabled = true
client.iab_compliance_enabled = true
client.iab_version = :v2
client.request_timeout = 30
client.dns_servers = ['8.8.8.8', '8.8.4.4']

# Settings take effect immediately
categories = client.categorise('reddit.com') # Uses new smart categorization rules
```

#### Data Export Features

##### Hosts File Export
Export all categorized domains as separate hosts files per category:

```ruby
# Export to default location (cache_dir/exports/hosts or ./exports/hosts)
result = client.export_hosts_files

# Export to custom location
result = client.export_hosts_files('/custom/export/path')

# Returns hash with file information:
# {
#   malware: { path: '/path/malware.hosts', filename: 'malware.hosts', count: 1500 },
#   advertising: { path: '/path/advertising.hosts', filename: 'advertising.hosts', count: 25000 },
#   _summary: { total_categories: 15, total_domains: 50000, export_directory: '/path' }
# }
```

##### CSV Data Export
Export all data as a single comprehensive CSV file for AI training and analysis:

```ruby
# Export to default location (cache_dir/exports/csv or ./exports/csv)
result = client.export_csv_data

# Export to custom location  
result = client.export_csv_data('/custom/export/path')

# Returns:
# {
#   csv_file: 'url_categorise_comprehensive_export_TIMESTAMP.csv',
#   summary_file: 'export_summary_TIMESTAMP.json',
#   total_entries: 75000,
#   summary: { domain_categorization_entries: 50000, dataset_content_entries: 25000 },
#   export_directory: '/export/path'
# }
```

**Comprehensive Export Features:**
- **Everything in One File**: Combined domains, categories, and raw dataset content
- **Rich Dataset Content**: Original titles, descriptions, summaries, and text from datasets
- **Dynamic Headers**: Automatically includes all available fields from any dataset
- **Data Type Tracking**: Distinguishes between processed domains and raw dataset entries
- **Perfect for AI/ML**: Single file with both structured categorization and rich textual features

#### CLI Commands
Command-line utilities for comprehensive data export:

```bash
# Export hosts files per category
$ bundle exec export_hosts --output /tmp/hosts --verbose

# Full CSV export with datasets and all features
$ bundle exec export_csv --auto-load-datasets --iab-compliance --smart-categorization --verbose

# Custom configuration export
$ bundle exec export_csv --cache-dir ./custom_cache --kaggle-credentials ~/kaggle.json --output /tmp/export

# Basic domain categorization only
$ bundle exec export_csv --output /tmp/basic

# Health check for all blocklist URLs
$ bundle exec check_lists

# Generate updated video hosting lists
$ ruby bin/generate_video_lists
```

**Enhanced CLI Features:**
- `--auto-load-datasets`: Automatically load datasets from constants for rich content export
- `--kaggle-credentials FILE`: Custom Kaggle API credentials file path
- Full integration with all client features (IAB compliance, smart categorization, etc.)
- Verbose output shows dataset statistics and loading progress
- Video list generation from yt-dlp extractors with manual curation

### List Sources
Primary sources include:
- The Block List Project
- hagezi/dns-blocklists  
- StevenBlack/hosts
- Various specialized security lists
- **yt-dlp video extractors**: Comprehensive video hosting domain detection (3,500+ domains)
- **GitHub-hosted video patterns**: Remote video URL detection patterns with manual curation
- **Kaggle datasets**: Public URL classification datasets
- **Custom CSV files**: Direct CSV dataset URLs with flexible column mapping

**Video hosting lists are now automatically fetched from:**
- Video domains: `https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_hosting_domains.hosts`
- URL patterns: `https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_url_patterns.txt`

### Testing Guidelines
- Mock all HTTP requests using WebMock
- Test both success and failure scenarios
- Verify proper parsing of different list formats
- Test edge cases (empty responses, malformed data)
- Include integration tests for the full categorization flow

### Performance Considerations
- Implement efficient parsing for large lists
- Use appropriate data structures for fast lookups
- Consider memory usage with large datasets
- Provide options for selective list loading

### Configuration
- Allow custom list URLs
- Support for local file directories
- Configurable DNS servers for IP resolution
- Optional caching parameters

## Build and Release Process
1. Update version number in `lib/url_categorise/version.rb`
2. Update CHANGELOG.md with new features
3. Run full test suite: `bundle exec rake test`
4. Update documentation as needed
5. Build gem: `gem build url_categorise.gemspec`
6. Release: `gem push url_categorise-x.x.x.gem`

## Contributing
- Fork the repository
- Create a feature branch
- Add comprehensive tests for new functionality
- Ensure all tests pass
- Update documentation
- Submit a pull request

## CI/CD
- GitHub Actions workflow runs tests on multiple Ruby versions
- All tests must pass before merging
- Coverage reporting with Codecov integration
- Automated dependency updates where appropriate