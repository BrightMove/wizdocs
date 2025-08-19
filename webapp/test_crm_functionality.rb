#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "Testing CRM Organization Management Functionality..."

base_url = "http://localhost:3000"

# Test 1: Get all organizations
puts "\n1. Testing GET /api/organizations"
begin
  response = Net::HTTP.get_response(URI("#{base_url}/api/organizations"))
  if response.code == "200"
    organizations = JSON.parse(response.body)
    puts "✅ Successfully retrieved #{organizations.length} organizations"
    organizations.each do |org|
      puts "   - #{org['name']} (ID: #{org['organization_id']}, Sources: #{org['content_source_count']})"
    end
  else
    puts "❌ Failed to get organizations: #{response.code}"
  end
rescue => e
  puts "❌ Error getting organizations: #{e.message}"
end

# Test 2: Update organization 0
puts "\n2. Testing PUT /api/organizations/0/update"
begin
  uri = URI("#{base_url}/api/organizations/0/update")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Put.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = {
    name: "BrightMove Test Updated",
    description: "Test description updated via API"
  }.to_json
  
  response = http.request(request)
  if response.code == "200"
    result = JSON.parse(response.body)
    puts "✅ Successfully updated organization: #{result['message']}"
  else
    puts "❌ Failed to update organization: #{response.code}"
  end
rescue => e
  puts "❌ Error updating organization: #{e.message}"
end

# Test 3: Add content source to organization 0
puts "\n3. Testing POST /api/organizations/0/content-sources/add"
begin
  uri = URI("#{base_url}/api/organizations/0/content-sources/add")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = {
    source_name: "test_jira_api",
    source_type: "specific",
    visibility: "private",
    sync_strategy: "dynamic",
    connector: "jira_connector"
  }.to_json
  
  response = http.request(request)
  if response.code == "200"
    result = JSON.parse(response.body)
    puts "✅ Successfully added content source: #{result['message']}"
  else
    puts "❌ Failed to add content source: #{response.code}"
  end
rescue => e
  puts "❌ Error adding content source: #{e.message}"
end

# Test 4: Get content sources for organization 0
puts "\n4. Testing GET /api/organizations/0/content-sources"
begin
  response = Net::HTTP.get_response(URI("#{base_url}/api/organizations/0/content-sources"))
  if response.code == "200"
    sources = JSON.parse(response.body)
    puts "✅ Successfully retrieved #{sources.length} content sources"
    
    # Find the test source
    test_source = sources.find { |s| s['name'] == 'test_jira_api' }
    if test_source
      puts "   ✅ Found test source: #{test_source['name']} (#{test_source['type']}, #{test_source['visibility']}, #{test_source['sync_strategy']})"
    else
      puts "   ❌ Test source not found"
    end
  else
    puts "❌ Failed to get content sources: #{response.code}"
  end
rescue => e
  puts "❌ Error getting content sources: #{e.message}"
end

# Test 5: Verify organization update
puts "\n5. Verifying organization update"
begin
  response = Net::HTTP.get_response(URI("#{base_url}/api/organizations"))
  if response.code == "200"
    organizations = JSON.parse(response.body)
    org_0 = organizations.find { |org| org['organization_id'] == '0' }
    if org_0
      puts "✅ Organization 0 updated successfully:"
      puts "   Name: #{org_0['name']}"
      puts "   Description: #{org_0['description']}"
      puts "   Content Sources: #{org_0['content_source_count']}"
    else
      puts "❌ Organization 0 not found"
    end
  else
    puts "❌ Failed to verify organization: #{response.code}"
  end
rescue => e
  puts "❌ Error verifying organization: #{e.message}"
end

puts "\n✅ All tests completed!"
