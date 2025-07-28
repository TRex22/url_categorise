module UrlCategorise
  module Constants
    ONE_MEGABYTE = 1048576
    DEFAULT_HOST_URLS = {
      abuse: ["https://github.com/blocklistproject/Lists/raw/master/abuse.txt"],
      adobe: ["https://github.com/blocklistproject/Lists/raw/master/adobe.txt"],
      advertising: ["https://blocklistproject.github.io/Lists/ads.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-advert_01.txt"],
      amazon: ["https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/amazon/all"],
      amp_hosts: ["https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt"],
      apple: ["https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/apple/all"],
      cloudflare: ["https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/cloudflare/all"],
      crypto: ["https://github.com/blocklistproject/Lists/raw/master/crypto.txt"],
      dating_services: ["https://www.github.developerdan.com/hosts/lists/dating-services-extended.txt"],
      drugs: ["https://github.com/blocklistproject/Lists/raw/master/drugs.txt"],
      facebook: ["https://github.com/blocklistproject/Lists/raw/master/facebook.txt", "https://www.github.developerdan.com/hosts/lists/facebook-extended.txt", "https://raw.githubusercontent.com/blocklistproject/Lists/master/facebook.txt", "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/facebook/all", "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/facebook/facebook.com"],
      fraud: ["https://blocklistproject.github.io/Lists/fraud.txt"],
      gambling: ["https://blocklistproject.github.io/Lists/gambling.txt", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release/adblock/gambling.txt"],
      gaming: ["https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-ubisoft.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-steam.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-activision.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-blizzard.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-ea.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-epicgames.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-nintendo.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-rockstargames.txt", "https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-roblox.txt"],
      google: ["https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/google/all"],
      hate_and_junk: ["https://www.github.developerdan.com/hosts/lists/hate-and-junk-extended.txt"],
      instagram: ["https://github.com/jmdugan/blocklists/raw/master/corporations/facebook/instagram"],
      linkedin: ["https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/microsoft/linkedin"],
      malware: ["https://blocklistproject.github.io/Lists/malware.txt", "http://www.malwaredomainlist.com/hostslist/hosts.txt"],
      microsoft: ["https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/microsoft/all"],
      mozilla: ["https://github.com/jmdugan/blocklists/raw/master/corporations/mozilla/all"],
      nsa: ["https://raw.githubusercontent.com/tigthor/NSA-CIA-Blocklist/main/HOSTS/HOSTS"],
      phishing: ["https://blocklistproject.github.io/Lists/phishing.txt"],
      pinterest: ["https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/pinterest/all"],
      piracy: ["https://github.com/blocklistproject/Lists/raw/master/piracy.txt", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release/adblock/anti.piracy.txt"],
      pornography: ["https://blocklistproject.github.io/Lists/porn.txt"],
      reddit: ["https://raw.githubusercontent.com/nickoppen/pihole-blocklists/master/blocklist-reddit.txt"],
      redirect: ["https://github.com/blocklistproject/Lists/raw/master/redirect.txt"],
      scam: ["https://blocklistproject.github.io/Lists/scam.txt"],
      smart_tv: ["https://github.com/blocklistproject/Lists/raw/master/smart-tv.txt"],
      social_media: [:facebook, :instagram, :linkedin, :pinterest, :reddit, :tiktok, :twitter, :whatsapp, :youtube],
      tiktok: ["https://blocklistproject.github.io/Lists/tiktok.txt"],
      torrent: ["https://github.com/blocklistproject/Lists/raw/master/torrent.txt"],
      tracking: ["https://blocklistproject.github.io/Lists/tracking.txt"],
      twitter: ["https://github.com/blocklistproject/Lists/raw/master/twitter.txt", "https://github.com/jmdugan/blocklists/raw/master/corporations/twitter/all"],
      vaping: ["https://github.com/blocklistproject/Lists/raw/master/vaping.txt"],
      whatsapp: ["https://github.com/blocklistproject/Lists/raw/master/whatsapp.txt", "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/facebook/whatsapp"],
      youtube: ["https://github.com/blocklistproject/Lists/raw/master/youtube.txt", "https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/google/youtube"],
      
      # Hagezi DNS Blocklists - specialized categories only
      threat_intelligence: ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release/adblock/tif.txt"],
      dyndns: ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release/adblock/dyndns.txt"],
      badware_hoster: ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release/adblock/hoster.txt"],
      most_abused_tlds: ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release/adblock/tlds.txt"],
      newly_registered_domains: ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release/adblock/nrd.txt"],
      doh_vpn_proxy_bypass: ["https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@release/adblock/doh-vpn-proxy-bypass.txt"],
      
      # StevenBlack hosts lists - specific categories only
      fakenews: ["https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts"],
      
      # Known abuse IP lists
      abuse_ch_feodo: ["https://feodotracker.abuse.ch/downloads/ipblocklist.txt"],
      abuse_ch_malware_bazaar: ["https://bazaar.abuse.ch/downloads/domain_blocklist.txt"],
      abuse_ch_ssl_blacklist: ["https://sslbl.abuse.ch/blacklist/sslipblacklist.txt"],
      abuse_ch_threat_fox: ["https://threatfox.abuse.ch/downloads/hostfile.txt"],
      
      # Additional IP-based sanctions and abuse lists
      sanctions_ips: ["https://lists.blocklist.de/lists/all.txt"],
      compromised_ips: ["https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"],
      tor_exit_nodes: ["https://www.dan.me.uk/torlist/"],
      open_proxy_ips: ["https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt"],
      
      # DShield suspicious IPs
      dshield_top_attackers: ["https://www.dshield.org/feeds/suspiciousdomains_High.txt"],
      dshield_block_list: ["https://www.dshield.org/feeds/suspiciousdomains_Medium.txt"],
      
      # Extended categories for better organization
      cryptojacking: ["https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt"],
      ransomware: ["https://ransomwaretracker.abuse.ch/downloads/RW_DOMBL.txt"],
      botnet_c2: ["https://osint.bambenekconsulting.com/feeds/c2-dommasterlist.txt"],
      phishing_extended: ["https://openphish.com/feed.txt"],
      
      # Regional and specialized lists
      chinese_ad_hosts: ["https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts"],
      korean_ad_hosts: ["https://raw.githubusercontent.com/yous/YousList/master/hosts.txt"],
      
      # Mobile and app-specific
      mobile_ads: ["https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/MobileFilter/sections/adservers.txt"],
      smart_tv_ads: ["https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV-AGH.txt"],
    }
  end
end
