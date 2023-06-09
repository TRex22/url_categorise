lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "url_categorise/version"

Gem::Specification.new do |spec|
  spec.name          = "UrlCategorise"
  spec.version       = UrlCategorise::VERSION
  spec.authors       = ["trex22"]
  spec.email         = ["contact@jasonchalom.com"]

  spec.summary       = "A client for using the UrlCategorise API in Ruby."
  spec.description   = "A client for using the UrlCategorise API in Ruby. Built from their api documentation. This is an unofficial project."
  spec.homepage      = "https://github.com/TRex22/UrlCategorise"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "api_pattern", "~> 0.0.4"

  # Development dependancies
  spec.add_development_dependency "rake", "~> 13.0.6"
  spec.add_development_dependency "minitest", "~> 5.18.0"
  spec.add_development_dependency "minitest-focus", "~> 1.3.1"
  spec.add_development_dependency "minitest-reporters", "~> 1.6.0"
  spec.add_development_dependency "timecop", "~> 0.9.6"
  spec.add_development_dependency "mocha", "~> 2.0.2"
  spec.add_development_dependency "pry", "~> 0.14.2"
  spec.add_development_dependency "webmock", "~> 3.18.1"
end
