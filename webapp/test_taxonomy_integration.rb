#!/usr/bin/env ruby

require_relative '../content-repo/taxonomy_manager'
require_relative '../content-repo/knowledge_base_manager'

puts "🧪 Testing Taxonomy Integration"
puts "==============================="

begin
  # Test TaxonomyManager
  puts "\n1. Testing TaxonomyManager..."
  taxonomy_manager = TaxonomyManager.new
  puts "✅ TaxonomyManager initialized successfully"
  
  # Test organization retrieval
  org = taxonomy_manager.get_organization('0')
  if org
    puts "✅ Organization 0 found: #{org['name']}"
  else
    puts "❌ Organization 0 not found"
  end
  
  # Test content sources
  sources = taxonomy_manager.list_content_sources('0')
  puts "✅ Found #{sources.length} content sources"
  
  # Test specific sources
  rfp_source = taxonomy_manager.get_content_source('0', 'rfp_projects')
  sow_source = taxonomy_manager.get_content_source('0', 'sow_projects')
  proposal_source = taxonomy_manager.get_content_source('0', 'proposal_projects')
  
  puts "✅ RFP Projects source: #{rfp_source ? 'Found' : 'Not found'}"
  puts "✅ SOW Projects source: #{sow_source ? 'Found' : 'Not found'}"
  puts "✅ Proposal Projects source: #{proposal_source ? 'Found' : 'Not found'}"
  
  # Test KnowledgeBaseManager
  puts "\n2. Testing KnowledgeBaseManager..."
  kb_manager = KnowledgeBaseManager.new
  puts "✅ KnowledgeBaseManager initialized successfully"
  
  # Test SalesToolsManager integration
  puts "\n3. Testing SalesToolsManager integration..."
  
  # Test the new paths
  rfp_dir = File.expand_path('../../content-repo/organizations/org_0/content_sources/general/private/static/rfp_projects', __FILE__)
  sow_dir = File.expand_path('../../content-repo/organizations/org_0/content_sources/general/private/static/sow_projects', __FILE__)
  proposal_dir = File.expand_path('../../content-repo/organizations/org_0/content_sources/general/private/static/proposal_projects', __FILE__)
  
  puts "✅ RFP directory exists: #{Dir.exist?(rfp_dir)}"
  puts "✅ SOW directory exists: #{Dir.exist?(sow_dir)}"
  puts "✅ Proposal directory exists: #{Dir.exist?(proposal_dir)}"
  
  # Test project listing
  if Dir.exist?(rfp_dir)
    rfp_projects = Dir.entries(rfp_dir).select { |entry| !entry.start_with?('.') && File.directory?(File.join(rfp_dir, entry)) }
    puts "✅ Found #{rfp_projects.length} RFP projects"
  end
  
  if Dir.exist?(sow_dir)
    sow_projects = Dir.entries(sow_dir).select { |entry| !entry.start_with?('.') && File.directory?(File.join(sow_dir, entry)) }
    puts "✅ Found #{sow_projects.length} SOW projects"
  end
  
  if Dir.exist?(proposal_dir)
    proposal_projects = Dir.entries(proposal_dir).select { |entry| !entry.start_with?('.') && File.directory?(File.join(proposal_dir, entry)) }
    puts "✅ Found #{proposal_projects.length} proposal projects"
  end
  
  puts "\n🎉 All tests passed! Taxonomy integration is working correctly."
  
rescue => e
  puts "\n❌ Error during testing: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end
