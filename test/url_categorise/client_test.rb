require "test_helper"

class UrlCategoriseTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::UrlCategorise::VERSION
  end

  def test_that_the_client_has_compatible_api_version
    assert_equal 'v2', ::UrlCategorise::Client.compatible_api_version
  end

  def test_that_the_client_has_api_version
    assert_equal 'v2 2023-04-12', ::UrlCategorise::Client.api_version
  end
end
