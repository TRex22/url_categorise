# UrlCategorise Development Guidelines

## Overview
UrlCategorise is a Ruby gem for categorizing URLs and domains based on various security and content blocklists. It downloads and processes multiple types of lists to provide comprehensive domain categorization.

## Development Requirements

### Testing
- **ALL new changes MUST include new tests**
- Use minitest for all testing
- Test coverage should be comprehensive
- Use WebMock for HTTP request stubbing in tests
- Run tests with: `bundle exec rake test`

### Dependencies
- **MUST use the latest stable versions of gems**
- Ruby >= 3.0.0 (currently using 3.4+)
- **MUST use minitest and rake** for testing and build automation
- Dependencies are managed via Gemfile and gemspec

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

### Core Features
- Domain/URL categorization
- Multiple list format parsing
- Hash-based file update detection
- Optional local file caching
- IP sanctions list checking
- DNS resolution for domain-to-IP mapping
- ActiveRecord/Rails integration (optional)

### Architecture
- `Client` class: Main interface for categorization
- `Constants` module: Contains default list URLs and categories
- Modular design allows extending with new list sources
- Support for custom list directories and caching

### List Sources
Primary sources include:
- The Block List Project
- hagezi/dns-blocklists  
- StevenBlack/hosts
- Various specialized security lists

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