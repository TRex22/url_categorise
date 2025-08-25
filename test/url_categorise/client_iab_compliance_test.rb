require 'test_helper'

class UrlCategoriseClientIabComplianceTest < Minitest::Test
  def setup
    WebMock.stub_request(:get, 'http://example.com/malware.txt')
           .to_return(body: "0.0.0.0 badsite.com\n0.0.0.0 evilsite.com")
    WebMock.stub_request(:get, 'http://example.com/ads.txt')
           .to_return(body: "0.0.0.0 adsite1.com\n0.0.0.0 adsite2.com")
    WebMock.stub_request(:get, 'http://example.com/gambling.txt')
           .to_return(body: '0.0.0.0 casino.com')

    @test_host_urls = {
      malware: ['http://example.com/malware.txt'],
      advertising: ['http://example.com/ads.txt'],
      gambling: ['http://example.com/gambling.txt']
    }
  end

  def test_client_initialization_without_iab_compliance
    client = UrlCategorise::Client.new(host_urls: @test_host_urls)

    refute client.iab_compliant?
    assert_equal :v3, client.iab_version # Default version
  end

  def test_client_initialization_with_iab_compliance_v2
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v2
    )

    assert client.iab_compliant?
    assert_equal :v2, client.iab_version
  end

  def test_client_initialization_with_iab_compliance_v3
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v3
    )

    assert client.iab_compliant?
    assert_equal :v3, client.iab_version
  end

  def test_client_initialization_with_iab_compliance_default_version
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true
    )

    assert client.iab_compliant?
    assert_equal :v3, client.iab_version # Should default to v3
  end

  def test_categorise_without_iab_compliance
    client = UrlCategorise::Client.new(host_urls: @test_host_urls)

    categories = client.categorise('http://badsite.com')
    assert_includes categories, :malware
    refute_includes categories, 'IAB25'
    refute_includes categories, '626'
  end

  def test_categorise_with_iab_compliance_v2
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v2
    )

    categories = client.categorise('http://badsite.com')
    assert_includes categories, 'IAB25' # v2 mapping for malware
    refute_includes categories, :malware
  end

  def test_categorise_with_iab_compliance_v3
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v3
    )

    categories = client.categorise('http://badsite.com')
    assert_includes categories, '626' # v3 mapping for malware
    refute_includes categories, :malware
  end

  def test_categorise_multiple_categories_iab_v2
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v2
    )

    # Create a host that matches multiple categories
    client.instance_variable_get(:@hosts)[:advertising] << 'multisite.com'
    client.instance_variable_get(:@hosts)[:malware] << 'multisite.com'

    categories = client.categorise('http://multisite.com')
    assert_includes categories, 'IAB3'  # advertising
    assert_includes categories, 'IAB25' # malware
    assert_equal 2, categories.length
  end

  def test_categorise_multiple_categories_iab_v3
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v3
    )

    # Create a host that matches multiple categories
    client.instance_variable_get(:@hosts)[:advertising] << 'multisite.com'
    client.instance_variable_get(:@hosts)[:malware] << 'multisite.com'

    categories = client.categorise('http://multisite.com')
    assert_includes categories, '3'   # advertising
    assert_includes categories, '626' # malware
    assert_equal 2, categories.length
  end

  def test_categorise_ip_without_iab_compliance
    client = UrlCategorise::Client.new(host_urls: @test_host_urls)

    # Add IP to malware list
    client.instance_variable_get(:@hosts)[:malware] << '192.168.1.100'

    categories = client.categorise_ip('192.168.1.100')
    assert_includes categories, :malware
    refute_includes categories, 'IAB25'
  end

  def test_categorise_ip_with_iab_compliance_v2
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v2
    )

    # Add IP to malware list
    client.instance_variable_get(:@hosts)[:malware] << '192.168.1.100'

    categories = client.categorise_ip('192.168.1.100')
    assert_includes categories, 'IAB25'
    refute_includes categories, :malware
  end

  def test_categorise_ip_with_iab_compliance_v3
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v3
    )

    # Add IP to malware list
    client.instance_variable_get(:@hosts)[:malware] << '192.168.1.100'

    categories = client.categorise_ip('192.168.1.100')
    assert_includes categories, '626'
    refute_includes categories, :malware
  end

  def test_resolve_and_categorise_with_iab_compliance
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v3
    )

    # Mock DNS resolution to avoid actual network calls
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :getaddresses, [IPAddr.new('192.168.1.100')], ['badsite.com']

    Resolv::DNS.stub :new, mock_resolver do
      # Add IP to malware list so both domain and IP categorization return malware
      client.instance_variable_get(:@hosts)[:malware] << '192.168.1.100'

      categories = client.resolve_and_categorise('badsite.com')
      assert_includes categories, '626' # Should get IAB code for malware
      refute_includes categories, :malware
    end

    mock_resolver.verify
  end

  def test_get_iab_mapping_when_disabled
    client = UrlCategorise::Client.new(host_urls: @test_host_urls)

    mapping = client.get_iab_mapping(:malware)
    assert_nil mapping
  end

  def test_get_iab_mapping_when_enabled_v2
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v2
    )

    mapping = client.get_iab_mapping(:malware)
    assert_equal 'IAB25', mapping
  end

  def test_get_iab_mapping_when_enabled_v3
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v3
    )

    mapping = client.get_iab_mapping(:malware)
    assert_equal '626', mapping
  end

  def test_iab_compliant_method
    non_compliant_client = UrlCategorise::Client.new(host_urls: @test_host_urls)
    refute non_compliant_client.iab_compliant?

    compliant_client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true
    )
    assert compliant_client.iab_compliant?
  end

  def test_categorise_unknown_category_with_iab_compliance
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v3
    )

    # Add an unknown category
    client.instance_variable_get(:@hosts)[:unknown_category] = ['unknown.com']

    categories = client.categorise('http://unknown.com')
    assert_includes categories, 'Unknown'
  end

  def test_iab_compliance_removes_duplicates
    client = UrlCategorise::Client.new(
      host_urls: @test_host_urls,
      iab_compliance: true,
      iab_version: :v3
    )

    # Add same host to business and advertising (both map to '3' in v3)
    client.instance_variable_get(:@hosts)[:advertising] << 'business-ad.com'
    client.instance_variable_get(:@hosts)[:business] = ['business-ad.com']

    categories = client.categorise('http://business-ad.com')
    assert_equal ['3'], categories # Should only have one '3' despite two categories mapping to it
  end
end
