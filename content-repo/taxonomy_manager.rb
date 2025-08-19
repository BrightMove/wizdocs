require 'yaml'
require 'fileutils'
require 'json'

class TaxonomyManager
  attr_reader :config, :organizations_path

  def initialize(organizations_path = File.expand_path('organizations', File.dirname(__FILE__)))
    @organizations_path = organizations_path
    @config = load_taxonomy_config
    ensure_base_structure
  end

  # Load the taxonomy configuration
  def load_taxonomy_config
    config_path = File.expand_path('taxonomy_config.yml', File.dirname(__FILE__))
    if File.exist?(config_path)
      YAML.load_file(config_path)
    else
      raise "Taxonomy configuration file not found: #{config_path}"
    end
  end

  # Ensure the base directory structure exists
  def ensure_base_structure
    FileUtils.mkdir_p(@organizations_path) unless Dir.exist?(@organizations_path)
  end

  # Create a new organization
  def create_organization(cro_org_id, name, description = nil)
    org_dir = File.join(@organizations_path, "org_#{cro_org_id}")
    
    if Dir.exist?(org_dir)
      puts "Organization org_#{cro_org_id} already exists"
      return false
    end

    # Create organization directory structure
    create_organization_structure(org_dir)
    
    # Create organization metadata
    create_organization_metadata(org_dir, cro_org_id, name, description)
    
    puts "Created organization: org_#{cro_org_id} (#{name})"
    true
  end

  # Create the directory structure for an organization
  def create_organization_structure(org_dir)
    # Content sources structure
    content_sources_path = File.join(org_dir, 'content_sources')
    
    # General content sources
    ['general/public/static', 'general/public/dynamic', 
     'general/private/static', 'general/private/dynamic'].each do |path|
      FileUtils.mkdir_p(File.join(content_sources_path, path))
    end
    
    # Specific content sources
    specific_types = ['intercom_tickets', 'intercom_help_center', 'confluence', 'jira', 'github']
    ['specific/public/dynamic', 'specific/private/dynamic'].each do |visibility|
      specific_types.each do |type|
        FileUtils.mkdir_p(File.join(content_sources_path, visibility, type))
      end
    end
    
    # Wiseguy content directories
    ['wiseguy_metadata', 'wiseguy_hints', 'wiseguy_prompts'].each do |wiseguy_type|
      FileUtils.mkdir_p(File.join(org_dir, wiseguy_type))
    end
  end

  # Create organization metadata file
  def create_organization_metadata(org_dir, cro_org_id, name, description)
    metadata = {
      'organization_id' => cro_org_id,
      'name' => name,
      'description' => description,
      'created_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'content_sources' => [],
      'wiseguy_content' => []
    }
    
    File.write(File.join(org_dir, 'organization.json'), JSON.pretty_generate(metadata))
  end

  # Add a content source to an organization (new API-compatible version)
  def add_content_source(org_id, source_data)
    source_name = source_data['name']
    source_type = source_data['type']
    visibility = source_data['visibility']
    sync_strategy = source_data['sync_strategy']
    connector = source_data['connector']
    url = source_data['url']
    description = source_data['description']
    
    org_dir = File.join(@organizations_path, "org_#{org_id}")
    
    unless Dir.exist?(org_dir)
      return { success: false, error: "Organization org_#{org_id} does not exist" }
    end

    # Check if content source already exists
    existing_source = get_content_source(org_id, source_name)
    if existing_source
      return { success: false, error: "Content source '#{source_name}' already exists" }
    end

    # Determine the target directory based on source type and configuration
    target_dir = determine_content_source_directory(org_dir, source_type, visibility, sync_strategy)
    
    # Create the content source directory
    source_dir = File.join(target_dir, source_name)
    FileUtils.mkdir_p(source_dir)
    
    # Create content source metadata with additional fields
    metadata = {
      'name' => source_name,
      'type' => source_type,
      'visibility' => visibility,
      'sync_strategy' => sync_strategy,
      'connector' => connector,
      'url' => url,
      'description' => description,
      'created_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'last_sync' => nil,
      'sync_status' => 'pending',
      'content_count' => 0
    }
    
    File.write(File.join(source_dir, 'source_metadata.json'), JSON.pretty_generate(metadata))
    
    # Update organization metadata
    update_organization_content_sources(org_dir, source_name, source_type, visibility, sync_strategy, connector)
    
    { success: true, message: "Added content source: #{source_name} to org_#{org_id}" }
  end

  # Update a content source
  def update_content_source(org_id, source_name, source_data)
    existing_source = get_content_source(org_id, source_name)
    unless existing_source
      return { success: false, error: "Content source '#{source_name}' not found" }
    end
    
    source_dir = existing_source['path']
    metadata_path = File.join(source_dir, 'source_metadata.json')
    
    # Update metadata with new values
    metadata = {
      'name' => source_name,
      'type' => source_data['type'] || existing_source['type'],
      'visibility' => source_data['visibility'] || existing_source['visibility'],
      'sync_strategy' => source_data['sync_strategy'] || existing_source['sync_strategy'],
      'connector' => source_data['connector'] || existing_source['connector'],
      'url' => source_data['url'] || existing_source['url'],
      'description' => source_data['description'] || existing_source['description'],
      'created_at' => existing_source['created_at'],
      'updated_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'last_sync' => existing_source['last_sync'],
      'sync_status' => existing_source['sync_status'],
      'content_count' => existing_source['content_count']
    }
    
    File.write(metadata_path, JSON.pretty_generate(metadata))
    
    { success: true, message: "Updated content source: #{source_name}" }
  end

  # Delete a content source
  def delete_content_source(org_id, source_name)
    existing_source = get_content_source(org_id, source_name)
    unless existing_source
      return { success: false, error: "Content source '#{source_name}' not found" }
    end
    
    source_dir = existing_source['path']
    
    # Remove the content source directory
    FileUtils.rm_rf(source_dir)
    
    # Update organization metadata to remove the content source
    org_dir = File.join(@organizations_path, "org_#{org_id}")
    metadata_path = File.join(org_dir, 'organization.json')
    
    if File.exist?(metadata_path)
      metadata = JSON.parse(File.read(metadata_path))
      metadata['content_sources'].reject! { |source| source['name'] == source_name }
      File.write(metadata_path, JSON.pretty_generate(metadata))
    end
    
    { success: true, message: "Deleted content source: #{source_name}" }
  end

  # Determine the correct directory for a content source
  def determine_content_source_directory(org_dir, source_type, visibility, sync_strategy)
    base_path = File.join(org_dir, 'content_sources')
    
    case source_type
    when 'general'
      File.join(base_path, 'general', visibility, sync_strategy)
    when 'specific'
      File.join(base_path, 'specific', visibility, sync_strategy)
    else
      raise "Invalid source type: #{source_type}"
    end
  end

  # Create content source metadata
  def create_content_source_metadata(source_dir, source_name, source_type, visibility, sync_strategy, connector)
    metadata = {
      'name' => source_name,
      'type' => source_type,
      'visibility' => visibility,
      'sync_strategy' => sync_strategy,
      'connector' => connector,
      'created_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'last_sync' => nil,
      'sync_status' => 'pending',
      'content_count' => 0
    }
    
    File.write(File.join(source_dir, 'source_metadata.json'), JSON.pretty_generate(metadata))
  end

  # Update organization metadata with new content source
  def update_organization_content_sources(org_dir, source_name, source_type, visibility, sync_strategy, connector)
    metadata_path = File.join(org_dir, 'organization.json')
    metadata = JSON.parse(File.read(metadata_path))
    
    content_source = {
      'name' => source_name,
      'type' => source_type,
      'visibility' => visibility,
      'sync_strategy' => sync_strategy,
      'connector' => connector,
      'added_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%SZ')
    }
    
    metadata['content_sources'] << content_source
    File.write(metadata_path, JSON.pretty_generate(metadata))
  end

  # List all organizations
  def list_organizations
    organizations = []
    
    Dir.glob(File.join(@organizations_path, 'org_*')).each do |org_dir|
      org_id = File.basename(org_dir)
      metadata_path = File.join(org_dir, 'organization.json')
      
      if File.exist?(metadata_path)
        metadata = JSON.parse(File.read(metadata_path))
        organizations << {
          'id' => org_id,
          'name' => metadata['name'],
          'description' => metadata['description'],
          'content_sources_count' => metadata['content_sources'].length
        }
      end
    end
    
    organizations
  end

  # Get organization details
  def get_organization(org_id)
    org_dir = File.join(@organizations_path, "org_#{org_id}")
    metadata_path = File.join(org_dir, 'organization.json')
    
    if File.exist?(metadata_path)
      JSON.parse(File.read(metadata_path))
    else
      nil
    end
  end

  # List content sources for an organization
  def list_content_sources(org_id)
    org_dir = File.join(@organizations_path, "org_#{org_id}")
    return nil unless Dir.exist?(org_dir)
    
    content_sources = []
    content_sources_path = File.join(org_dir, 'content_sources')
    
    # Scan all content source directories
    Dir.glob(File.join(content_sources_path, '**', '*')).select { |path| File.directory?(path) }.each do |source_dir|
      metadata_path = File.join(source_dir, 'source_metadata.json')
      
      if File.exist?(metadata_path)
        metadata = JSON.parse(File.read(metadata_path))
        content_sources << {
          'name' => metadata['name'],
          'type' => metadata['type'],
          'visibility' => metadata['visibility'],
          'sync_strategy' => metadata['sync_strategy'],
          'connector' => metadata['connector'],
          'last_sync' => metadata['last_sync'],
          'sync_status' => metadata['sync_status'],
          'content_count' => metadata['content_count'],
          'path' => source_dir
        }
      end
    end
    
    content_sources
  end

  # Get content source details
  def get_content_source(org_id, source_name)
    org_dir = File.join(@organizations_path, "org_#{org_id}")
    content_sources_path = File.join(org_dir, 'content_sources')
    
    # Search for the content source
    Dir.glob(File.join(content_sources_path, '**', source_name)).each do |source_dir|
      metadata_path = File.join(source_dir, 'source_metadata.json')
      
      if File.exist?(metadata_path)
        metadata = JSON.parse(File.read(metadata_path))
        metadata['path'] = source_dir
        return metadata
      end
    end
    
    nil
  end

  # Update content source sync status
  def update_sync_status(org_id, source_name, status, content_count = nil)
    source = get_content_source(org_id, source_name)
    return false unless source
    
    metadata_path = File.join(source['path'], 'source_metadata.json')
    metadata = JSON.parse(File.read(metadata_path))
    
    metadata['last_sync'] = Time.now.strftime('%Y-%m-%dT%H:%M:%SZ')
    metadata['sync_status'] = status
    metadata['content_count'] = content_count if content_count
    
    File.write(metadata_path, JSON.pretty_generate(metadata))
    true
  end

  # Get Wiseguy content for an organization
  def get_wiseguy_content(org_id, content_type)
    org_dir = File.join(@organizations_path, "org_#{org_id}")
    wiseguy_dir = File.join(org_dir, content_type)
    
    return nil unless Dir.exist?(wiseguy_dir)
    
    content = []
    Dir.glob(File.join(wiseguy_dir, '**', '*')).each do |file_path|
      next if File.directory?(file_path)
      
      content << {
        'filename' => File.basename(file_path),
        'path' => file_path,
        'size' => File.size(file_path),
        'modified' => File.mtime(file_path).strftime('%Y-%m-%dT%H:%M:%SZ')
      }
    end
    
    content
  end

  # Add Wiseguy content
  def add_wiseguy_content(org_id, content_type, filename, content)
    org_dir = File.join(@organizations_path, "org_#{org_id}")
    wiseguy_dir = File.join(org_dir, content_type)
    
    FileUtils.mkdir_p(wiseguy_dir) unless Dir.exist?(wiseguy_dir)
    
    file_path = File.join(wiseguy_dir, filename)
    File.write(file_path, content)
    
    puts "Added Wiseguy content: #{content_type}/#{filename} to org_#{org_id}"
    true
  end

  # Validate taxonomy structure
  def validate_taxonomy
    errors = []
    
    # Check if organizations directory exists
    unless Dir.exist?(@organizations_path)
      errors << "Organizations directory does not exist: #{@organizations_path}"
      return errors
    end
    
    # Check each organization
    Dir.glob(File.join(@organizations_path, 'org_*')).each do |org_dir|
      org_id = File.basename(org_dir)
      
      # Check organization metadata
      metadata_path = File.join(org_dir, 'organization.json')
      unless File.exist?(metadata_path)
        errors << "Missing organization metadata: #{org_id}"
        next
      end
      
      # Validate organization structure
      required_dirs = [
        'content_sources/general/public/static',
        'content_sources/general/public/dynamic',
        'content_sources/general/private/static',
        'content_sources/general/private/dynamic',
        'content_sources/specific/public/dynamic',
        'content_sources/specific/private/dynamic',
        'wiseguy_metadata',
        'wiseguy_hints',
        'wiseguy_prompts'
      ]
      
      required_dirs.each do |dir|
        unless Dir.exist?(File.join(org_dir, dir))
          errors << "Missing required directory: #{org_id}/#{dir}"
        end
      end
    end
    
    errors
  end

  # Generate taxonomy report
  def generate_report
    report = {
      'generated_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'organizations' => [],
      'total_content_sources' => 0,
      'validation_errors' => validate_taxonomy
    }
    
    list_organizations.each do |org|
      org_details = get_organization(org['id'].gsub('org_', ''))
      content_sources = list_content_sources(org['id'].gsub('org_', ''))
      
      report['organizations'] << {
        'id' => org['id'],
        'name' => org['name'],
        'description' => org['description'],
        'content_sources' => content_sources,
        'content_sources_count' => content_sources&.length || 0
      }
      
      report['total_content_sources'] += content_sources&.length || 0
    end
    
    report
  end
end

# Example usage
if __FILE__ == $0
  puts "🔧 Taxonomy Manager"
  puts "=================="
  
  manager = TaxonomyManager.new
  
  # Create organization 0 if it doesn't exist
  unless Dir.exist?('content-repo/organizations/org_0')
    manager.create_organization('0', 'BrightMove', 'Primary organization for BrightMove content')
  end
  
  # Add some content sources to org_0
  content_sources = [
    { name: 'intercom_tickets', type: 'specific', visibility: 'private', sync_strategy: 'dynamic', connector: 'intercom_tickets_connector' },
    { name: 'confluence', type: 'specific', visibility: 'private', sync_strategy: 'dynamic', connector: 'confluence_connector' },
    { name: 'jira', type: 'specific', visibility: 'private', sync_strategy: 'dynamic', connector: 'jira_connector' },
    { name: 'github', type: 'specific', visibility: 'public', sync_strategy: 'dynamic', connector: 'github_connector' },
    { name: 'website_content', type: 'general', visibility: 'public', sync_strategy: 'static', connector: 'web_scraper_connector' }
  ]
  
  content_sources.each do |source|
    manager.add_content_source('0', source[:name], source[:type], source[:visibility], source[:sync_strategy], source[:connector])
  end
  
  # Generate and display report
  report = manager.generate_report
  puts "\n📊 Taxonomy Report:"
  puts JSON.pretty_generate(report)
end
