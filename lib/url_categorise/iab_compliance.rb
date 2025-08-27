module UrlCategorise
  module IabCompliance
    IAB_V2_MAPPINGS = {
      # Content Categories
      advertising: 'IAB3', # Advertising
      automotive: 'IAB2', # Automotive
      books_literature: 'IAB20', # Books & Literature
      business: 'IAB3', # Business
      careers: 'IAB4', # Careers
      education: 'IAB5', # Education
      entertainment: 'IAB1', # Arts & Entertainment
      finance: 'IAB13', # Personal Finance
      food_drink: 'IAB8', # Food & Drink
      health: 'IAB7', # Health & Fitness
      hobbies_interests: 'IAB9', # Hobbies & Interests
      home_garden: 'IAB10', # Home & Garden
      law_government: 'IAB11', # Law, Government & Politics
      news: 'IAB12', # News
      parenting: 'IAB6', # Family & Parenting
      pets: 'IAB16', # Pets
      philosophy: 'IAB21', # Philosophy/Religion
      real_estate: 'IAB21', # Real Estate
      science: 'IAB15', # Science
      shopping: 'IAB22', # Shopping
      sports: 'IAB17', # Sports
      style_fashion: 'IAB18', # Style & Fashion
      technology: 'IAB19', # Technology & Computing
      travel: 'IAB20', # Travel

      # Security & Malware Categories
      malware: 'IAB25', # Non-Standard Content (custom extension)
      phishing: 'IAB25', # Non-Standard Content (custom extension)
      gambling: 'IAB7-39', # Gambling
      pornography: 'IAB25-3', # Pornography
      violence: 'IAB25', # Non-Standard Content (custom extension)
      illegal: 'IAB25', # Non-Standard Content (custom extension)

      # Network & Security
      botnet_command_control: 'IAB25', # Non-Standard Content (custom extension)
      threat_intelligence: 'IAB25', # Non-Standard Content (custom extension)
      suspicious_domains: 'IAB25', # Non-Standard Content (custom extension)
      compromised_ips: 'IAB25', # Non-Standard Content (custom extension)
      tor_exit_nodes: 'IAB25', # Non-Standard Content (custom extension)

      # Social & Media
      social_media: 'IAB14', # Society
      streaming: 'IAB1-2', # Music
      video_hosting: 'IAB1-2', # Music (video hosting platforms)
      blogs: 'IAB14', # Society
      forums: 'IAB19', # Technology & Computing

      # Geographic/Language Specific
      chinese_ad_hosts: 'IAB3', # Advertising
      korean_ad_hosts: 'IAB3', # Advertising
      mobile_ads: 'IAB3', # Advertising
      smart_tv_ads: 'IAB3', # Advertising

      # Specialized
      newly_registered_domains: 'IAB25', # Non-Standard Content (custom extension)
      dns_over_https_bypass: 'IAB25', # Non-Standard Content (custom extension)
      sanctions_ips: 'IAB25', # Non-Standard Content (custom extension)
      cryptojacking: 'IAB25', # Non-Standard Content (custom extension)
      phishing_extended: 'IAB25' # Non-Standard Content (custom extension)
    }.freeze

    IAB_V3_MAPPINGS = {
      # Tier-1 Categories (IAB Content Taxonomy 3.0)
      advertising: '3', # Advertising
      automotive: '2', # Automotive
      books_literature: '20', # Books & Literature
      business: '3', # Business
      careers: '4', # Careers
      education: '5', # Education
      entertainment: '1', # Arts & Entertainment
      finance: '13', # Personal Finance
      food_drink: '8', # Food & Drink
      health: '7', # Health & Fitness & Wellness
      hobbies_interests: '9', # Hobbies & Interests
      home_garden: '10', # Home & Garden
      law_government: '11', # Law, Government & Politics
      news: '12', # News & Politics
      parenting: '6', # Family & Parenting
      pets: '16', # Pets
      philosophy: '21', # Philosophy/Religion & Spirituality
      real_estate: '21', # Real Estate
      science: '15', # Science
      shopping: '22', # Shopping
      sports: '17', # Sports
      style_fashion: '18', # Style & Fashion
      technology: '19', # Technology & Computing
      travel: '20', # Travel

      # Security & Malware Categories (Custom extensions)
      malware: '626', # Illegal Content (custom mapping)
      phishing: '626', # Illegal Content (custom mapping)
      gambling: '7-39', # Gambling (subcategory)
      pornography: '626', # Adult Content
      violence: '626', # Illegal Content (custom mapping)
      illegal: '626', # Illegal Content

      # Network & Security (Custom extensions)
      botnet_command_control: '626', # Illegal Content (custom mapping)
      threat_intelligence: '626', # Illegal Content (custom mapping)
      suspicious_domains: '626', # Illegal Content (custom mapping)
      compromised_ips: '626', # Illegal Content (custom mapping)
      tor_exit_nodes: '626', # Illegal Content (custom mapping)

      # Social & Media
      social_media: '14', # Society
      streaming: '1-2', # Music & Audio
      video_hosting: '1-2', # Music & Audio (video hosting platforms)
      blogs: '14', # Society
      forums: '19', # Technology & Computing

      # Geographic/Language Specific
      chinese_ad_hosts: '3', # Advertising
      korean_ad_hosts: '3', # Advertising
      mobile_ads: '3', # Advertising
      smart_tv_ads: '3', # Advertising

      # Specialized
      newly_registered_domains: '626', # Illegal Content (custom mapping)
      dns_over_https_bypass: '626', # Illegal Content (custom mapping)
      sanctions_ips: '626', # Illegal Content (custom mapping)
      cryptojacking: '626', # Illegal Content (custom mapping)
      phishing_extended: '626' # Illegal Content (custom mapping)
    }.freeze

    def self.map_category_to_iab(category, version = :v3)
      category_sym = category.to_sym
      mapping = version == :v2 ? IAB_V2_MAPPINGS : IAB_V3_MAPPINGS
      mapping[category_sym] || 'Unknown'
    end

    def self.get_iab_categories(categories, version = :v3)
      categories.map { |cat| map_category_to_iab(cat, version) }.uniq
    end

    def self.supported_versions
      %i[v2 v3]
    end

    def self.category_exists?(category, version = :v3)
      category_sym = category.to_sym
      mapping = version == :v2 ? IAB_V2_MAPPINGS : IAB_V3_MAPPINGS
      mapping.key?(category_sym)
    end
  end
end
