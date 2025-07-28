require "test_helper"

class UrlCategoriseNewListsTest < Minitest::Test
  def test_hagezi_lists_are_available
    hagezi_categories = [
      :hagezi_light, :hagezi_normal, :hagezi_pro, :hagezi_ultimate,
      :hagezi_threat_intelligence, :hagezi_gambling, :hagezi_anti_piracy,
      :hagezi_dyndns, :hagezi_badware_hoster, :hagezi_most_abused_tlds,
      :hagezi_newly_registered_domains, :hagezi_doh_vpn_proxy_bypass
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
      :stevenblack_base, :stevenblack_fakenews, :stevenblack_social,
      :stevenblack_gambling_porn, :stevenblack_all
    ]
    
    stevenblack_categories.each do |category|
      assert_includes UrlCategorise::Constants::DEFAULT_HOST_URLS.keys, category,
                      "Missing StevenBlack category: #{category}"
      assert_instance_of Array, UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
    end
  end

  def test_abuse_ch_lists_are_available
    abuse_ch_categories = [
      :abuse_ch_feodo, :abuse_ch_malware_bazaar, :abuse_ch_ssl_blacklist, :abuse_ch_threat_fox
    ]
    
    abuse_ch_categories.each do |category|
      assert_includes UrlCategorise::Constants::DEFAULT_HOST_URLS.keys, category,
                      "Missing Abuse.ch category: #{category}"
      assert_instance_of Array, UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      refute_empty UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
    end
  end

  def test_sanctions_and_ip_lists_are_available
    ip_categories = [
      :sanctions_ips, :compromised_ips, :tor_exit_nodes, :open_proxy_ips,
      :dshield_top_attackers, :dshield_block_list
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
      :cryptojacking, :ransomware, :botnet_c2, :phishing_extended
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
      :hagezi_light, :hagezi_normal, :stevenblack_base, :abuse_ch_feodo,
      :sanctions_ips, :cryptojacking, :chinese_ad_hosts, :mobile_ads
    ]
    
    new_categories.each do |category|
      urls = UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      urls.each do |url|
        assert_match(/\Ahttps?:\/\//, url, "Invalid URL format for #{category}: #{url}")
      end
    end
  end

  def test_hagezi_urls_use_jsdelivr_cdn
    hagezi_categories = [
      :hagezi_light, :hagezi_normal, :hagezi_pro, :hagezi_ultimate,
      :hagezi_threat_intelligence, :hagezi_gambling, :hagezi_anti_piracy,
      :hagezi_dyndns, :hagezi_badware_hoster, :hagezi_most_abused_tlds,
      :hagezi_newly_registered_domains, :hagezi_doh_vpn_proxy_bypass
    ]
    
    hagezi_categories.each do |category|
      urls = UrlCategorise::Constants::DEFAULT_HOST_URLS[category]
      urls.each do |url|
        assert_includes url, "cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release",
                        "Hagezi URL should use jsDelivr CDN: #{url}"
      end
    end
  end

  def test_stevenblack_urls_use_github_raw
    stevenblack_categories = [
      :stevenblack_base, :stevenblack_fakenews, :stevenblack_social,
      :stevenblack_gambling_porn, :stevenblack_all
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
        refute_includes all_urls, url, "Duplicate URL found: #{url} in category #{category}"
        all_urls << url
      end
    end
  end
end