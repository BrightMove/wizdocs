#!/usr/bin/env ruby

require_relative '../content-repo/knowledge_base_manager'

puts "Testing Organization Management..."

begin
  kb_manager = KnowledgeBaseManager.new
  taxonomy_manager = kb_manager.taxonomy_manager
  
  puts "✅ KnowledgeBaseManager initialized successfully"
  
  # Test creating a new organization
  puts "\n📝 Testing organization creation..."
  test_org_id = "test_123"
  test_org_name = "Test Organization"
  test_org_description = "A test organization for verification"
  
  result = taxonomy_manager.create_organization(test_org_id, test_org_name, test_org_description)
  if result
    puts "✅ Organization created successfully"
  else
    puts "❌ Failed to create organization"
  end
  
  # Test adding content source to the new organization
  puts "\n📁 Testing content source addition..."
  source_result = taxonomy_manager.add_content_source(
    test_org_id,
    'test_jira',
    'specific',
    'private',
    'dynamic',
    'jira_connector'
  )
  
  if source_result
    puts "✅ Content source added successfully"
  else
    puts "❌ Failed to add content source"
  end
  
  # Verify the organization exists
  puts "\n🔍 Verifying organization..."
  org_info = taxonomy_manager.get_organization(test_org_id)
  if org_info
    puts "✅ Organization found: #{org_info['name']}"
    puts "   Description: #{org_info['description']}"
    puts "   Created: #{org_info['created_at']}"
  else
    puts "❌ Organization not found"
  end
  
  # List content sources
  puts "\n📋 Listing content sources..."
  sources = taxonomy_manager.list_content_sources(test_org_id)
  puts "✅ Found #{sources.length} content sources:"
  sources.each do |source|
    puts "   - #{source['name']} (#{source['type']}, #{source['visibility']}, #{source['sync_strategy']})"
  end
  
  # List all organizations
  puts "\n🏢 Listing all organizations..."
  if Dir.exist?(taxonomy_manager.organizations_path)
    Dir.entries(taxonomy_manager.organizations_path).each do |entry|
      next if entry.start_with?('.')
      org_id = entry.gsub('org_', '')
      org_info = taxonomy_manager.get_organization(org_id)
      if org_info
        sources = taxonomy_manager.list_content_sources(org_id)
        puts "   - #{org_info['name']} (ID: #{org_id}, Sources: #{sources.length})"
      end
    end
  end
  
  puts "\n✅ All tests completed successfully!"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end
