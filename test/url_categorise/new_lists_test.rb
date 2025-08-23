require "test_helper"

class UrlCategoriseNewListsTest < Minitest::Test
  def test_hagezi_lists_are_available
    hagezi_categories = [
      :threat_intelligence, :dyndns, :badware_hoster, :most_abused_tlds,
      :newly_registered_domains, :dns_over_https_bypass
    ]
    
    hagezi_categories.each do |category|
      assert_includes UrlCategorise::Constants::DEFAULT_HOST_URLS.keys, category, 
                      "Missing Hagezi category: #{category}"
      assert_instance_of Array, UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
    end
  end

  def test_stevenblack_lists_are_available
    stevenblack_categories = [
      :fakenews
    ]
    
    stevenblack_categories.each do |category|
      assert_includes UrlCategorise::Constants::DEFAULT_HOST_URLS.keys, category,
                      "Missing StevenBlack category: #{category}"
      assert_instance_of Array, UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
    end
  end

  def test_security_threat_lists_are_available
    security_categories = [
      :threat_indicators, :cryptojacking, :botnet_command_control, :phishing_extended
    ]
    
    security_categories.each do |category|
      assert_includes UrlCategorise::Constants::DEFAULT_HOST_URLS.keys, category,
                      "Missing security threat category: #{category}"
      assert_instance_of Array, UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
    end
  end

  def test_sanctions_and_ip_lists_are_available
    ip_categories = [
      :sanctions_ips, :compromised_ips, :tor_exit_nodes, :open_proxy_ips,
      :top_attack_sources, :suspicious_domains
    ]
    
    ip_categories.each do |category|
      assert_includes UrlCategorise::Constants::DEFAULT_HOST_URLS.keys, category,
                      "Missing IP-based category: #{category}"
      assert_instance_of Array, UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
    end
  end

  def test_extended_security_categories_are_available
    security_categories = [
      :cryptojacking, :botnet_command_control, :phishing_extended, :threat_intelligence
    ]
    
    security_categories.each do |category|
      assert_includes UrlCategorise::Constants::DEFAULT_HOST_URLS.keys, category,
                      "Missing security category: #{category}"
      assert_instance_of Array, UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
    end
  end

  def test_regional_and_mobile_categories_are_available
    regional_mobile_categories = [
      :chinese_ad_hosts, :korean_ad_hosts, :mobile_ads, :smart_tv_ads
    ]
    
    regional_mobile_categories.each do |category|
      assert_includes UrlCategorise::Constants::DEFAULT_HOST_URLS.keys, category,
                      "Missing regional/mobile category: #{category}"
      assert_instance_of Array, UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
    end
  end

  def test_all_new_urls_are_valid_format
    new_categories = [
      :threat_intelligence, :fakenews, :threat_indicators,
      :sanctions_ips, :cryptojacking, :chinese_ad_hosts, :mobile_ads
    ]
    
    new_categories.each do |category|
      urls = UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      urls.each do |url|
        assert_match(/\Ahttps?:\/\//, url, "Invalid URL format for #{category}: #{url}")
      end
    end
  end

  def test_hagezi_urls_use_github_raw
    hagezi_categories = [
      :threat_intelligence, :dyndns, :badware_hoster, :most_abused_tlds,
      :dns_over_https_bypass
    ]
    
    hagezi_categories.each do |category|
      urls = UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      urls.each do |url|
        assert_includes url, "github.com/hagezi/dns-blocklists/raw",
                        "Hagezi URL should use GitHub raw: #{url}"
      end
    end
  end
  
  def test_newly_registered_domains_uses_nrd_repository
    urls = UrlCategorise::Constants::DEFAULT_HOST_URLS[:newly_registered_domains]
    urls.each do |url|
      assert_includes url, "github.com/xRuffKez/NRD/raw",
                      "NRD URL should use xRuffKez/NRD repository: #{url}"
    end
  end

  def test_stevenblack_urls_use_github_raw
    stevenblack_categories = [
      :fakenews
    ]
    
    stevenblack_categories.each do |category|
      urls = UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      urls.each do |url|
        assert_includes url, "raw.githubusercontent.com/StevenBlack/hosts",
                        "StevenBlack URL should use GitHub raw: #{url}"
      end
    end
  end

  def test_no_duplicate_urls_in_new_categories
    all_urls = []
    
    UrlCategorise::Constants::DEFAULT_HOST_URLS.each do |category, urls|
      urls.each do |url|
        next if url.is_a?(Symbol) # Skip symbol references to other categories
        refute_includes all_urls, url, "Duplicate URL found: #{url} in category #{category}"
        all_urls << url
      end
    end
  end
end