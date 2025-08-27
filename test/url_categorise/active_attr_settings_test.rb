require 'test_helper'

class UrlCategorise::ActiveAttrSettingsTest < Minitest::Test
  def setup
    # Use empty host URLs to avoid HTTP requests in tests
    @client = UrlCategorise::Client.new(host_urls: {})
  end

  def test_client_includes_active_attr_model
    assert @client.class.included_modules.include?(ActiveAttr::Model)
  end

  def test_smart_categorization_enabled_setter
    assert_equal false, @client.smart_categorization_enabled

    @client.smart_categorization_enabled = true
    assert_equal true, @client.smart_categorization_enabled

    @client.smart_categorization_enabled = false
    assert_equal false, @client.smart_categorization_enabled
  end

  def test_smart_categorization_enabled_affects_categorization
    # Mock hosts data
    @client.instance_variable_set(:@hosts, {
                                    social_media: ['reddit.com'],
                                    news: ['reddit.com']
                                  })

    # Without smart categorization
    @client.smart_categorization_enabled = false
    categories = @client.categorise('https://reddit.com')
    assert categories.include?(:social_media)
    assert categories.include?(:news)

    # With smart categorization enabled
    @client.smart_categorization_enabled = true
    categories = @client.categorise('https://reddit.com')
    # Smart rules should remove overly broad categories
    assert categories.include?(:social_media)
    refute categories.include?(:news) # Should be filtered out by smart rules
  end

  def test_iab_compliance_enabled_setter
    assert_equal false, @client.iab_compliance_enabled

    @client.iab_compliance_enabled = true
    assert_equal true, @client.iab_compliance_enabled

    @client.iab_compliance_enabled = false
    assert_equal false, @client.iab_compliance_enabled
  end

  def test_iab_version_setter
    assert_equal :v3, @client.iab_version

    @client.iab_version = :v2
    assert_equal :v2, @client.iab_version
  end

  def test_dns_servers_setter
    default_dns = ['1.1.1.1', '1.0.0.1']
    assert_equal default_dns, @client.dns_servers

    custom_dns = ['8.8.8.8', '8.8.4.4']
    @client.dns_servers = custom_dns
    assert_equal custom_dns, @client.dns_servers
  end

  def test_request_timeout_setter
    assert_equal 10, @client.request_timeout

    @client.request_timeout = 30
    assert_equal 30, @client.request_timeout
  end

  def test_force_download_setter
    assert_equal false, @client.force_download

    @client.force_download = true
    assert_equal true, @client.force_download
  end

  def test_cache_dir_setter
    @client.cache_dir = '/tmp/test_cache'
    assert_equal '/tmp/test_cache', @client.cache_dir
  end

  def test_host_urls_setter
    custom_urls = {
      test_category: ['http://example.com/list.txt']
    }

    @client.host_urls = custom_urls
    assert_equal custom_urls, @client.host_urls
  end

  def test_auto_load_datasets_setter
    assert_equal false, @client.auto_load_datasets

    @client.auto_load_datasets = true
    assert_equal true, @client.auto_load_datasets
  end

  def test_smart_rules_setter
    custom_rules = {
      test_rule: {
        domains: ['test.com'],
        remove_categories: [:news]
      }
    }

    @client.smart_rules = custom_rules
    # NOTE: smart_rules getter includes default rules merged with custom ones
    assert @client.smart_rules[:test_rule]
    assert_equal ['test.com'], @client.smart_rules[:test_rule][:domains]
  end

  def test_attribute_defaults
    client = UrlCategorise::Client.new(host_urls: {})

    assert_equal({}, client.host_urls) # We set empty host_urls in initialization
    assert_equal false, client.force_download
    assert_equal ['1.1.1.1', '1.0.0.1'], client.dns_servers
    assert_equal 10, client.request_timeout
    assert_equal false, client.iab_compliance_enabled
    assert_equal :v3, client.iab_version
    assert_equal false, client.auto_load_datasets
    assert_equal false, client.smart_categorization_enabled
    assert_kind_of Hash, client.smart_rules
  end

  def test_default_initialization_uses_constants
    # Create a new client with no parameters to test defaults
    client = UrlCategorise::Client.new(host_urls: {})

    # We can't test DEFAULT_HOST_URLS because we override it, but we can test other defaults
    assert_equal false, client.force_download
    assert_equal ['1.1.1.1', '1.0.0.1'], client.dns_servers
    assert_equal 10, client.request_timeout
    assert_equal false, client.iab_compliance_enabled
    assert_equal :v3, client.iab_version
    assert_equal false, client.auto_load_datasets
    assert_equal false, client.smart_categorization_enabled
    assert_kind_of Hash, client.smart_rules
  end

  def test_initialization_with_custom_attributes
    custom_cache_dir = '/tmp/custom'
    custom_timeout = 25

    client = UrlCategorise::Client.new(
      host_urls: {},
      cache_dir: custom_cache_dir,
      request_timeout: custom_timeout,
      smart_categorization: true,
      iab_compliance: true
    )

    assert_equal custom_cache_dir, client.cache_dir
    assert_equal custom_timeout, client.request_timeout
    assert_equal true, client.smart_categorization_enabled
    assert_equal true, client.iab_compliance_enabled
  end

  def test_iab_compliant_method_reflects_attribute
    @client.iab_compliance_enabled = false
    assert_equal false, @client.iab_compliant?

    @client.iab_compliance_enabled = true
    assert_equal true, @client.iab_compliant?
  end

  def test_attribute_validation
    # Test that boolean attributes handle truthy/falsy values correctly
    @client.smart_categorization_enabled = 'true'
    assert_equal true, @client.smart_categorization_enabled

    @client.force_download = nil
    # ActiveAttr Boolean typecasting makes nil return nil, not false
    assert_nil @client.force_download

    @client.iab_compliance_enabled = 1
    assert_equal true, @client.iab_compliance_enabled
  end
end
