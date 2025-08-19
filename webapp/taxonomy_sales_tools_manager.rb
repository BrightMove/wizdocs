require_relative '../content-repo/taxonomy_manager'
require_relative '../content-repo/sync_connector_manager'
require_relative '../content-repo/wiseguy_content_manager'
require_relative '../content-repo/knowledge_base_manager'

# Sales Tools Management with Taxonomy Integration
class TaxonomySalesToolsManager
  def initialize
    @kb_manager = KnowledgeBaseManager.new
    @taxonomy_manager = @kb_manager.taxonomy_manager
    
    # Define the new paths based on taxonomy structure
    @rfp_dir = File.expand_path('../content-repo/organizations/org_0/content_sources/general/private/static/rfp_projects', __FILE__)
    @sow_dir = File.expand_path('../content-repo/organizations/org_0/content_sources/general/private/static/sow_projects', __FILE__)
    @proposal_dir = File.expand_path('../content-repo/organizations/org_0/content_sources/general/private/static/proposal_projects', __FILE__)
  end

  def list_rfp_projects
    return [] unless Dir.exist?(@rfp_dir)
    
    begin
      Dir.entries(@rfp_dir).select do |entry|
        next if entry.start_with?('.')
        File.directory?(File.join(@rfp_dir, entry))
      end.sort.reverse
    rescue => e
      puts "Error listing RFP projects: #{e.message}"
      []
    end
  end

  def list_sow_projects
    return [] unless Dir.exist?(@sow_dir)
    
    begin
      Dir.entries(@sow_dir).select do |entry|
        next if entry.start_with?('.')
        File.directory?(File.join(@sow_dir, entry))
      end.sort.reverse
    rescue => e
      puts "Error listing SOW projects: #{e.message}"
      []
    end
  end

  def list_proposal_projects
    return [] unless Dir.exist?(@proposal_dir)
    
    begin
      Dir.entries(@proposal_dir).select do |entry|
        next if entry.start_with?('.')
        File.directory?(File.join(@proposal_dir, entry))
      end.sort.reverse
    rescue => e
      puts "Error listing proposal projects: #{e.message}"
      []
    end
  end

  def get_rfp_project_info(project_name)
    project_path = File.join(@rfp_dir, project_name)
    return nil unless Dir.exist?(project_path)

    input_dir = File.join(project_path, 'input')
    output_dir = File.join(project_path, 'output')
    final_dir = File.join(project_path, 'final')
    
    begin
      last_modified = File.mtime(project_path).strftime('%Y-%m-%d %H:%M:%S')
    rescue => e
      last_modified = 'Unknown'
    end
    
    # Try to get creation date from .created file, fallback to directory creation time
    begin
      created_file = File.join(project_path, '.created')
      if File.exist?(created_file)
        created_date = File.read(created_file).strip
      else
        created_date = File.ctime(project_path).strftime('%Y-%m-%d %H:%M:%S')
      end
    rescue => e
      created_date = 'Unknown'
    end
    
    {
      name: project_name,
      type: 'RFP',
      input_files: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      output_files: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      final_files: Dir.exist?(final_dir) ? (begin; Dir.entries(final_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      python_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.py') && !f.start_with?('.') }; rescue; []; end),
      text_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.txt', '.md') && !f.start_with?('.') }; rescue; []; end),
      input_count: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      output_count: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      final_count: Dir.exist?(final_dir) ? (begin; Dir.entries(final_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      created_date: created_date,
      last_modified: last_modified,
      path: project_path
    }
  end

  def get_sow_project_info(project_name)
    project_path = File.join(@sow_dir, project_name)
    return nil unless Dir.exist?(project_path)

    input_dir = File.join(project_path, 'input')
    output_dir = File.join(project_path, 'output')
    
    begin
      last_modified = File.mtime(project_path).strftime('%Y-%m-%d %H:%M:%S')
    rescue => e
      last_modified = 'Unknown'
    end
    
    # Try to get creation date from .created file, fallback to directory creation time
    begin
      created_file = File.join(project_path, '.created')
      if File.exist?(created_file)
        created_date = File.read(created_file).strip
      else
        created_date = File.ctime(project_path).strftime('%Y-%m-%d %H:%M:%S')
      end
    rescue => e
      created_date = 'Unknown'
    end
    
    {
      name: project_name,
      type: 'SOW',
      input_files: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      output_files: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      python_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.py') && !f.start_with?('.') }; rescue; []; end),
      text_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.txt', '.md') && !f.start_with?('.') }; rescue; []; end),
      input_count: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      output_count: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      created_date: created_date,
      last_modified: last_modified,
      path: project_path
    }
  end

  def get_proposal_project_info(project_name)
    project_path = File.join(@proposal_dir, project_name)
    return nil unless Dir.exist?(project_path)

    input_dir = File.join(project_path, 'input')
    output_dir = File.join(project_path, 'output')
    
    begin
      last_modified = File.mtime(project_path).strftime('%Y-%m-%d %H:%M:%S')
    rescue => e
      last_modified = 'Unknown'
    end
    
    # Try to get creation date from .created file, fallback to directory creation time
    begin
      created_file = File.join(project_path, '.created')
      if File.exist?(created_file)
        created_date = File.read(created_file).strip
      else
        created_date = File.ctime(project_path).strftime('%Y-%m-%d %H:%M:%S')
      end
    rescue => e
      created_date = 'Unknown'
    end
    
    {
      name: project_name,
      type: 'Proposal',
      input_files: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      output_files: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      python_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.py') && !f.start_with?('.') }; rescue; []; end),
      text_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.txt', '.md') && !f.start_with?('.') }; rescue; []; end),
      input_count: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      output_count: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      created_date: created_date,
      last_modified: last_modified,
      path: project_path
    }
  end

  def create_rfp_project(project_name)
    project_path = File.join(@rfp_dir, project_name)
    
    if Dir.exist?(project_path)
      return { success: false, message: "Project '#{project_name}' already exists" }
    end
    
    begin
      FileUtils.mkdir_p(project_path)
      FileUtils.mkdir_p(File.join(project_path, 'input'))
      FileUtils.mkdir_p(File.join(project_path, 'output'))
      FileUtils.mkdir_p(File.join(project_path, 'final'))
      
      # Create .created file with timestamp
      File.write(File.join(project_path, '.created'), Time.now.strftime('%Y-%m-%d %H:%M:%S'))
      
      # Update taxonomy metadata
      update_taxonomy_metadata('rfp_projects', project_name)
      
      { success: true, message: "RFP project '#{project_name}' created successfully" }
    rescue => e
      { success: false, message: "Error creating project: #{e.message}" }
    end
  end

  def create_sow_project(project_name)
    project_path = File.join(@sow_dir, project_name)
    
    if Dir.exist?(project_path)
      return { success: false, message: "Project '#{project_name}' already exists" }
    end
    
    begin
      FileUtils.mkdir_p(project_path)
      FileUtils.mkdir_p(File.join(project_path, 'input'))
      FileUtils.mkdir_p(File.join(project_path, 'output'))
      
      # Create .created file with timestamp
      File.write(File.join(project_path, '.created'), Time.now.strftime('%Y-%m-%d %H:%M:%S'))
      
      # Update taxonomy metadata
      update_taxonomy_metadata('sow_projects', project_name)
      
      { success: true, message: "SOW project '#{project_name}' created successfully" }
    rescue => e
      { success: false, message: "Error creating project: #{e.message}" }
    end
  end

  def create_proposal_project(project_name)
    project_path = File.join(@proposal_dir, project_name)
    
    if Dir.exist?(project_path)
      return { success: false, message: "Project '#{project_name}' already exists" }
    end
    
    begin
      FileUtils.mkdir_p(project_path)
      FileUtils.mkdir_p(File.join(project_path, 'input'))
      FileUtils.mkdir_p(File.join(project_path, 'output'))
      
      # Create .created file with timestamp
      File.write(File.join(project_path, '.created'), Time.now.strftime('%Y-%m-%d %H:%M:%S'))
      
      # Update taxonomy metadata
      update_taxonomy_metadata('proposal_projects', project_name)
      
      { success: true, message: "Proposal project '#{project_name}' created successfully" }
    rescue => e
      { success: false, message: "Error creating project: #{e.message}" }
    end
  end

  def delete_rfp_project(project_name)
    project_path = File.join(@rfp_dir, project_name)
    
    unless Dir.exist?(project_path)
      return { success: false, message: "Project '#{project_name}' does not exist" }
    end
    
    begin
      FileUtils.rm_rf(project_path)
      { success: true, message: "RFP project '#{project_name}' deleted successfully" }
    rescue => e
      { success: false, message: "Error deleting project: #{e.message}" }
    end
  end

  def delete_sow_project(project_name)
    project_path = File.join(@sow_dir, project_name)
    
    unless Dir.exist?(project_path)
      return { success: false, message: "Project '#{project_name}' does not exist" }
    end
    
    begin
      FileUtils.rm_rf(project_path)
      { success: true, message: "SOW project '#{project_name}' deleted successfully" }
    rescue => e
      { success: false, message: "Error deleting project: #{e.message}" }
    end
  end

  def delete_proposal_project(project_name)
    project_path = File.join(@proposal_dir, project_name)
    
    unless Dir.exist?(project_path)
      return { success: false, message: "Project '#{project_name}' does not exist" }
    end
    
    begin
      FileUtils.rm_rf(project_path)
      { success: true, message: "Proposal project '#{project_name}' deleted successfully" }
    rescue => e
      { success: false, message: "Error deleting project: #{e.message}" }
    end
  end

  def run_rfp_script(project_name, script_name)
    project_path = File.join(@rfp_dir, project_name)
    script_path = File.join(project_path, script_name)
    
    unless File.exist?(script_path)
      return { success: false, message: "Script '#{script_name}' not found in project '#{project_name}'" }
    end
    
    begin
      # Run the script
      output = `cd "#{project_path}" && python "#{script_name}" 2>&1`
      exit_code = $?.exitstatus
      
      if exit_code == 0
        { success: true, message: "Script executed successfully", output: output }
      else
        { success: false, message: "Script execution failed", output: output }
      end
    rescue => e
      { success: false, message: "Error running script: #{e.message}" }
    end
  end

  def run_sow_script(project_name, script_name)
    project_path = File.join(@sow_dir, project_name)
    script_path = File.join(project_path, script_name)
    
    unless File.exist?(script_path)
      return { success: false, message: "Script '#{script_name}' not found in project '#{project_name}'" }
    end
    
    begin
      # Run the script
      output = `cd "#{project_path}" && python "#{script_name}" 2>&1`
      exit_code = $?.exitstatus
      
      if exit_code == 0
        { success: true, message: "Script executed successfully", output: output }
      else
        { success: false, message: "Script execution failed", output: output }
      end
    rescue => e
      { success: false, message: "Error running script: #{e.message}" }
    end
  end

  def run_proposal_script(project_name, script_name)
    project_path = File.join(@proposal_dir, project_name)
    script_path = File.join(project_path, script_name)
    
    unless File.exist?(script_path)
      return { success: false, message: "Script '#{script_name}' not found in project '#{project_name}'" }
    end
    
    begin
      # Run the script
      output = `cd "#{project_path}" && python "#{script_name}" 2>&1`
      exit_code = $?.exitstatus
      
      if exit_code == 0
        { success: true, message: "Script executed successfully", output: output }
      else
        { success: false, message: "Script execution failed", output: output }
      end
    rescue => e
      { success: false, message: "Error running script: #{e.message}" }
    end
  end

  def get_project_estimated_value(project_name, project_type)
    # This would integrate with actual business logic
    # For now, return a placeholder value
    case project_type
    when 'rfp'
      rand(50000..500000)
    when 'sow'
      rand(25000..250000)
    when 'proposal'
      rand(10000..100000)
    else
      0
    end
  end

  def get_sales_tools_summary
    rfp_projects = list_rfp_projects
    sow_projects = list_sow_projects
    proposal_projects = list_proposal_projects
    
    {
      total_projects: rfp_projects.length + sow_projects.length + proposal_projects.length,
      rfp_projects: rfp_projects.length,
      sow_projects: sow_projects.length,
      proposal_projects: proposal_projects.length,
      recent_projects: get_recent_projects(5)
    }
  end

  def get_taxonomy_info
    # Get taxonomy information for the sales tools content sources
    {
      organization: @taxonomy_manager.get_organization('0'),
      content_sources: @taxonomy_manager.list_content_sources('0'),
      rfp_source: @taxonomy_manager.get_content_source('0', 'rfp_projects'),
      sow_source: @taxonomy_manager.get_content_source('0', 'sow_projects'),
      proposal_source: @taxonomy_manager.get_content_source('0', 'proposal_projects')
    }
  end

  private

  def get_recent_projects(limit = 5)
    all_projects = []
    
    # Get RFP projects
    list_rfp_projects.each do |name|
      info = get_rfp_project_info(name)
      all_projects << info if info
    end
    
    # Get SOW projects
    list_sow_projects.each do |name|
      info = get_sow_project_info(name)
      all_projects << info if info
    end
    
    # Get proposal projects
    list_proposal_projects.each do |name|
      info = get_proposal_project_info(name)
      all_projects << info if info
    end
    
    # Sort by last modified and return the most recent
    all_projects.sort_by { |p| p[:last_modified] }.reverse.first(limit)
  end

  def update_taxonomy_metadata(source_name, project_name)
    # Update the taxonomy metadata when projects are created
    begin
      source = @taxonomy_manager.get_content_source('0', source_name)
      if source
        @taxonomy_manager.update_sync_status('0', source_name, 'updated')
      end
    rescue => e
      puts "Warning: Could not update taxonomy metadata: #{e.message}"
    end
  end
end
