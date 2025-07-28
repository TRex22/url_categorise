require "test_helper"

class UrlCategoriseVersionTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::UrlCategorise::VERSION
    assert_match(/\A\d+\.\d+\.\d+\z/, ::UrlCategorise::VERSION)
  end
end