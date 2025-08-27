require "httparty"
require "nokogiri"
require "digest"
require "fileutils"
require "resolv"
require "active_attr"

require "api-pattern"

require "url_categorise/version"
require "url_categorise/constants"
require "url_categorise/dataset_processor"
require "url_categorise/iab_compliance"

require "url_categorise/client"

# Optional ActiveRecord integration
begin
  require "url_categorise/models"
  require "url_categorise/active_record_client"
rescue LoadError
  # ActiveRecord not available, skip
end

module UrlCategorise
  class Error < StandardError; end
end
