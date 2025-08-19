require 'json'
require 'fileutils'
require 'yaml'
require_relative 'taxonomy_manager'
require_relative 'sync_connector_manager'
require_relative 'wiseguy_content_manager'

class KnowledgeBaseManager
  attr_reader :taxonomy_manager, :sync_connector_manager, :wiseguy_content_manager

  def initialize
    @taxonomy_manager = TaxonomyManager.new
    @sync_connector_manager = SyncConnectorManager.new(@taxonomy_manager)
    @wiseguy_content_manager = WiseguyContentManager.new(@taxonomy_manager)
  end

  # Initialize the knowledge base with organization 0
  def initialize_knowledge_base
    puts "🚀 Initializing Knowledge Base..."
    
    # Create organization 0 if it doesn't exist
    unless Dir.exist?('organizations/org_0')
      @taxonomy_manager.create_organization('0', 'BrightMove', 'Primary organization for BrightMove content')
    end
    
    # Add default content sources to org_0
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
      @taxonomy_manager.add_content_source('0', source[:name], source[:type], source[:visibility], source[:sync_strategy], source[:connector])
    end
    
    # Add default Wiseguy content
    add_default_wiseguy_content('0')
    
    puts "✅ Knowledge Base initialized successfully"
    true
  end

  # Add default Wiseguy content for an organization
  def add_default_wiseguy_content(org_id)
    # Add system metadata
    @wiseguy_content_manager.add_metadata('0', 'system_config', {
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
      @wiseguy_content_manager.add_hint(org_id, hint[:name], hint[:content], hint[:category], hint[:priority])
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
      @wiseguy_content_manager.add_prompt(org_id, prompt[:name], prompt[:template], prompt[:variables], prompt[:description])
    end
  end

  # Create a new organization
  def create_organization(cro_org_id, name, description = nil)
    success = @taxonomy_manager.create_organization(cro_org_id, name, description)
    
    if success
      # Add default Wiseguy content to the new organization
      add_default_wiseguy_content(cro_org_id)
    end
    
    success
  end

  # Sync all content for an organization
  def sync_organization(org_id)
    puts "🔄 Syncing organization #{org_id}..."
    
    # Sync content sources
    sync_results = @sync_connector_manager.sync_organization(org_id)
    
    # Update Wiseguy metadata with sync results
    @wiseguy_content_manager.update_metadata(org_id, 'sync_status', {
      'last_sync' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'sync_results' => sync_results
    })
    
    sync_results
  end

  # Search across all content in an organization
  def search_organization(org_id, query, content_types = nil)
    results = {
      'query' => query,
      'org_id' => org_id,
      'content_sources' => [],
      'wiseguy_content' => []
    }
    
    # Search content sources
    if content_types.nil? || content_types.include?('content_sources')
      source_results = @sync_connector_manager.search_content(org_id, query)
      results['content_sources'] = source_results
    end
    
    # Search Wiseguy content
    if content_types.nil? || content_types.include?('wiseguy_content')
      wiseguy_results = @wiseguy_content_manager.search_content(org_id, query)
      results['wiseguy_content'] = wiseguy_results
    end
    
    results
  end

  # Get comprehensive organization report
  def get_organization_report(org_id)
    report = {
      'org_id' => org_id,
      'generated_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'organization' => @taxonomy_manager.get_organization(org_id),
      'content_sources' => @taxonomy_manager.list_content_sources(org_id),
      'wiseguy_content_stats' => @wiseguy_content_manager.get_content_stats(org_id),
      'sync_connector_report' => @sync_connector_manager.generate_connector_report,
      'validation' => {
        'taxonomy_errors' => @taxonomy_manager.validate_taxonomy,
        'wiseguy_content_errors' => @wiseguy_content_manager.validate_content(org_id),
        'connector_errors' => @sync_connector_manager.validate_connectors
      }
    }
    
    report
  end

  # Get content from a specific source
  def get_content_source_content(org_id, source_name)
    @sync_connector_manager.get_content(org_id, source_name)
  end

  # Get Wiseguy content
  def get_wiseguy_content(org_id, content_type = nil)
    case content_type
    when 'metadata'
      @wiseguy_content_manager.get_metadata(org_id)
    when 'hints'
      @wiseguy_content_manager.get_hints(org_id)
    when 'prompts'
      @wiseguy_content_manager.get_prompts(org_id)
    else
      {
        'metadata' => @wiseguy_content_manager.get_metadata(org_id),
        'hints' => @wiseguy_content_manager.get_hints(org_id),
        'prompts' => @wiseguy_content_manager.get_prompts(org_id)
      }
    end
  end

  # Add content to a specific source
  def add_content_source_content(org_id, source_name, content_data)
    source = @taxonomy_manager.get_content_source(org_id, source_name)
    return false unless source
    
    content_dir = File.join(source['path'], 'content')
    FileUtils.mkdir_p(content_dir) unless Dir.exist?(content_dir)
    
    # Generate a unique filename
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "content_#{timestamp}.json"
    file_path = File.join(content_dir, filename)
    
    # Add metadata to the content
    content_with_metadata = {
      'metadata' => {
        'source' => source_name,
        'added_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'org_id' => org_id
      },
      'content' => content_data
    }
    
    File.write(file_path, JSON.pretty_generate(content_with_metadata))
    
    # Update source metadata
    @taxonomy_manager.update_sync_status(org_id, source_name, 'updated')
    
    puts "✅ Added content to #{source_name} in org_#{org_id}"
    true
  end

  # Export organization data
  def export_organization(org_id, export_path = nil)
    export_path ||= "content-repo/organizations/org_#{org_id}/full_export_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    
    export_data = {
      'exported_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'org_id' => org_id,
      'organization' => @taxonomy_manager.get_organization(org_id),
      'content_sources' => @taxonomy_manager.list_content_sources(org_id),
      'wiseguy_content' => {
        'metadata' => @wiseguy_content_manager.get_metadata(org_id),
        'hints' => @wiseguy_content_manager.get_hints(org_id),
        'prompts' => @wiseguy_content_manager.get_prompts(org_id)
      },
      'content_data' => {}
    }
    
    # Export content from each source
    content_sources = @taxonomy_manager.list_content_sources(org_id)
    content_sources.each do |source|
      content = @sync_connector_manager.get_content(org_id, source['name'])
      export_data['content_data'][source['name']] = content if content
    end
    
    File.write(export_path, JSON.pretty_generate(export_data))
    
    puts "✅ Exported organization #{org_id} to #{export_path}"
    export_path
  end

  # Import organization data
  def import_organization(import_path, org_id = nil)
    return false unless File.exist?(import_path)
    
    import_data = JSON.parse(File.read(import_path))
    org_id ||= import_data['org_id']
    
    # Create organization if it doesn't exist
    unless Dir.exist?("content-repo/organizations/org_#{org_id}")
      org_info = import_data['organization']
      @taxonomy_manager.create_organization(org_id, org_info['name'], org_info['description'])
    end
    
    # Import Wiseguy content
    if import_data['wiseguy_content']
      wiseguy_content = import_data['wiseguy_content']
      
      # Import metadata
      wiseguy_content['metadata']&.each do |type, data|
        @wiseguy_content_manager.add_metadata(org_id, type, data['data'])
      end
      
      # Import hints
      wiseguy_content['hints']&.each do |hint|
        @wiseguy_content_manager.add_hint(org_id, hint['name'], hint['content'], hint['category'], hint['priority'])
      end
      
      # Import prompts
      wiseguy_content['prompts']&.each do |prompt|
        @wiseguy_content_manager.add_prompt(org_id, prompt['name'], prompt['template'], prompt['variables'], prompt['description'])
      end
    end
    
    # Import content sources
    if import_data['content_sources']
      import_data['content_sources'].each do |source|
        @taxonomy_manager.add_content_source(org_id, source['name'], source['type'], source['visibility'], source['sync_strategy'], source['connector'])
      end
    end
    
    puts "✅ Imported organization #{org_id} from #{import_path}"
    true
  end

  # Get system-wide report
  def get_system_report
    report = {
      'generated_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'organizations' => @taxonomy_manager.list_organizations,
      'taxonomy_report' => @taxonomy_manager.generate_report,
      'connector_report' => @sync_connector_manager.generate_connector_report,
      'system_stats' => {
        'total_organizations' => @taxonomy_manager.list_organizations.length,
        'total_content_sources' => 0,
        'total_wiseguy_content' => 0
      }
    }
    
    # Calculate totals
    @taxonomy_manager.list_organizations.each do |org|
      org_id = org['id'].gsub('org_', '')
      content_sources = @taxonomy_manager.list_content_sources(org_id)
      report['system_stats']['total_content_sources'] += content_sources&.length || 0
      
      wiseguy_stats = @wiseguy_content_manager.get_content_stats(org_id)
      report['system_stats']['total_wiseguy_content'] += wiseguy_stats['wiseguy_metadata']['count'] + 
                                                       wiseguy_stats['wiseguy_hints']['count'] + 
                                                       wiseguy_stats['wiseguy_prompts']['count']
    end
    
    report
  end

  # Validate entire knowledge base
  def validate_knowledge_base
    errors = []
    
    # Validate taxonomy
    taxonomy_errors = @taxonomy_manager.validate_taxonomy
    errors.concat(taxonomy_errors.map { |e| "Taxonomy: #{e}" })
    
    # Validate connectors
    connector_errors = @sync_connector_manager.validate_connectors
    errors.concat(connector_errors.map { |e| "Connector: #{e}" })
    
    # Validate each organization
    @taxonomy_manager.list_organizations.each do |org|
      org_id = org['id'].gsub('org_', '')
      wiseguy_errors = @wiseguy_content_manager.validate_content(org_id)
      errors.concat(wiseguy_errors.map { |e| "Organization #{org_id}: #{e}" })
    end
    
    errors
  end

  # Run maintenance tasks
  def run_maintenance
    puts "🔧 Running Knowledge Base Maintenance..."
    
    maintenance_results = {
      'timestamp' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'validation_errors' => validate_knowledge_base,
      'organizations_processed' => 0,
      'content_sources_synced' => 0,
      'wiseguy_content_updated' => 0
    }
    
    # Process each organization
    @taxonomy_manager.list_organizations.each do |org|
      org_id = org['id'].gsub('org_', '')
      maintenance_results['organizations_processed'] += 1
      
      # Sync dynamic content sources
      content_sources = @taxonomy_manager.list_content_sources(org_id)
      content_sources.each do |source|
        if source['sync_strategy'] == 'dynamic'
          success = @sync_connector_manager.sync_content_source(org_id, source['name'])
          maintenance_results['content_sources_synced'] += 1 if success
        end
      end
      
      # Update Wiseguy metadata
      @wiseguy_content_manager.update_metadata(org_id, 'maintenance', {
        'last_maintenance' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'organization_status' => 'active'
      })
      maintenance_results['wiseguy_content_updated'] += 1
    end
    
    # Save maintenance report
    File.write('content-repo/maintenance_report.json', JSON.pretty_generate(maintenance_results))
    
    puts "✅ Maintenance completed: #{maintenance_results['content_sources_synced']} sources synced, #{maintenance_results['wiseguy_content_updated']} content updated"
    maintenance_results
  end
end

# Example usage
if __FILE__ == $0
  puts "🧠 Knowledge Base Manager"
  puts "========================"
  
  require_relative 'taxonomy_manager'
  require_relative 'sync_connector_manager'
  require_relative 'wiseguy_content_manager'
  
  kb_manager = KnowledgeBaseManager.new
  
  # Initialize the knowledge base
  kb_manager.initialize_knowledge_base
  
  # Generate system report
  system_report = kb_manager.get_system_report
  puts "\n📊 System Report:"
  puts JSON.pretty_generate(system_report)
  
  # Run maintenance
  maintenance_results = kb_manager.run_maintenance
  puts "\n🔧 Maintenance Results:"
  puts JSON.pretty_generate(maintenance_results)
end
