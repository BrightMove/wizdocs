require 'json'
require 'fileutils'
require 'net/http'
require 'uri'
require 'yaml'

class SyncConnectorManager
  attr_reader :taxonomy_manager

  def initialize(taxonomy_manager)
    @taxonomy_manager = taxonomy_manager
    @connectors = load_connector_configs
  end

  # Load connector configurations
  def load_connector_configs
    config_path = 'taxonomy_config.yml'
    if File.exist?(config_path)
      config = YAML.load_file(config_path)
      config['content_source_types']['specific']['connectors']
    else
      {}
    end
  end

  # Sync content from a specific source
  def sync_content_source(org_id, source_name)
    source = @taxonomy_manager.get_content_source(org_id, source_name)
    return false unless source

    connector_name = source['connector']
    return false unless @connectors[connector_name]

    puts "🔄 Syncing #{source_name} for org_#{org_id} using #{connector_name}"

    begin
      # Update sync status to 'syncing'
      @taxonomy_manager.update_sync_status(org_id, source_name, 'syncing')

      # Get connector configuration
      connector_config = @connectors[connector_name]
      
      # Execute the appropriate sync method
      case connector_name
      when 'intercom_tickets_connector'
        result = sync_intercom_tickets(org_id, source_name, connector_config)
      when 'intercom_help_center_connector'
        result = sync_intercom_help_center(org_id, source_name, connector_config)
      when 'confluence_connector'
        result = sync_confluence(org_id, source_name, connector_config)
      when 'jira_connector'
        result = sync_jira(org_id, source_name, connector_config)
      when 'github_connector'
        result = sync_github(org_id, source_name, connector_config)
      when 'web_scraper_connector'
        result = sync_web_content(org_id, source_name, connector_config)
      when 'file_system_connector'
        result = sync_file_system(org_id, source_name, connector_config)
      else
        puts "❌ Unknown connector: #{connector_name}"
        @taxonomy_manager.update_sync_status(org_id, source_name, 'failed')
        return false
      end

      if result
        @taxonomy_manager.update_sync_status(org_id, source_name, 'completed', result[:content_count])
        puts "✅ Successfully synced #{source_name}: #{result[:content_count]} items"
        true
      else
        @taxonomy_manager.update_sync_status(org_id, source_name, 'failed')
        puts "❌ Failed to sync #{source_name}"
        false
      end

    rescue => e
      puts "❌ Error syncing #{source_name}: #{e.message}"
      @taxonomy_manager.update_sync_status(org_id, source_name, 'failed')
      false
    end
  end

  # Sync Intercom tickets
  def sync_intercom_tickets(org_id, source_name, config)
    source_path = @taxonomy_manager.get_content_source(org_id, source_name)['path']
    
    # This would integrate with the existing Intercom service
    # For now, we'll create a placeholder structure
    tickets_data = {
      'metadata' => {
        'source' => 'intercom_tickets',
        'synced_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'connector_config' => config
      },
      'tickets' => []
    }

    # Create the content directory structure
    content_dir = File.join(source_path, 'content')
    FileUtils.mkdir_p(content_dir)

    # Save the synced data with metadata
    File.write(File.join(content_dir, 'tickets.json'), JSON.pretty_generate(tickets_data))
    
    # Create metadata index
    create_metadata_index(source_path, 'intercom_tickets', tickets_data['tickets'].length)
    
    { content_count: tickets_data['tickets'].length }
  end

  # Sync Intercom help center
  def sync_intercom_help_center(org_id, source_name, config)
    source_path = @taxonomy_manager.get_content_source(org_id, source_name)['path']
    
    articles_data = {
      'metadata' => {
        'source' => 'intercom_help_center',
        'synced_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'connector_config' => config
      },
      'articles' => []
    }

    content_dir = File.join(source_path, 'content')
    FileUtils.mkdir_p(content_dir)

    File.write(File.join(content_dir, 'articles.json'), JSON.pretty_generate(articles_data))
    create_metadata_index(source_path, 'intercom_help_center', articles_data['articles'].length)
    
    { content_count: articles_data['articles'].length }
  end

  # Sync Confluence content
  def sync_confluence(org_id, source_name, config)
    source_path = @taxonomy_manager.get_content_source(org_id, source_name)['path']
    
    pages_data = {
      'metadata' => {
        'source' => 'confluence',
        'synced_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'connector_config' => config
      },
      'pages' => []
    }

    content_dir = File.join(source_path, 'content')
    FileUtils.mkdir_p(content_dir)

    File.write(File.join(content_dir, 'pages.json'), JSON.pretty_generate(pages_data))
    create_metadata_index(source_path, 'confluence', pages_data['pages'].length)
    
    { content_count: pages_data['pages'].length }
  end

  # Sync JIRA tickets
  def sync_jira(org_id, source_name, config)
    source_path = @taxonomy_manager.get_content_source(org_id, source_name)['path']
    
    issues_data = {
      'metadata' => {
        'source' => 'jira',
        'synced_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'connector_config' => config
      },
      'issues' => []
    }

    content_dir = File.join(source_path, 'content')
    FileUtils.mkdir_p(content_dir)

    File.write(File.join(content_dir, 'issues.json'), JSON.pretty_generate(issues_data))
    create_metadata_index(source_path, 'jira', issues_data['issues'].length)
    
    { content_count: issues_data['issues'].length }
  end

  # Sync GitHub repositories
  def sync_github(org_id, source_name, config)
    source_path = @taxonomy_manager.get_content_source(org_id, source_name)['path']
    
    repos_data = {
      'metadata' => {
        'source' => 'github',
        'synced_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'connector_config' => config
      },
      'repositories' => []
    }

    content_dir = File.join(source_path, 'content')
    FileUtils.mkdir_p(content_dir)

    File.write(File.join(content_dir, 'repositories.json'), JSON.pretty_generate(repos_data))
    create_metadata_index(source_path, 'github', repos_data['repositories'].length)
    
    { content_count: repos_data['repositories'].length }
  end

  # Sync web content (static)
  def sync_web_content(org_id, source_name, config)
    source_path = @taxonomy_manager.get_content_source(org_id, source_name)['path']
    
    web_data = {
      'metadata' => {
        'source' => 'web_content',
        'synced_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'connector_config' => config
      },
      'pages' => []
    }

    content_dir = File.join(source_path, 'content')
    FileUtils.mkdir_p(content_dir)

    File.write(File.join(content_dir, 'web_content.json'), JSON.pretty_generate(web_data))
    create_metadata_index(source_path, 'web_content', web_data['pages'].length)
    
    { content_count: web_data['pages'].length }
  end

  # Sync file system content
  def sync_file_system(org_id, source_name, config)
    source_path = @taxonomy_manager.get_content_source(org_id, source_name)['path']
    
    files_data = {
      'metadata' => {
        'source' => 'file_system',
        'synced_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        'connector_config' => config
      },
      'files' => []
    }

    content_dir = File.join(source_path, 'content')
    FileUtils.mkdir_p(content_dir)

    File.write(File.join(content_dir, 'files.json'), JSON.pretty_generate(files_data))
    create_metadata_index(source_path, 'file_system', files_data['files'].length)
    
    { content_count: files_data['files'].length }
  end

  # Create metadata index for content source
  def create_metadata_index(source_path, content_type, content_count)
    index_data = {
      'content_type' => content_type,
      'content_count' => content_count,
      'last_updated' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'metadata_fields' => get_metadata_fields(content_type)
    }

    File.write(File.join(source_path, 'metadata_index.json'), JSON.pretty_generate(index_data))
  end

  # Get metadata fields for content type
  def get_metadata_fields(content_type)
    case content_type
    when 'intercom_tickets'
      ['id', 'created_at', 'updated_at', 'user_id', 'conversation_parts', 'status']
    when 'intercom_help_center'
      ['id', 'title', 'body', 'author_id', 'published_at', 'updated_at', 'url']
    when 'confluence'
      ['id', 'title', 'body', 'version', 'created', 'updated', 'space_key', 'url']
    when 'jira'
      ['key', 'summary', 'description', 'status', 'assignee', 'created', 'updated', 'project']
    when 'github'
      ['id', 'name', 'full_name', 'description', 'created_at', 'updated_at', 'url']
    when 'web_content'
      ['url', 'title', 'content', 'scraped_at', 'file_size']
    when 'file_system'
      ['filename', 'path', 'size', 'modified', 'file_type']
    else
      []
    end
  end

  # Sync all content sources for an organization
  def sync_organization(org_id)
    content_sources = @taxonomy_manager.list_content_sources(org_id)
    return false unless content_sources

    results = {
      'org_id' => org_id,
      'synced_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'sources' => []
    }

    content_sources.each do |source|
      if source['sync_strategy'] == 'dynamic'
        success = sync_content_source(org_id, source['name'])
        results['sources'] << {
          'name' => source['name'],
          'success' => success,
          'sync_time' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
        }
      end
    end

    # Save sync report
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    File.write(File.join(org_dir, 'sync_report.json'), JSON.pretty_generate(results))

    results
  end

  # Get content from a specific source
  def get_content(org_id, source_name)
    source = @taxonomy_manager.get_content_source(org_id, source_name)
    return nil unless source

    content_dir = File.join(source['path'], 'content')
    return nil unless Dir.exist?(content_dir)

    content_files = Dir.glob(File.join(content_dir, '*.json'))
    content = {}

    content_files.each do |file|
      filename = File.basename(file, '.json')
      content[filename] = JSON.parse(File.read(file))
    end

    content
  end

  # Get metadata for a specific source
  def get_metadata(org_id, source_name)
    source = @taxonomy_manager.get_content_source(org_id, source_name)
    return nil unless source

    metadata_path = File.join(source['path'], 'metadata_index.json')
    return nil unless File.exist?(metadata_path)

    JSON.parse(File.read(metadata_path))
  end

  # Search content across all sources in an organization
  def search_content(org_id, query, content_types = nil)
    content_sources = @taxonomy_manager.list_content_sources(org_id)
    return [] unless content_sources

    results = []

    content_sources.each do |source|
      next if content_types && !content_types.include?(source['name'])

      content = get_content(org_id, source['name'])
      next unless content

      # Simple text search (would be enhanced with vector search)
      content.each do |content_type, data|
        if data.is_a?(Hash) && data['metadata']
          # Search in metadata
          if data['metadata']['source'].downcase.include?(query.downcase)
            results << {
              'source' => source['name'],
              'content_type' => content_type,
              'match_type' => 'metadata',
              'data' => data['metadata']
            }
          end
        end
      end
    end

    results
  end

  # Validate sync connectors
  def validate_connectors
    errors = []
    
    @connectors.each do |connector_name, config|
      required_fields = ['api_endpoint', 'content_type', 'metadata_fields']
      
      required_fields.each do |field|
        unless config[field]
          errors << "Missing required field '#{field}' in connector '#{connector_name}'"
        end
      end
    end

    errors
  end

  # Generate connector report
  def generate_connector_report
    report = {
      'generated_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'connectors' => @connectors.keys,
      'connector_count' => @connectors.length,
      'validation_errors' => validate_connectors
    }

    report
  end
end

# Example usage
if __FILE__ == $0
  puts "🔄 Sync Connector Manager"
  puts "========================"
  
  require_relative 'taxonomy_manager'
  
  taxonomy_manager = TaxonomyManager.new
  connector_manager = SyncConnectorManager.new(taxonomy_manager)
  
  # Generate connector report
  report = connector_manager.generate_connector_report
  puts "\n📊 Connector Report:"
  puts JSON.pretty_generate(report)
  
  # Sync organization 0
  if Dir.exist?('content-repo/organizations/org_0')
    puts "\n🔄 Syncing organization 0..."
    sync_results = connector_manager.sync_organization('0')
    puts "Sync Results:"
    puts JSON.pretty_generate(sync_results)
  end
end
