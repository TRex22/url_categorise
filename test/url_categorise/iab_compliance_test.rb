require "test_helper"

class UrlCategoriseIabComplianceTest < Minitest::Test
  def test_iab_v2_mappings_constant_exists
    assert defined?(UrlCategorise::IabCompliance::IAB_V2_MAPPINGS)
    assert_instance_of Hash, UrlCategorise::IabCompliance::IAB_V2_MAPPINGS
    refute_empty UrlCategorise::IabCompliance::IAB_V2_MAPPINGS
  end

  def test_iab_v3_mappings_constant_exists
    assert defined?(UrlCategorise::IabCompliance::IAB_V3_MAPPINGS)
    assert_instance_of Hash, UrlCategorise::IabCompliance::IAB_V3_MAPPINGS
    refute_empty UrlCategorise::IabCompliance::IAB_V3_MAPPINGS
  end

  def test_map_category_to_iab_v2
    assert_equal "IAB3", UrlCategorise::IabCompliance.map_category_to_iab(:advertising, :v2)
    assert_equal "IAB7-39", UrlCategorise::IabCompliance.map_category_to_iab(:gambling, :v2)
    assert_equal "IAB25", UrlCategorise::IabCompliance.map_category_to_iab(:malware, :v2)
  end

  def test_map_category_to_iab_v3
    assert_equal "3", UrlCategorise::IabCompliance.map_category_to_iab(:advertising, :v3)
    assert_equal "7-39", UrlCategorise::IabCompliance.map_category_to_iab(:gambling, :v3)
    assert_equal "626", UrlCategorise::IabCompliance.map_category_to_iab(:malware, :v3)
  end

  def test_map_category_to_iab_defaults_to_v3
    assert_equal "3", UrlCategorise::IabCompliance.map_category_to_iab(:advertising)
  end

  def test_map_category_to_iab_unknown_category
    assert_equal "Unknown", UrlCategorise::IabCompliance.map_category_to_iab(:nonexistent_category)
    assert_equal "Unknown", UrlCategorise::IabCompliance.map_category_to_iab(:nonexistent_category, :v2)
  end

  def test_get_iab_categories_v2
    categories = %i[advertising gambling malware]
    expected = %w[IAB3 IAB7-39 IAB25]
    assert_equal expected, UrlCategorise::IabCompliance.get_iab_categories(categories, :v2)
  end

  def test_get_iab_categories_v3
    categories = %i[advertising gambling malware]
    expected = %w[3 7-39 626]
    assert_equal expected, UrlCategorise::IabCompliance.get_iab_categories(categories, :v3)
  end

  def test_get_iab_categories_defaults_to_v3
    categories = %i[advertising gambling]
    expected = %w[3 7-39]
    assert_equal expected, UrlCategorise::IabCompliance.get_iab_categories(categories)
  end

  def test_get_iab_categories_removes_duplicates
    categories = %i[advertising advertising business] # business also maps to '3' in v3
    result = UrlCategorise::IabCompliance.get_iab_categories(categories, :v3)
    assert_equal [ "3" ], result.uniq
    assert_equal result.uniq, result
  end

  def test_get_iab_categories_with_unknown_categories
    categories = %i[advertising unknown_category gambling]
    expected = %w[3 Unknown 7-39]
    assert_equal expected, UrlCategorise::IabCompliance.get_iab_categories(categories, :v3)
  end

  def test_supported_versions
    expected_versions = %i[v2 v3]
    assert_equal expected_versions, UrlCategorise::IabCompliance.supported_versions
  end

  def test_category_exists_v2
    assert UrlCategorise::IabCompliance.category_exists?(:advertising, :v2)
    assert UrlCategorise::IabCompliance.category_exists?(:malware, :v2)
    refute UrlCategorise::IabCompliance.category_exists?(:nonexistent_category, :v2)
  end

  def test_category_exists_v3
    assert UrlCategorise::IabCompliance.category_exists?(:advertising, :v3)
    assert UrlCategorise::IabCompliance.category_exists?(:malware, :v3)
    refute UrlCategorise::IabCompliance.category_exists?(:nonexistent_category, :v3)
  end

  def test_category_exists_defaults_to_v3
    assert UrlCategorise::IabCompliance.category_exists?(:advertising)
    refute UrlCategorise::IabCompliance.category_exists?(:nonexistent_category)
  end

  def test_string_to_symbol_conversion
    assert_equal "3", UrlCategorise::IabCompliance.map_category_to_iab("advertising", :v3)
    assert UrlCategorise::IabCompliance.category_exists?("advertising", :v3)
  end

  def test_comprehensive_category_mappings_v2
    # Test a comprehensive set of categories for v2
    test_cases = {
      advertising: "IAB3",
      automotive: "IAB2",
      books_literature: "IAB20",
      business: "IAB3",
      careers: "IAB4",
      education: "IAB5",
      entertainment: "IAB1",
      finance: "IAB13",
      food_drink: "IAB8",
      health: "IAB7",
      gambling: "IAB7-39",
      pornography: "IAB25-3",
      malware: "IAB25",
      phishing: "IAB25"
    }

    test_cases.each do |category, expected_iab|
      assert_equal expected_iab, UrlCategorise::IabCompliance.map_category_to_iab(category, :v2),
                   "Category #{category} should map to #{expected_iab} in v2"
    end
  end

  def test_comprehensive_category_mappings_v3
    # Test a comprehensive set of categories for v3
    test_cases = {
      advertising: "3",
      automotive: "2",
      books_literature: "20",
      business: "3",
      careers: "4",
      education: "5",
      entertainment: "1",
      finance: "13",
      food_drink: "8",
      health: "7",
      gambling: "7-39",
      pornography: "626",
      malware: "626",
      phishing: "626"
    }

    test_cases.each do |category, expected_iab|
      assert_equal expected_iab, UrlCategorise::IabCompliance.map_category_to_iab(category, :v3),
                   "Category #{category} should map to #{expected_iab} in v3"
    end
  end
end
