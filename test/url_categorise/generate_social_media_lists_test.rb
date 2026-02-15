require "test_helper"
require "tmpdir"
require "fileutils"

# Load the generator module
load File.expand_path("../../bin/generate_social_media_lists", __dir__)

class GenerateSocialMediaListsTest < Minitest::Test
  def setup
    WebMock.reset!
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_generator_creates_hosts_file_with_manual_domains_when_api_fails
    # Mock the Mr.Holmes API to fail
    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Internal Server Error")

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    assert File.exist?(hosts_file), "Hosts file should be created"

    content = File.read(hosts_file)

    # Check header
    assert_match(/Social Media Domains/, content)
    assert_match(/PiHole Compatible/, content)
    assert_match(/Mr\.Holmes/, content)

    # Check core social media domains are present
    assert_match(/0\.0\.0\.0 facebook\.com/, content)
    assert_match(/0\.0\.0\.0 instagram\.com/, content)
    assert_match(/0\.0\.0\.0 twitter\.com/, content)
    assert_match(/0\.0\.0\.0 tiktok\.com/, content)
    assert_match(/0\.0\.0\.0 linkedin\.com/, content)
    assert_match(/0\.0\.0\.0 reddit\.com/, content)
    assert_match(/0\.0\.0\.0 mastodon\.social/, content)
    assert_match(/0\.0\.0\.0 discord\.com/, content)
    assert_match(/0\.0\.0\.0 threads\.net/, content)

    # Check www variants are generated
    assert_match(/0\.0\.0\.0 www\.facebook\.com/, content)
    assert_match(/0\.0\.0\.0 www\.twitter\.com/, content)
  end

  def test_generator_processes_mr_holmes_data
    mr_holmes_data = [
      {
        "TestPlatform" => {
          "Error" => "Status-Code",
          "name" => "TestPlatform",
          "main" => "testplatform.com",
          "user" => "https://testplatform.com/{}",
          "user2" => "https://testplatform.com/{}",
          "Tag" => ["Social"]
        },
        "AnotherSite" => {
          "Error" => "Status-Code",
          "name" => "AnotherSite",
          "main" => "anothersite.org",
          "user" => "https://anothersite.org/users/{}",
          "user2" => "https://anothersite.org/users/{}",
          "Tag" => ["Forum"]
        }
      }
    ]

    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 200, body: JSON.generate(mr_holmes_data))

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    content = File.read(hosts_file)

    # Check Mr.Holmes domains are included
    assert_match(/0\.0\.0\.0 testplatform\.com/, content)
    assert_match(/0\.0\.0\.0 anothersite\.org/, content)
  end

  def test_generator_handles_malformed_json
    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 200, body: "not valid json{{{")

    generator = SocialMediaListGenerator::SiteParser.new
    # Should not raise, falls back to manual domains
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    assert File.exist?(hosts_file), "Hosts file should still be created"

    content = File.read(hosts_file)
    assert_match(/0\.0\.0\.0 facebook\.com/, content)
  end

  def test_generator_filters_invalid_domains
    mr_holmes_data = [
      {
        "Valid" => {
          "name" => "Valid",
          "main" => "valid-site.com",
          "user" => "https://valid-site.com/{}",
          "user2" => "https://valid-site.com/{}",
          "Tag" => ["Social"]
        },
        "Invalid" => {
          "name" => "Invalid",
          "main" => "localhost",
          "user" => "https://localhost/{}",
          "user2" => "https://localhost/{}",
          "Tag" => ["Test"]
        },
        "TooShort" => {
          "name" => "TooShort",
          "main" => "a.b",
          "user" => "https://a.b/{}",
          "user2" => "https://a.b/{}",
          "Tag" => ["Test"]
        },
        "Example" => {
          "name" => "Example",
          "main" => "example.com",
          "user" => "https://example.com/{}",
          "user2" => "https://example.com/{}",
          "Tag" => ["Test"]
        }
      }
    ]

    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 200, body: JSON.generate(mr_holmes_data))

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    content = File.read(hosts_file)

    # Valid domain should be present
    assert_match(/0\.0\.0\.0 valid-site\.com/, content)

    # Invalid domains should be filtered out
    refute_match(/0\.0\.0\.0 localhost/, content)
    refute_match(/0\.0\.0\.0 example\.com/, content)
  end

  def test_generator_creates_lists_directory
    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    assert Dir.exist?(File.join(@tmpdir, "lists")), "lists directory should be created"
  end

  def test_generator_deduplicates_domains
    # Mr.Holmes data that overlaps with manual domains
    mr_holmes_data = [
      {
        "Facebook" => {
          "name" => "Facebook",
          "main" => "facebook.com",
          "user" => "https://facebook.com/{}",
          "user2" => "https://facebook.com/{}",
          "Tag" => ["Social"]
        }
      }
    ]

    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 200, body: JSON.generate(mr_holmes_data))

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    content = File.read(hosts_file)

    # Count occurrences of facebook.com (should appear only once as a non-www entry)
    non_www_matches = content.scan(/^0\.0\.0\.0 facebook\.com$/)
    assert_equal 1, non_www_matches.length, "facebook.com should appear exactly once"
  end

  def test_generator_sorts_base_domains_alphabetically
    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    lines = File.readlines(hosts_file).reject { |l| l.start_with?("#") || l.strip.empty? }
    domains = lines.map { |l| l.strip.split(" ").last }

    # Extract base domains (non-www) and verify they are sorted
    # The file uses the pattern: domain, www.domain pairs from sorted set
    base_domains = domains.reject { |d| d.start_with?("www.") }
    assert_equal base_domains.sort, base_domains, "Base domains should be sorted alphabetically"
  end

  def test_generator_includes_messaging_platforms
    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    content = File.read(hosts_file)

    assert_match(/0\.0\.0\.0 slack\.com/, content)
    assert_match(/0\.0\.0\.0 telegram\.org/, content)
    assert_match(/0\.0\.0\.0 whatsapp\.com/, content)
    assert_match(/0\.0\.0\.0 messenger\.com/, content)
  end

  def test_generator_includes_developer_platforms
    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    content = File.read(hosts_file)

    assert_match(/0\.0\.0\.0 github\.com/, content)
    assert_match(/0\.0\.0\.0 gitlab\.com/, content)
    assert_match(/0\.0\.0\.0 stackoverflow\.com|0\.0\.0\.0 bitbucket\.org/, content)
  end

  def test_generator_cleans_mr_holmes_domains_with_protocols
    mr_holmes_data = [
      {
        "Site1" => {
          "name" => "Site1",
          "main" => "https://www.colourlovers.com",
          "user" => "https://www.colourlovers.com/lover/{}",
          "user2" => "https://www.colourlovers.com/lover/{}",
          "Tag" => ["Forum"]
        },
        "Site2" => {
          "name" => "Site2",
          "main" => "sourceforge.net/",
          "user" => "https://sourceforge.net/u/{}",
          "user2" => "https://sourceforge.net/u/{}",
          "Tag" => ["Programming"]
        }
      }
    ]

    WebMock.stub_request(:get, SocialMediaListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 200, body: JSON.generate(mr_holmes_data))

    generator = SocialMediaListGenerator::SiteParser.new
    generator.generate_lists

    hosts_file = File.join(@tmpdir, "lists", "social_media_domains.hosts")
    content = File.read(hosts_file)

    # Should have cleaned domains without protocol or trailing slash
    assert_match(/0\.0\.0\.0 colourlovers\.com/, content)
    assert_match(/0\.0\.0\.0 sourceforge\.net/, content)

    # Should not have protocol in the hosts entries (comments may contain URLs)
    host_lines = content.lines.reject { |l| l.start_with?("#") || l.strip.empty? }
    host_lines.each do |line|
      refute_match(/https?:\/\//, line, "Host entry should not contain protocol: #{line.strip}")
    end
  end
end
