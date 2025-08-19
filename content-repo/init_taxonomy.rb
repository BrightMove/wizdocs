#!/usr/bin/env ruby

require_relative 'taxonomy_manager'
require_relative 'sync_connector_manager'
require_relative 'wiseguy_content_manager'
require_relative 'knowledge_base_manager'

puts "🚀 Initializing Knowledge Base Taxonomy"
puts "======================================="

# Initialize managers
taxonomy_manager = TaxonomyManager.new
sync_connector_manager = SyncConnectorManager.new(taxonomy_manager)
wiseguy_content_manager = WiseguyContentManager.new(taxonomy_manager)
kb_manager = KnowledgeBaseManager.new

# Check if org_0 exists and has proper structure
org_dir = 'organizations/org_0'
if Dir.exist?(org_dir)
  puts "✅ Organization directory exists: #{org_dir}"
  
  # Check if organization.json exists
  org_json = File.join(org_dir, 'organization.json')
  if File.exist?(org_json)
    puts "✅ Organization metadata exists"
  else
    puts "⚠️  Creating organization metadata..."
    taxonomy_manager.create_organization_metadata(org_dir, '0', 'BrightMove', 'Primary organization for BrightMove content')
  end
else
  puts "📁 Creating organization 0..."
  taxonomy_manager.create_organization('0', 'BrightMove', 'Primary organization for BrightMove content')
end

# Add default content sources
puts "\n📝 Adding default content sources..."
default_content_sources = [
  { name: 'intercom_tickets', type: 'specific', visibility: 'private', sync_strategy: 'dynamic', connector: 'intercom_tickets_connector' },
  { name: 'intercom_help_center', type: 'specific', visibility: 'public', sync_strategy: 'dynamic', connector: 'intercom_help_center_connector' },
  { name: 'confluence', type: 'specific', visibility: 'private', sync_strategy: 'dynamic', connector: 'confluence_connector' },
  { name: 'jira', type: 'specific', visibility: 'private', sync_strategy: 'dynamic', connector: 'jira_connector' },
  { name: 'github', type: 'specific', visibility: 'public', sync_strategy: 'dynamic', connector: 'github_connector' },
  { name: 'website_content', type: 'general', visibility: 'public', sync_strategy: 'static', connector: 'web_scraper_connector' },
  { name: 'documents', type: 'general', visibility: 'private', sync_strategy: 'static', connector: 'file_system_connector' }
]

default_content_sources.each do |source|
  puts "  Adding #{source[:name]}..."
  taxonomy_manager.add_content_source('0', source[:name], source[:type], source[:visibility], source[:sync_strategy], source[:connector])
end

# Add default Wiseguy content
puts "\n🧠 Adding default Wiseguy content..."

# Add system metadata
wiseguy_content_manager.add_metadata('0', 'system_config', {
  'ai_model' => 'gpt-4',
  'max_tokens' => 4000,
  'temperature' => 0.7,
  'organization_name' => 'BrightMove',
  'knowledge_base_version' => '1.0'
})

# Add default hints
default_hints = [
  {
    name: 'API Integration',
    content: 'When integrating with external APIs, always include proper error handling and rate limiting.',
    category: 'development',
    priority: 'high'
  },
  {
    name: 'Documentation Standards',
    content: 'All new features must include updated documentation in both Confluence and Intercom Help Center.',
    category: 'process',
    priority: 'medium'
  },
  {
    name: 'Content Consistency',
    content: 'Ensure that documentation, code comments, and user-facing content are consistent across all platforms.',
    category: 'quality',
    priority: 'high'
  }
]

default_hints.each do |hint|
  puts "  Adding hint: #{hint[:name]}..."
  wiseguy_content_manager.add_hint('0', hint[:name], hint[:content], hint[:category], hint[:priority])
end

# Add default prompts
default_prompts = [
  {
    name: 'Ticket Analysis',
    template: "Analyze the following {{ticket_type}} ticket for consistency with our documentation and implementation:\n\n{{ticket_content}}\n\nProvide a detailed analysis including:\n1. Documentation gaps\n2. Implementation inconsistencies\n3. Recommended actions",
    variables: ['ticket_type', 'ticket_content'],
    description: 'Standard prompt for analyzing support tickets and feature requests'
  },
  {
    name: 'Content Verification',
    template: "Verify the accuracy of the following content against our current implementation:\n\n{{content}}\n\nCheck for:\n1. Outdated information\n2. Missing features\n3. Inconsistent terminology\n4. Broken references",
    variables: ['content'],
    description: 'Prompt for verifying content accuracy and consistency'
  }
]

default_prompts.each do |prompt|
  puts "  Adding prompt: #{prompt[:name]}..."
  wiseguy_content_manager.add_prompt('0', prompt[:name], prompt[:template], prompt[:variables], prompt[:description])
end

# Generate and display report
puts "\n📊 Generating taxonomy report..."
report = kb_manager.get_organization_report('0')

puts "\n✅ Knowledge Base Taxonomy Initialized Successfully!"
puts "\n📋 Summary:"
puts "  - Organization: #{report['organization']['name']}"
puts "  - Content Sources: #{report['content_sources'].length}"
puts "  - Wiseguy Metadata: #{report['wiseguy_content_stats']['wiseguy_metadata']['count']}"
puts "  - Wiseguy Hints: #{report['wiseguy_content_stats']['wiseguy_hints']['count']}"
puts "  - Wiseguy Prompts: #{report['wiseguy_content_stats']['wiseguy_prompts']['count']}"

puts "\n🎉 Taxonomy initialization complete!"
