require 'json'
require 'fileutils'
require 'yaml'

class WiseguyContentManager
  attr_reader :taxonomy_manager

  def initialize(taxonomy_manager)
    @taxonomy_manager = taxonomy_manager
    @content_types = ['wiseguy_metadata', 'wiseguy_hints', 'wiseguy_prompts']
  end

  # Add Wiseguy metadata to an organization
  def add_metadata(org_id, metadata_type, data)
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    metadata_dir = File.join(org_dir, 'wiseguy_metadata')
    
    FileUtils.mkdir_p(metadata_dir) unless Dir.exist?(metadata_dir)
    
    metadata = {
      'type' => metadata_type,
      'org_id' => org_id,
      'created_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'updated_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'data' => data
    }
    
    filename = "#{metadata_type}.json"
    file_path = File.join(metadata_dir, filename)
    
    File.write(file_path, JSON.pretty_generate(metadata))
    
    puts "✅ Added metadata: #{metadata_type} to org_#{org_id}"
    true
  end

  # Get Wiseguy metadata for an organization
  def get_metadata(org_id, metadata_type = nil)
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    metadata_dir = File.join(org_dir, 'wiseguy_metadata')
    
    return nil unless Dir.exist?(metadata_dir)
    
    if metadata_type
      file_path = File.join(metadata_dir, "#{metadata_type}.json")
      return nil unless File.exist?(file_path)
      
      JSON.parse(File.read(file_path))
    else
      # Return all metadata
      metadata = {}
      Dir.glob(File.join(metadata_dir, '*.json')).each do |file|
        type = File.basename(file, '.json')
        metadata[type] = JSON.parse(File.read(file))
      end
      metadata
    end
  end

  # Update Wiseguy metadata
  def update_metadata(org_id, metadata_type, data)
    existing = get_metadata(org_id, metadata_type)
    return false unless existing
    
    existing['data'] = data
    existing['updated_at'] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    metadata_dir = File.join(org_dir, 'wiseguy_metadata')
    file_path = File.join(metadata_dir, "#{metadata_type}.json")
    
    File.write(file_path, JSON.pretty_generate(existing))
    
    puts "✅ Updated metadata: #{metadata_type} in org_#{org_id}"
    true
  end

  # Add Wiseguy hints to an organization
  def add_hint(org_id, hint_name, content, category = 'general', priority = 'medium')
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    hints_dir = File.join(org_dir, 'wiseguy_hints')
    
    FileUtils.mkdir_p(hints_dir) unless Dir.exist?(hints_dir)
    
    hint = {
      'name' => hint_name,
      'content' => content,
      'category' => category,
      'priority' => priority,
      'org_id' => org_id,
      'created_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'updated_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    }
    
    filename = "#{hint_name.gsub(/\s+/, '_').downcase}.json"
    file_path = File.join(hints_dir, filename)
    
    File.write(file_path, JSON.pretty_generate(hint))
    
    puts "✅ Added hint: #{hint_name} to org_#{org_id}"
    true
  end

  # Get Wiseguy hints for an organization
  def get_hints(org_id, category = nil, priority = nil)
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    hints_dir = File.join(org_dir, 'wiseguy_hints')
    
    return [] unless Dir.exist?(hints_dir)
    
    hints = []
    Dir.glob(File.join(hints_dir, '*.json')).each do |file|
      hint = JSON.parse(File.read(file))
      
      # Apply filters
      next if category && hint['category'] != category
      next if priority && hint['priority'] != priority
      
      hints << hint
    end
    
    hints
  end

  # Update Wiseguy hint
  def update_hint(org_id, hint_name, content = nil, category = nil, priority = nil)
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    hints_dir = File.join(org_dir, 'wiseguy_hints')
    filename = "#{hint_name.gsub(/\s+/, '_').downcase}.json"
    file_path = File.join(hints_dir, filename)
    
    return false unless File.exist?(file_path)
    
    hint = JSON.parse(File.read(file_path))
    hint['content'] = content if content
    hint['category'] = category if category
    hint['priority'] = priority if priority
    hint['updated_at'] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    
    File.write(file_path, JSON.pretty_generate(hint))
    
    puts "✅ Updated hint: #{hint_name} in org_#{org_id}"
    true
  end

  # Add Wiseguy prompt to an organization
  def add_prompt(org_id, prompt_name, template, variables = [], description = nil)
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    prompts_dir = File.join(org_dir, 'wiseguy_prompts')
    
    FileUtils.mkdir_p(prompts_dir) unless Dir.exist?(prompts_dir)
    
    prompt = {
      'name' => prompt_name,
      'template' => template,
      'variables' => variables,
      'description' => description,
      'org_id' => org_id,
      'created_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'updated_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'usage_count' => 0
    }
    
    filename = "#{prompt_name.gsub(/\s+/, '_').downcase}.json"
    file_path = File.join(prompts_dir, filename)
    
    File.write(file_path, JSON.pretty_generate(prompt))
    
    puts "✅ Added prompt: #{prompt_name} to org_#{org_id}"
    true
  end

  # Get Wiseguy prompts for an organization
  def get_prompts(org_id, prompt_name = nil)
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    prompts_dir = File.join(org_dir, 'wiseguy_prompts')
    
    return nil unless Dir.exist?(prompts_dir)
    
    if prompt_name
      filename = "#{prompt_name.gsub(/\s+/, '_').downcase}.json"
      file_path = File.join(prompts_dir, filename)
      return nil unless File.exist?(file_path)
      
      JSON.parse(File.read(file_path))
    else
      # Return all prompts
      prompts = []
      Dir.glob(File.join(prompts_dir, '*.json')).each do |file|
        prompts << JSON.parse(File.read(file))
      end
      prompts
    end
  end

  # Update Wiseguy prompt
  def update_prompt(org_id, prompt_name, template = nil, variables = nil, description = nil)
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    prompts_dir = File.join(org_dir, 'wiseguy_prompts')
    filename = "#{prompt_name.gsub(/\s+/, '_').downcase}.json"
    file_path = File.join(prompts_dir, filename)
    
    return false unless File.exist?(file_path)
    
    prompt = JSON.parse(File.read(file_path))
    prompt['template'] = template if template
    prompt['variables'] = variables if variables
    prompt['description'] = description if description
    prompt['updated_at'] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    
    File.write(file_path, JSON.pretty_generate(prompt))
    
    puts "✅ Updated prompt: #{prompt_name} in org_#{org_id}"
    true
  end

  # Use a prompt (increment usage count)
  def use_prompt(org_id, prompt_name)
    prompt = get_prompts(org_id, prompt_name)
    return nil unless prompt
    
    prompt['usage_count'] += 1
    prompt['updated_at'] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    prompts_dir = File.join(org_dir, 'wiseguy_prompts')
    filename = "#{prompt_name.gsub(/\s+/, '_').downcase}.json"
    file_path = File.join(prompts_dir, filename)
    
    File.write(file_path, JSON.pretty_generate(prompt))
    
    prompt
  end

  # Render a prompt with variables
  def render_prompt(org_id, prompt_name, variables = {})
    prompt = get_prompts(org_id, prompt_name)
    return nil unless prompt
    
    # Use the prompt (increment usage count)
    use_prompt(org_id, prompt_name)
    
    # Render the template with variables
    rendered = prompt['template']
    variables.each do |key, value|
      rendered = rendered.gsub("{{#{key}}}", value.to_s)
    end
    
    {
      'prompt_name' => prompt_name,
      'rendered_content' => rendered,
      'variables_used' => variables,
      'original_template' => prompt['template']
    }
  end

  # Search Wiseguy content
  def search_content(org_id, query, content_types = nil)
    results = []
    
    content_types ||= @content_types
    
    content_types.each do |content_type|
      case content_type
      when 'wiseguy_metadata'
        metadata = get_metadata(org_id)
        metadata.each do |type, data|
          if data['data'].to_s.downcase.include?(query.downcase)
            results << {
              'content_type' => 'wiseguy_metadata',
              'type' => type,
              'match' => data
            }
          end
        end
      when 'wiseguy_hints'
        hints = get_hints(org_id)
        hints.each do |hint|
          if hint['content'].downcase.include?(query.downcase) || 
             hint['name'].downcase.include?(query.downcase)
            results << {
              'content_type' => 'wiseguy_hints',
              'hint' => hint
            }
          end
        end
      when 'wiseguy_prompts'
        prompts = get_prompts(org_id)
        prompts.each do |prompt|
          if prompt['template'].downcase.include?(query.downcase) || 
             prompt['name'].downcase.include?(query.downcase) ||
             (prompt['description'] && prompt['description'].downcase.include?(query.downcase))
            results << {
              'content_type' => 'wiseguy_prompts',
              'prompt' => prompt
            }
          end
        end
      end
    end
    
    results
  end

  # Get content statistics for an organization
  def get_content_stats(org_id)
    stats = {
      'org_id' => org_id,
      'wiseguy_metadata' => {
        'count' => 0,
        'types' => []
      },
      'wiseguy_hints' => {
        'count' => 0,
        'categories' => {},
        'priorities' => {}
      },
      'wiseguy_prompts' => {
        'count' => 0,
        'total_usage' => 0
      }
    }
    
    # Count metadata
    metadata = get_metadata(org_id)
    stats['wiseguy_metadata']['count'] = metadata.length
    stats['wiseguy_metadata']['types'] = metadata.keys
    
    # Count hints
    hints = get_hints(org_id)
    stats['wiseguy_hints']['count'] = hints.length
    hints.each do |hint|
      category = hint['category']
      priority = hint['priority']
      
      stats['wiseguy_hints']['categories'][category] ||= 0
      stats['wiseguy_hints']['categories'][category] += 1
      
      stats['wiseguy_hints']['priorities'][priority] ||= 0
      stats['wiseguy_hints']['priorities'][priority] += 1
    end
    
    # Count prompts
    prompts = get_prompts(org_id)
    stats['wiseguy_prompts']['count'] = prompts.length
    stats['wiseguy_prompts']['total_usage'] = prompts.sum { |p| p['usage_count'] }
    
    stats
  end

  # Export Wiseguy content for an organization
  def export_content(org_id, export_path = nil)
    export_path ||= "content-repo/organizations/org_#{org_id}/wiseguy_export_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    
    export_data = {
      'exported_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'org_id' => org_id,
      'wiseguy_metadata' => get_metadata(org_id),
      'wiseguy_hints' => get_hints(org_id),
      'wiseguy_prompts' => get_prompts(org_id),
      'stats' => get_content_stats(org_id)
    }
    
    File.write(export_path, JSON.pretty_generate(export_data))
    
    puts "✅ Exported Wiseguy content for org_#{org_id} to #{export_path}"
    export_path
  end

  # Import Wiseguy content for an organization
  def import_content(org_id, import_path)
    return false unless File.exist?(import_path)
    
    import_data = JSON.parse(File.read(import_path))
    
    # Import metadata
    if import_data['wiseguy_metadata']
      import_data['wiseguy_metadata'].each do |type, data|
        add_metadata(org_id, type, data['data'])
      end
    end
    
    # Import hints
    if import_data['wiseguy_hints']
      import_data['wiseguy_hints'].each do |hint|
        add_hint(org_id, hint['name'], hint['content'], hint['category'], hint['priority'])
      end
    end
    
    # Import prompts
    if import_data['wiseguy_prompts']
      import_data['wiseguy_prompts'].each do |prompt|
        add_prompt(org_id, prompt['name'], prompt['template'], prompt['variables'], prompt['description'])
      end
    end
    
    puts "✅ Imported Wiseguy content for org_#{org_id} from #{import_path}"
    true
  end

  # Validate Wiseguy content structure
  def validate_content(org_id)
    errors = []
    
    org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
    
    @content_types.each do |content_type|
      content_dir = File.join(org_dir, content_type)
      
      unless Dir.exist?(content_dir)
        errors << "Missing #{content_type} directory for org_#{org_id}"
        next
      end
      
      # Check for valid JSON files
      Dir.glob(File.join(content_dir, '*.json')).each do |file|
        begin
          JSON.parse(File.read(file))
        rescue JSON::ParserError => e
          errors << "Invalid JSON in #{file}: #{e.message}"
        end
      end
    end
    
    errors
  end

  # Generate Wiseguy content report
  def generate_report(org_id)
    report = {
      'generated_at' => Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      'org_id' => org_id,
      'stats' => get_content_stats(org_id),
      'validation_errors' => validate_content(org_id)
    }
    
    report
  end
end

# Example usage
if __FILE__ == $0
  puts "🧠 Wiseguy Content Manager"
  puts "=========================="
  
  require_relative 'taxonomy_manager'
  
  taxonomy_manager = TaxonomyManager.new
  content_manager = WiseguyContentManager.new(taxonomy_manager)
  
  # Create organization 0 if it doesn't exist
  unless Dir.exist?('content-repo/organizations/org_0')
    taxonomy_manager.create_organization('0', 'BrightMove', 'Primary organization for BrightMove content')
  end
  
  # Add some example content to org_0
  puts "\n📝 Adding example Wiseguy content..."
  
  # Add metadata
  content_manager.add_metadata('0', 'system_config', {
    'ai_model' => 'gpt-4',
    'max_tokens' => 4000,
    'temperature' => 0.7
  })
  
  # Add hints
  content_manager.add_hint('0', 'API Integration', 
    'When integrating with external APIs, always include proper error handling and rate limiting.',
    'development', 'high')
  
  content_manager.add_hint('0', 'Documentation Standards',
    'All new features must include updated documentation in both Confluence and Intercom Help Center.',
    'process', 'medium')
  
  # Add prompts
  content_manager.add_prompt('0', 'Ticket Analysis',
    'Analyze the following {{ticket_type}} ticket for consistency with our documentation and implementation:\n\n{{ticket_content}}\n\nProvide a detailed analysis including:\n1. Documentation gaps\n2. Implementation inconsistencies\n3. Recommended actions',
    ['ticket_type', 'ticket_content'],
    'Standard prompt for analyzing support tickets and feature requests')
  
  # Generate and display report
  report = content_manager.generate_report('0')
  puts "\n📊 Wiseguy Content Report:"
  puts JSON.pretty_generate(report)
end
