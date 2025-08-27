require "test_helper"

class UrlCategoriseVersionTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::UrlCategorise::VERSION
    assert_match(/\A\d+\.\d+\.\d+\z/, ::UrlCategorise::VERSION)
  end

  def test_version_is_string
    assert_instance_of String, ::UrlCategorise::VERSION
  end

  def test_version_follows_semver
    parts = ::UrlCategorise::VERSION.split(".")
    assert_equal 3, parts.length

    parts.each do |part|
      assert_match(/\A\d+\z/, part, "Version part should be numeric: #{part}")
    end
  end

  def test_module_structure
    assert defined?(UrlCategorise)
    assert defined?(UrlCategorise::VERSION)
    assert defined?(UrlCategorise::Client)
    assert defined?(UrlCategorise::Constants)
  end

  def test_module_is_module
    assert_kind_of Module, UrlCategorise
  end

  def test_client_is_class
    assert_kind_of Class, UrlCategorise::Client
  end

  def test_constants_is_module
    assert_kind_of Module, UrlCategorise::Constants
  end

  def test_client_inheritance
    assert UrlCategorise::Client < ApiPattern::Client
  end

  def test_constants_module_inclusion
    client = UrlCategorise::Client.new(host_urls: { test: [] })
    assert client.class.include?(UrlCategorise::Constants)
  end
end
