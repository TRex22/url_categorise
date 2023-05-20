# URL Categorise
A tool which makes use of a set of domain host lists, and is then able to classify a given URL.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'url_categorise'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install UrlCategorise

## Usage
The default host lists I picked for their separated categories.
I didn't select them for the quality of data
Use at your own risk!

```ruby
  require 'url_categorise'
  client = UrlCategorise::Client.new

  client.count_of_hosts
  client.count_of_categories
  client.size_of_data # In megabytes

  url = "www.google.com"
  client.categorise(url)

  # Can also initialise the client using a custom dataset
  host_urls = {
    abuse: ["https://github.com/blocklistproject/Lists/raw/master/abuse.txt"]
  }

  require 'url_categorise'
  client = UrlCategorise::Client.new(host_urls: host_urls)

  # You can also define symbols to combine other categories
  host_urls = {
    abuse: ["https://github.com/blocklistproject/Lists/raw/master/abuse.txt"],
    bad_links: [:abuse]
  }

  require 'url_categorise'
  client = UrlCategorise::Client.new(host_urls: host_urls)
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
