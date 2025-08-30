module UrlCategorise
  module Constants
    ONE_MEGABYTE = 1_048_576

    # Video URL patterns for detecting video content
    VIDEO_URL_PATTERNS_FILE = "https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_url_patterns.txt".freeze

    # crawler data
    # https://commoncrawl.org/

    # Usually used to train deep models. Using directly here
    CATEGORIY_DATABASES = [
      { type: :kaggle, path: "shaurov/website-classification-using-url" },
      { type: :kaggle, path: "hetulmehta/website-classification" },
      { type: :kaggle, path: "shawon10/url-classification-dataset-dmoz" },
      { type: :csv, path: "https://query.data.world/s/zackomeddpgotrp3yel66aphvvlcuq?dws=00000" }
    ]

    DEFAULT_HOST_URLS = {
      abuse: [ "https://github.com/blocklistproject/Lists/raw/master/abuse.txt" ],
      adobe: [ "https://github.com/blocklistproject/Lists/raw/master/adobe.txt" ],
      adult: %i[pornography dating_services drugs gambling],
      advertising: [ "https://blocklistproject.github.io/Lists/ads.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-advert_01.txt" ],
      amazon: [ "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/amazon/all" ],
      amp_hosts: [ "https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt" ],
      apple: [ "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/apple/all" ],
      cloudflare: [ "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/cloudflare/all" ],
      crypto: [ "https://github.com/blocklistproject/Lists/raw/master/crypto.txt", "https://v.firebog.net/hosts/Prigent-Crypto.txt" ],
      dating_services: [ "https://www.github.developerdan.com/hosts/lists/dating-services-extended.txt" ],
      drugs: [ "https://github.com/blocklistproject/Lists/raw/master/drugs.txt" ],
      facebook: [ "https://github.com/blocklistproject/Lists/raw/master/facebook.txt",
                 "https://www.github.developerdan.com/hosts/lists/facebook-extended.txt", "https://raw.githubusercontent.com/blocklistproject/Lists/master/facebook.txt", "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/facebook/all", "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/facebook/facebook.com" ],
      fraud: [ "https://blocklistproject.github.io/Lists/fraud.txt" ],
      gambling: [ "https://blocklistproject.github.io/Lists/gambling.txt", "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.txt" ],
      gaming: [ "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-ubisoft.txt",
               "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-steam.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-activision.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-blizzard.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-ea.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-epicgames.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-nintendo.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-rockstargames.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-roblox.txt" ],
      google: [ "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/google/all" ],
      hate_and_junk: [ "https://www.github.developerdan.com/hosts/lists/hate-and-junk-extended.txt" ],
      instagram: [ "https://github.com/jmdugan/blocklists/raw/master/corporations/facebook/instagram" ],
      linkedin: [ "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/microsoft/linkedin" ],
      malware: [ "https://blocklistproject.github.io/Lists/malware.txt",
                "https://feodotracker.abuse.ch/downloads/ipblocklist.txt", "https://sslbl.abuse.ch/blacklist/sslipblacklist.txt" ],
      microsoft: [ "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/microsoft/all" ],
      mozilla: [ "https://github.com/jmdugan/blocklists/raw/master/corporations/mozilla/all" ],
      nsa: [ "https://raw.githubusercontent.com/tigthor/NSA-CIA-Blocklist/main/HOSTS/HOSTS" ],
      phishing: [ "https://blocklistproject.github.io/Lists/phishing.txt", "https://openphish.com/feed.txt" ],
      pinterest: [ "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/pinterest/all" ],
      piracy: [ "https://github.com/blocklistproject/Lists/raw/master/piracy.txt", "https://github.com/hagezi/dns-blocklists/raw/refs/heads/main/adblock/anti.piracy.txt" ],
      pornography: [ "https://blocklistproject.github.io/Lists/porn.txt", "https://v.firebog.net/hosts/Prigent-Adult.txt" ],
      reddit: [ "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-reddit.txt" ],
      redirect: [ "https://github.com/blocklistproject/Lists/raw/master/redirect.txt" ],
      scam: [ "https://blocklistproject.github.io/Lists/scam.txt" ],
      smart_tv: [ "https://github.com/blocklistproject/Lists/raw/master/smart-tv.txt" ],
      social_media: %i[facebook instagram linkedin pinterest reddit tiktok twitter whatsapp youtube],
      tiktok: [ "https://blocklistproject.github.io/Lists/tiktok.txt" ],
      torrent: [ "https://github.com/blocklistproject/Lists/raw/master/torrent.txt" ],
      tracking: [ "https://blocklistproject.github.io/Lists/tracking.txt" ],
      twitter: [ "https://github.com/blocklistproject/Lists/raw/master/twitter.txt", "https://github.com/jmdugan/blocklists/raw/master/corporations/twitter/all" ],
      vaping: [ "https://github.com/blocklistproject/Lists/raw/master/vaping.txt" ],
      video: [ "https://raw.githubusercontent.com/wilwade/pihole-block-video/master/hosts.txt" ],
      video_hosting: [ "https://raw.githubusercontent.com/TRex22/url_categorise/refs/heads/main/lists/video_hosting_domains.hosts" ],
      whatsapp: [ "https://github.com/blocklistproject/Lists/raw/master/whatsapp.txt", "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/facebook/whatsapp" ],
      youtube: [ "https://github.com/blocklistproject/Lists/raw/master/youtube.txt", "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/google/youtube" ],

      # Hagezi DNS Blocklists - specialized categories only
      threat_intelligence: [ "https://github.com/hagezi/dns-blocklists/raw/refs/heads/main/ips/tif.txt" ],
      dyndns: [ "https://github.com/hagezi/dns-blocklists/raw/refs/heads/main/adblock/dyndns.txt" ],
      badware_hoster: [ "https://github.com/hagezi/dns-blocklists/raw/refs/heads/main/adblock/hoster.txt" ],
      most_abused_tlds: [ "https://github.com/hagezi/dns-blocklists/raw/refs/heads/main/adblock/spam-tlds.txt" ],
      newly_registered_domains: [ "https://github.com/xRuffKez/NRD/raw/refs/heads/main/lists/14-day/adblock/nrd-14day_adblock.txt" ],
      dns_over_https_bypass: [ "https://github.com/hagezi/dns-blocklists/raw/refs/heads/main/adblock/doh-vpn-proxy-bypass.txt" ],

      # StevenBlack hosts lists - specific categories only
      fakenews: [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts", "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts" ],

      # Security threat lists
      threat_indicators: [ "https://threatfox.abuse.ch/downloads/hostfile.txt" ],

      # Additional IP-based sanctions and abuse lists
      sanctions_ips: [ "https://lists.blocklist.de/lists/all.txt" ],
      compromised_ips: [ "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt" ],
      tor_exit_nodes: [ "https://www.dan.me.uk/torlist/" ],
      open_proxy_ips: [ "https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt" ],

      # Network security feeds
      top_attack_sources: [ "https://www.dshield.org/feeds/suspiciousdomains_High.txt" ],
      suspicious_domains: [ "https://www.dshield.org/feeds/suspiciousdomains_Medium.txt" ],

      # Extended categories for better organisation
      cryptojacking: [ "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt" ],

      # Regional and specialized lists
      chinese_ad_hosts: [ "https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts" ],
      korean_ad_hosts: [ "https://raw.githubusercontent.com/yous/YousList/master/hosts.txt" ],

      # Mobile and app-specific
      mobile_ads: [ "https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/MobileFilter/sections/adservers.txt" ],
      smart_tv_ads: [ "https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV-AGH.txt" ],

      # Content and informational categories
      # news: [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts" ],
      # NOTE: The following categories had broken URLs and have been commented out:
      # legitimate_news: URLs from mitchellkrogza repository return 404
      # blogs, forums, health, finance, streaming, shopping: blocklistproject alt-version URLs return 404
      # educational: StevenBlack educational hosts URL returns 404
      # government: mitchellkrogza government domains URL returns 404
      # business, technology: blocklistproject alt-version URLs return 404
      # local_news, international_news: blocklistproject alt-version URLs return 404
    }
  end
end
