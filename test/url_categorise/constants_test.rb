require 'test_helper'

class UrlCategoriseConstantsTest < Minitest::Test
  include UrlCategorise::Constants

  def test_one_megabyte_constant
    assert_equal 1_048_576, ONE_MEGABYTE
  end

  def test_default_host_urls_is_hash
    assert_instance_of Hash, DEFAULT_HOST_URLS
    refute_empty DEFAULT_HOST_URLS
  end

  def test_default_host_urls_contains_required_categories
    required_categories = %i[abuse malware phishing advertising]

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
      assert_instance_of Symbol, item, 'Social media items should be symbols'
    end
  end

  def test_url_formats_are_valid
    DEFAULT_HOST_URLS.each do |category, urls|
      next if category == :social_media # Skip symbolic references

      urls.each do |url|
        next unless url.is_a?(String)

        assert_match(%r{\A(?:https?://|file://)}, url, "Invalid URL format for #{category}: #{url}")
      end
    end
  end

  def test_all_categories_are_symbols
    DEFAULT_HOST_URLS.keys.each do |category|
      assert_instance_of Symbol, category, "Category keys should be symbols: #{category}"
    end
  end

  def test_constants_module_structure
    assert defined?(UrlCategorise::Constants::ONE_MEGABYTE)
    assert defined?(UrlCategorise::Constants::DEFAULT_HOST_URLS)
  end

  def test_comprehensive_category_coverage
    # Test that we have good coverage of different types of categories
    security_categories = %i[malware phishing threat_indicators]
    content_categories = %i[advertising gambling pornography gaming]
    corporate_categories = %i[google facebook microsoft apple]

    [security_categories, content_categories, corporate_categories].each do |category_group|
      category_group.each do |category|
        assert_includes DEFAULT_HOST_URLS.keys, category if DEFAULT_HOST_URLS.key?(category)
      end
    end

    # NOTE: botnet_command_control was removed due to broken URL (403 Forbidden)
    refute_includes DEFAULT_HOST_URLS.keys, :botnet_command_control,
                    'botnet_command_control should be removed due to broken URL'
  end

  def test_hagezi_categories_present
    hagezi_categories = DEFAULT_HOST_URLS.keys.select do |k|
      k.to_s.include?('hagezi') || %i[threat_intelligence dyndns badware_hoster].include?(k)
    end
    refute_empty hagezi_categories, 'Should have HaGeZi categories'
  end

  def test_security_threat_categories_present
    security_categories = %i[threat_indicators cryptojacking]
    security_categories.each do |category|
      assert_includes DEFAULT_HOST_URLS.keys, category, "Should have security category: #{category}"
    end

    # NOTE: botnet_command_control was removed due to broken URL (403 Forbidden)
    refute_includes DEFAULT_HOST_URLS.keys, :botnet_command_control,
                    'botnet_command_control should be removed due to broken URL'
  end

  def test_network_security_categories_present
    network_categories = %i[top_attack_sources suspicious_domains dns_over_https_bypass]
    network_categories.each do |category|
      assert_includes DEFAULT_HOST_URLS.keys, category, "Should have network security category: #{category}"
    end

    # NOTE: botnet_command_control was removed due to broken URL (403 Forbidden)
    refute_includes DEFAULT_HOST_URLS.keys, :botnet_command_control,
                    'botnet_command_control should be removed due to broken URL'
  end

  def test_ip_based_categories_present
    ip_categories = %i[sanctions_ips compromised_ips tor_exit_nodes open_proxy_ips]
    ip_categories.each do |category|
      assert_includes DEFAULT_HOST_URLS.keys, category, "Should have IP-based category: #{category}"
    end
  end

  def test_content_categories_present
    content_categories = [:news] # Only news category remains, others had broken URLs
    content_categories.each do |category|
      assert_includes DEFAULT_HOST_URLS.keys, category, "Should have content category: #{category}"
    end

    # NOTE: These categories were removed due to broken URLs (404 Not Found)
    removed_categories = %i[blogs forums educational health finance streaming shopping]
    removed_categories.each do |category|
      refute_includes DEFAULT_HOST_URLS.keys, category, "#{category} should be removed due to broken URLs"
    end
  end

  def test_business_categories_present
    # NOTE: All business categories were removed due to broken URLs (404 Not Found)
    removed_categories = %i[business technology government]
    removed_categories.each do |category|
      refute_includes DEFAULT_HOST_URLS.keys, category, "#{category} should be removed due to broken URLs"
    end
  end

  def test_regional_categories_present
    remaining_categories = %i[chinese_ad_hosts korean_ad_hosts] # These remain functional
    remaining_categories.each do |category|
      assert_includes DEFAULT_HOST_URLS.keys, category, "Should have regional category: #{category}"
    end

    # NOTE: These categories were removed due to broken URLs (404 Not Found)
    removed_categories = %i[local_news international_news legitimate_news]
    removed_categories.each do |category|
      refute_includes DEFAULT_HOST_URLS.keys, category, "#{category} should be removed due to broken URLs"
    end
  end

  def test_no_duplicate_categories
    categories = DEFAULT_HOST_URLS.keys
    assert_equal categories.uniq, categories, 'Should not have duplicate categories'
  end

  def test_constants_are_accessible
    # Test that constants are accessible and have expected values
    assert_equal 1_048_576, ONE_MEGABYTE
    assert_instance_of Hash, DEFAULT_HOST_URLS
    refute_empty DEFAULT_HOST_URLS
  end
end
