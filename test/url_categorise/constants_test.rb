require "test_helper"

class UrlCategoriseConstantsTest < Minitest::Test
  include UrlCategorise::Constants

  def test_one_megabyte_constant
    assert_equal 1048576, ONE_MEGABYTE
  end

  def test_default_host_urls_is_hash
    assert_instance_of Hash, DEFAULT_HOST_URLS
    refute_empty DEFAULT_HOST_URLS
  end

  def test_default_host_urls_contains_required_categories
    required_categories = [:abuse, :malware, :phishing, :advertising]
    
    required_categories.each do |category|
      assert_includes DEFAULT_HOST_URLS.keys, category, "Missing category: #{category}"
    end
  end

  def test_default_host_urls_values_are_arrays
    DEFAULT_HOST_URLS.each do |category, urls|
      assert_instance_of Array, urls, "URLs for #{category} should be an array"
      refute_empty urls, "URLs for #{category} should not be empty"
    end
  end

  def test_social_media_category_contains_symbols
    social_media_list = DEFAULT_HOST_URLS[:social_media]
    assert_instance_of Array, social_media_list
    
    social_media_list.each do |item|
      assert_instance_of Symbol, item, "Social media items should be symbols"
    end
  end

  def test_url_formats_are_valid
    DEFAULT_HOST_URLS.each do |category, urls|
      next if category == :social_media # Skip symbolic references
      
      urls.each do |url|
        next unless url.is_a?(String)
        assert_match(/\Ahttps?:\/\//, url, "Invalid URL format for #{category}: #{url}")
      end
    end
  end
end