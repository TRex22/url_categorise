module UrlCategorise
  module Constants
    # Resources used:
    # https://blocklist.site/#
    # https://github.com/lightswitch05/hosts
    #
    DEFAULT_HOST_URLS = {
      advertising: ["https://blocklistproject.github.io/Lists/ads.txt"],
      amp_hosts: ["https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt"],
      dating_services: ["https://www.github.developerdan.com/hosts/lists/dating-services-extended.txt"],
      facebook: ["https://github.com/blocklistproject/Lists/raw/master/facebook.txt", "https://www.github.developerdan.com/hosts/lists/facebook-extended.txt", "https://raw.githubusercontent.com/blocklistproject/Lists/master/facebook.txt"],
      fraud: ["https://blocklistproject.github.io/Lists/fraud.txt"],
      gambling: ["https://blocklistproject.github.io/Lists/gambling.txt"],
      hate: [],
      junk: [],
      malware: ["https://blocklistproject.github.io/Lists/malware.txt"],
      phishing: ["https://blocklistproject.github.io/Lists/phishing.txt"],
      pornography: ["https://blocklistproject.github.io/Lists/porn.txt"],
      scam: ["https://blocklistproject.github.io/Lists/scam.txt"],
      tiktok: ["https://blocklistproject.github.io/Lists/tiktok.txt"],
      tracking: ["https://blocklistproject.github.io/Lists/tracking.txt"],
      twitter: ["https://github.com/blocklistproject/Lists/raw/master/twitter.txt"],
      vaping: ["https://github.com/blocklistproject/Lists/raw/master/vaping.txt"],
      whatsapp: ["https://github.com/blocklistproject/Lists/raw/master/whatsapp.txt"],
      youtube: ["https://github.com/blocklistproject/Lists/raw/master/youtube.txt"],
      torrent: ["https://github.com/blocklistproject/Lists/raw/master/torrent.txt"],
      smart_tv: ["https://github.com/blocklistproject/Lists/raw/master/smart-tv.txt"],
      redirect: ["https://github.com/blocklistproject/Lists/raw/master/redirect.txt"],
      piracy: ["https://github.com/blocklistproject/Lists/raw/master/piracy.txt"],
      drugs: ["https://github.com/blocklistproject/Lists/raw/master/drugs.txt"],
      crypto: ["https://github.com/blocklistproject/Lists/raw/master/crypto.txt"],
      adobe: ["https://github.com/blocklistproject/Lists/raw/master/adobe.txt"],
      abuse: ["https://github.com/blocklistproject/Lists/raw/master/abuse.txt"],
    }
  end
end
