#!/usr/bin/env ruby

require 'bundler/setup'
require './lib/url_categorise'

puts '=== Large Dataset Loading Example ==='

# Configuration for handling large datasets (300+ MB)
# First test with cache-only mode
puts 'Creating client with cached datasets only...'
client = UrlCategorise::Client.new(
  cache_dir: './url_cache',
  auto_load_datasets: true,
  smart_categorization: true,
  dataset_config: {
    cache_path: './url_cache/datasets',
    download_path: './url_cache/downloads',
    kaggle: { credentials_file: '~/kaggle.json' }
  }
)

puts 'Client created successfully!'
puts ''
puts 'Dataset Statistics:'
puts "  Total categories: #{client.count_of_categories}"
puts "  Dataset categories: #{client.count_of_dataset_categories}"
puts "  Blocklist categories: #{client.count_of_categories - client.count_of_dataset_categories}"
puts ''
puts "  Total hosts: #{client.count_of_hosts.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "  Dataset hosts: #{client.count_of_dataset_hosts.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts ''
puts "  Total data size: #{client.size_of_data.round(1)} MB"
puts "  Dataset data size: #{client.size_of_dataset_data.round(1)} MB"
puts "  Blocklist data size: #{client.size_of_blocklist_data.round(1)} MB"

puts ''
puts 'Dataset-specific Statistics:'
# Get dataset metadata if available
metadata = client.dataset_metadata
if metadata && !metadata.empty?
  puts "  Datasets loaded: #{metadata.size}"

  # Calculate size for each dataset by finding its categories and domains
  client.instance_variable_get(:@dataset_categories)
  total_dataset_size = 0

  metadata.each_with_index do |(hash, data), index|
    # Estimate size contribution of this dataset
    dataset_portion = data[:total_entries].to_f / metadata.values.sum { |d| d[:total_entries] }
    dataset_size_mb = (client.size_of_dataset_data * dataset_portion).round(2)
    total_dataset_size += dataset_size_mb

    puts "  Dataset #{index + 1}:"
    puts "    Processed at: #{data[:processed_at]}"
    puts "    Total entries: #{data[:total_entries].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "    Estimated size: #{dataset_size_mb} MB"
    puts "    Data hash: #{hash[0..12]}..."
  end

  puts ''
  puts "  Total dataset size: #{total_dataset_size.round(2)} MB (#{client.size_of_dataset_data.round(1)} MB actual)"
else
  puts '  No dataset metadata available'
end
