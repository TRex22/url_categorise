require "test_helper"
require "tmpdir"
require "fileutils"

# Load the generator module
load File.expand_path("../../bin/generate_categorised_lists", __dir__)

class GenerateCategorisedListsTest < Minitest::Test
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

  def test_generator_creates_all_category_hosts_files_when_api_fails
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Internal Server Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    expected_files = %w[
      gaming_domains.hosts
      developer_domains.hosts
      music_domains.hosts
      streaming_domains.hosts
      forum_domains.hosts
      messaging_domains.hosts
      crypto_domains.hosts
      blogging_domains.hosts
      security_domains.hosts
    ]

    expected_files.each do |filename|
      filepath = File.join(@tmpdir, "lists", filename)
      assert File.exist?(filepath), "#{filename} should be created"

      content = File.read(filepath)
      assert_match(/PiHole Compatible/, content, "#{filename} should have PiHole header")
      assert_match(/Mr\.Holmes/, content, "#{filename} should reference Mr.Holmes")
    end
  end

  def test_gaming_domains_contains_core_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "gaming_domains.hosts"))

    assert_match(/0\.0\.0\.0 steamcommunity\.com/, content)
    assert_match(/0\.0\.0\.0 roblox\.com/, content)
    assert_match(/0\.0\.0\.0 twitch\.tv/, content)
    assert_match(/0\.0\.0\.0 chess\.com/, content)
    assert_match(/0\.0\.0\.0 epicgames\.com/, content)
  end

  def test_developer_domains_contains_core_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "developer_domains.hosts"))

    assert_match(/0\.0\.0\.0 github\.com/, content)
    assert_match(/0\.0\.0\.0 gitlab\.com/, content)
    assert_match(/0\.0\.0\.0 npmjs\.com/, content)
    assert_match(/0\.0\.0\.0 rubygems\.org/, content)
    assert_match(/0\.0\.0\.0 stackoverflow\.com/, content)
  end

  def test_music_domains_contains_core_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "music_domains.hosts"))

    assert_match(/0\.0\.0\.0 soundcloud\.com/, content)
    assert_match(/0\.0\.0\.0 bandcamp\.com/, content)
    assert_match(/0\.0\.0\.0 spotify\.com/, content)
  end

  def test_messaging_domains_contains_core_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "messaging_domains.hosts"))

    assert_match(/0\.0\.0\.0 whatsapp\.com/, content)
    assert_match(/0\.0\.0\.0 telegram\.org/, content)
    assert_match(/0\.0\.0\.0 discord\.com/, content)
    assert_match(/0\.0\.0\.0 slack\.com/, content)
    assert_match(/0\.0\.0\.0 signal\.org/, content)
  end

  def test_security_domains_contains_core_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "security_domains.hosts"))

    assert_match(/0\.0\.0\.0 hackerone\.com/, content)
    assert_match(/0\.0\.0\.0 bugcrowd\.com/, content)
    assert_match(/0\.0\.0\.0 tryhackme\.com/, content)
  end

  def test_generator_processes_mr_holmes_tags_to_correct_categories
    mr_holmes_data = [
      {
        "SteamCommunity" => {
          "name" => "SteamCommunity",
          "main" => "steamcommunity.com",
          "user" => "https://steamcommunity.com/id/{}",
          "user2" => "https://steamcommunity.com/id/{}",
          "Tag" => ["Gaming", "Steam"]
        },
        "SoundCloud" => {
          "name" => "SoundCloud",
          "main" => "soundcloud.com",
          "user" => "https://soundcloud.com/{}",
          "user2" => "https://soundcloud.com/{}",
          "Tag" => ["Music"]
        },
        "HackerOne" => {
          "name" => "HackerOne",
          "main" => "hackerone.com",
          "user" => "https://hackerone.com/{}",
          "user2" => "https://hackerone.com/{}",
          "Tag" => ["Hacking"]
        },
        "DevCommunity" => {
          "name" => "DevCommunity",
          "main" => "dev.to",
          "user" => "https://dev.to/{}",
          "user2" => "https://dev.to/{}",
          "Tag" => ["Forum"]
        }
      }
    ]

    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 200, body: JSON.generate(mr_holmes_data))

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    gaming_content = File.read(File.join(@tmpdir, "lists", "gaming_domains.hosts"))
    assert_match(/0\.0\.0\.0 steamcommunity\.com/, gaming_content)

    music_content = File.read(File.join(@tmpdir, "lists", "music_domains.hosts"))
    assert_match(/0\.0\.0\.0 soundcloud\.com/, music_content)

    security_content = File.read(File.join(@tmpdir, "lists", "security_domains.hosts"))
    assert_match(/0\.0\.0\.0 hackerone\.com/, security_content)

    forum_content = File.read(File.join(@tmpdir, "lists", "forum_domains.hosts"))
    assert_match(/0\.0\.0\.0 dev\.to/, forum_content)
  end

  def test_generator_handles_malformed_json
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 200, body: "not valid json{{{")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    # All files should still be created with manual domains
    gaming_file = File.join(@tmpdir, "lists", "gaming_domains.hosts")
    assert File.exist?(gaming_file), "gaming_domains.hosts should still be created"

    content = File.read(gaming_file)
    assert_match(/0\.0\.0\.0 steamcommunity\.com/, content)
  end

  def test_generator_filters_invalid_domains
    mr_holmes_data = [
      {
        "Valid" => {
          "name" => "Valid",
          "main" => "valid-game.com",
          "user" => "https://valid-game.com/{}",
          "user2" => "https://valid-game.com/{}",
          "Tag" => ["Gaming"]
        },
        "Invalid" => {
          "name" => "Invalid",
          "main" => "localhost",
          "user" => "https://localhost/{}",
          "user2" => "https://localhost/{}",
          "Tag" => ["Gaming"]
        }
      }
    ]

    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 200, body: JSON.generate(mr_holmes_data))

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "gaming_domains.hosts"))
    assert_match(/0\.0\.0\.0 valid-game\.com/, content)
    refute_match(/0\.0\.0\.0 localhost/, content)
  end

  def test_all_host_entries_have_no_protocols
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    CategorisedListGenerator::SiteParser::CATEGORIES.each do |_category, info|
      filepath = File.join(@tmpdir, "lists", info[:filename])
      host_lines = File.readlines(filepath).reject { |l| l.start_with?("#") || l.strip.empty? }

      host_lines.each do |line|
        refute_match(/https?:\/\//, line, "#{info[:filename]} host entry should not contain protocol: #{line.strip}")
      end
    end
  end

  def test_www_variants_are_generated
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "gaming_domains.hosts"))

    assert_match(/0\.0\.0\.0 chess\.com/, content)
    assert_match(/0\.0\.0\.0 www\.chess\.com/, content)
  end

  def test_creates_lists_directory
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    assert Dir.exist?(File.join(@tmpdir, "lists")), "lists directory should be created"
  end

  def test_crypto_domains_contains_expected_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "crypto_domains.hosts"))

    assert_match(/0\.0\.0\.0 opensea\.io/, content)
    assert_match(/0\.0\.0\.0 coinbase\.com/, content)
    assert_match(/0\.0\.0\.0 bitcoin\.org/, content)
  end

  def test_blogging_domains_contains_expected_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "blogging_domains.hosts"))

    assert_match(/0\.0\.0\.0 medium\.com/, content)
    assert_match(/0\.0\.0\.0 wordpress\.com/, content)
    assert_match(/0\.0\.0\.0 substack\.com/, content)
  end

  def test_streaming_domains_contains_expected_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "streaming_domains.hosts"))

    assert_match(/0\.0\.0\.0 twitch\.tv/, content)
    assert_match(/0\.0\.0\.0 kick\.com/, content)
  end

  def test_forum_domains_contains_expected_platforms
    WebMock.stub_request(:get, CategorisedListGenerator::SiteParser::MR_HOLMES_SITE_LIST_URL)
           .to_return(status: 500, body: "Error")

    generator = CategorisedListGenerator::SiteParser.new
    generator.generate_lists

    content = File.read(File.join(@tmpdir, "lists", "forum_domains.hosts"))

    assert_match(/0\.0\.0\.0 quora\.com/, content)
    assert_match(/0\.0\.0\.0 reddit\.com/, content)
    assert_match(/0\.0\.0\.0 stackoverflow\.com/, content)
  end
end
