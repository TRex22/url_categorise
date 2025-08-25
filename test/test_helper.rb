require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'

  add_group 'Libraries', 'lib'

  # Track minimum coverage - comprehensive test suite with dataset functionality
  minimum_coverage 90
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'minitest/autorun'
require 'minitest/focus'
require 'minitest/reporters'
require 'mocha/minitest'
require 'webmock/minitest'
require 'timecop'
require 'pry'

require 'httparty'
require 'nokogiri'

require 'url_categorise'

################################################################################
# Environment Setup
################################################################################

Minitest::Reporters.use!(
  [Minitest::Reporters::DefaultReporter.new(color: true)],
  ENV,
  Minitest.backtrace_filter
)

Timecop.safe_mode = true

################################################################################
# Pry
################################################################################
Pry.config.history_load = true

# Used code from: https://github.com/pry/pry/pull/1846
Pry::Prompt.add 'pry_env', '', %w[> *] do |target_self, nest_level, _pry, sep|
  '[test] ' \
  "(#{Pry.view_clip(target_self)})" \
  "#{":#{nest_level}" unless nest_level.zero?}#{sep} "
end

Pry.config.prompt = Pry::Prompt.all['pry_env']
