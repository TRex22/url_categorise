require "test_helper"

class UrlCategoriseParsingFixTest < Minitest::Test
  def test_hosts_format_parsing_extracts_domains_correctly
    client = UrlCategorise::Client.new(host_urls: {})
    
    # Test typical hosts file content
    hosts_content = <<~HOSTS
      # Comment line
      0.0.0.0 domain1.com
      127.0.0.1 domain2.com
      # Another comment
      0.0.0.0 domain3.org
      
      # Empty line above and below
      
      192.168.1.1 domain4.net
    HOSTS
    
    result = client.send(:parse_list_content, hosts_content, :hosts)
    
    # Should extract only the domain names, not the full lines
    expected_domains = ['domain1.com', 'domain2.com', 'domain3.org', 'domain4.net']
    assert_equal expected_domains, result
    
    # Verify no IP addresses or full lines are included
    result.each do |domain|
      refute_match(/^\d+\.\d+\.\d+\.\d+/, domain, "Should not contain IP addresses")
      refute_match(/\s/, domain, "Should not contain spaces")
    end
  end
  
  def test_hosts_parsing_handles_malformed_lines
    client = UrlCategorise::Client.new(host_urls: {})
    
    malformed_content = <<~HOSTS
      0.0.0.0 good.com
      malformed_line_without_space
      # Comment
      127.0.0.1 another.com
      just_one_part
      0.0.0.0
      192.168.1.1 final.org
    HOSTS
    
    result = client.send(:parse_list_content, malformed_content, :hosts)
    
    # Should only extract valid domains
    expected_domains = ['good.com', 'another.com', 'final.org']
    assert_equal expected_domains, result
  end
  
  def test_categorisation_works_with_fixed_parsing
    # Mock a hosts file response
    WebMock.stub_request(:get, "http://test-hosts.com/hosts.txt")
           .to_return(
             body: "0.0.0.0 malicious.com\n127.0.0.1 badsite.org",
             headers: { 'etag' => '"test-hosts"' }
           )

    client = UrlCategorise::Client.new(
      host_urls: { malware: ["http://test-hosts.com/hosts.txt"] }
    )
    
    # Test that categorisation works with extracted domains
    assert_includes client.categorise("malicious.com"), :malware
    assert_includes client.categorise("badsite.org"), :malware
    assert_includes client.categorise("sub.malicious.com"), :malware
    
    # Test that it doesn't match the raw hosts file lines
    assert_empty client.categorise("0.0.0.0")
    assert_empty client.categorise("127.0.0.1")
  end
end