#!/usr/bin/env ruby

require_relative 'taxonomy_manager'
require_relative 'sync_connector_manager'
require_relative 'wiseguy_content_manager'
require_relative 'knowledge_base_manager'

puts "🔄 Adding Sales Tools Content Sources"
puts "====================================="

# Initialize managers
taxonomy_manager = TaxonomyManager.new
kb_manager = KnowledgeBaseManager.new

# Add the new sales tools content sources
puts "\n📝 Adding sales tools content sources..."

# Add RFP projects
puts "  Adding rfp_projects..."
taxonomy_manager.add_content_source('0', 'rfp_projects', 'general', 'private', 'static', 'file_system_connector')

# Add SOW projects  
puts "  Adding sow_projects..."
taxonomy_manager.add_content_source('0', 'sow_projects', 'general', 'private', 'static', 'file_system_connector')

# Add Proposal projects
puts "  Adding proposal_projects..."
taxonomy_manager.add_content_source('0', 'proposal_projects', 'general', 'private', 'static', 'file_system_connector')

puts "\n✅ Sales tools content sources added successfully!"

# Generate updated report
puts "\n📊 Updated organization report:"
report = kb_manager.get_organization_report('0')
puts "  - Organization: #{report['organization']['name']}"
puts "  - Content Sources: #{report['content_sources'].length}"
puts "  - New sources added: rfp_projects, sow_projects, proposal_projects"

puts "\n🎉 Sales tools migration complete!"
