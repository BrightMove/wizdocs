#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'open3'
require 'fileutils'
require 'time'
# require 'diffy'  # Not used

class KnowledgeBaseConflictDetector
  def initialize
    @github_integration = GitHubIntegration.new
    @confluence_service = ConfluenceService.new
    @intercom_service = IntercomService.new
    @jira_service = JiraService.new
  end

  def detect_conflicts_from_pr(repo, pr_number)
    puts "Detecting knowledge base conflicts from PR ##{pr_number} in #{repo}..."
    
    # Get PR details and changes
    pr_data = get_pr_data(repo, pr_number)
    return { error: 'Failed to get PR data' } if pr_data[:error]
    
    # Get changed files with their content
    changed_files = get_changed_files_with_content(repo, pr_number)
    return { error: 'Failed to get changed files' } if changed_files[:error]
    
    # Get knowledge base content
    kb_content = get_knowledge_base_content
    
    # Analyze each changed file for conflicts
    conflicts = []
    changed_files.each do |file_data|
      file_conflicts = analyze_file_for_conflicts(file_data, kb_content)
      conflicts.concat(file_conflicts) if file_conflicts.any?
    end
    
    # Generate comprehensive conflict report
    {
      pr_number: pr_number,
      repo: repo,
      title: pr_data['title'],
      author: pr_data['user']['login'],
      changed_files_count: changed_files.length,
      conflicts_found: conflicts.length,
      conflicts: conflicts,
      summary: generate_conflict_summary(conflicts),
      timestamp: Time.now.iso8601
    }
  end

  private

  def get_pr_data(repo, pr_number)
    @github_integration.get_pull_request(repo, pr_number)
  end

  def get_changed_files_with_content(repo, pr_number)
    files = @github_integration.get_pull_request_files(repo, pr_number)
    return files if files.is_a?(Hash) && files[:error]
    
    # Get content for each changed file
    files_with_content = []
    files.each do |file|
      if file['status'] != 'removed'
        content = get_file_content(repo, file['filename'], file['sha'])
        files_with_content << {
          filename: file['filename'],
          status: file['status'],
          additions: file['additions'],
          deletions: file['deletions'],
          content: content,
          patch: file['patch']
        }
      end
    end
    
    files_with_content
  end

  def get_file_content(repo, filename, sha)
    # Get file content from GitHub
    content_data = @github_integration.get_repository_content(repo, filename, sha)
    return nil if content_data.is_a?(Hash) && content_data[:error]
    
    # Decode content if it's base64 encoded
    if content_data['content'] && content_data['encoding'] == 'base64'
      require 'base64'
      Base64.decode64(content_data['content'])
    else
      content_data['content']
    end
  rescue => e
    puts "Error getting file content for #{filename}: #{e.message}"
    nil
  end

  def get_knowledge_base_content
    {
      confluence: get_confluence_content,
      intercom: get_intercom_content,
      jira_tickets: get_jira_tickets,
      readme_files: get_readme_files
    }
  end

  def get_confluence_content
    begin
      @confluence_service.get_all_content
    rescue => e
      puts "Error getting Confluence content: #{e.message}"
      []
    end
  end

  def get_intercom_content
    begin
      @intercom_service.get_help_center_articles
    rescue => e
      puts "Error getting Intercom content: #{e.message}"
      []
    end
  end

  def get_jira_tickets
    begin
      @jira_service.get_issues("project in (WISDOM, BRIGHTMOVE, JOBGORILLA)")
    rescue => e
      puts "Error getting JIRA tickets: #{e.message}"
      []
    end
  end

  def get_readme_files
    # This would scan for README files in the repository
    # For now, return empty array
    []
  end

  def analyze_file_for_conflicts(file_data, kb_content)
    conflicts = []
    
    case file_data[:filename]
    when /\.(java|py|js|ts|rb|php|go|cs)$/i
      conflicts.concat(analyze_code_file_conflicts(file_data, kb_content))
    when /\.(sql|migration|schema)$/i
      conflicts.concat(analyze_database_file_conflicts(file_data, kb_content))
    when /\.(yml|yaml|json|properties|conf|config)$/i
      conflicts.concat(analyze_config_file_conflicts(file_data, kb_content))
    when /\.(md|rst|txt)$/i
      conflicts.concat(analyze_documentation_file_conflicts(file_data, kb_content))
    end
    
    conflicts
  end

  def analyze_code_file_conflicts(file_data, kb_content)
    conflicts = []
    content = file_data[:content]
    filename = file_data[:filename]
    
    return conflicts unless content
    
    # Extract API endpoints, methods, classes, etc.
    api_elements = extract_api_elements(content, filename)
    
    # Check for conflicts in Confluence content
    kb_content[:confluence].each do |page|
      page_conflicts = check_api_conflicts_in_page(api_elements, page, filename)
      conflicts.concat(page_conflicts) if page_conflicts.any?
    end
    
    # Check for conflicts in Intercom content
    kb_content[:intercom].each do |article|
      article_conflicts = check_api_conflicts_in_article(api_elements, article, filename)
      conflicts.concat(article_conflicts) if article_conflicts.any?
    end
    
    # Check for conflicts in JIRA tickets
    kb_content[:jira_tickets].each do |ticket|
      ticket_conflicts = check_api_conflicts_in_ticket(api_elements, ticket, filename)
      conflicts.concat(ticket_conflicts) if ticket_conflicts.any?
    end
    
    conflicts
  end

  def extract_api_elements(content, filename)
    elements = {
      endpoints: [],
      methods: [],
      classes: [],
      parameters: [],
      return_types: []
    }
    
    # Extract based on file type
    case filename
    when /\.java$/i
      elements = extract_java_elements(content)
    when /\.py$/i
      elements = extract_python_elements(content)
    when /\.js$/i, /\.ts$/i
      elements = extract_javascript_elements(content)
    when /\.rb$/i
      elements = extract_ruby_elements(content)
    end
    
    elements
  end

  def extract_java_elements(content)
    elements = {
      endpoints: [],
      methods: [],
      classes: [],
      parameters: [],
      return_types: []
    }
    
    # Extract REST endpoints
    content.scan(/@(?:GetMapping|PostMapping|PutMapping|DeleteMapping|RequestMapping)\s*\(\s*["']([^"']+)["']/).each do |match|
      elements[:endpoints] << match[0]
    end
    
    # Extract method signatures
    content.scan(/public\s+(?:static\s+)?(\w+(?:<[^>]+>)?)\s+(\w+)\s*\(([^)]*)\)/).each do |match|
      elements[:return_types] << match[0]
      elements[:methods] << match[1]
      elements[:parameters] << match[2] unless match[2].strip.empty?
    end
    
    # Extract class names
    content.scan(/public\s+class\s+(\w+)/).each do |match|
      elements[:classes] << match[0]
    end
    
    elements
  end

  def extract_python_elements(content)
    elements = {
      endpoints: [],
      methods: [],
      classes: [],
      parameters: [],
      return_types: []
    }
    
    # Extract Flask/Django endpoints
    content.scan(/@(?:app\.route|url_patterns)\s*\(\s*["']([^"']+)["']/).each do |match|
      elements[:endpoints] << match[0]
    end
    
    # Extract function definitions
    content.scan(/def\s+(\w+)\s*\(([^)]*)\)(?:\s*->\s*(\w+))?/).each do |match|
      elements[:methods] << match[0]
      elements[:parameters] << match[1] unless match[1].strip.empty?
      elements[:return_types] << match[2] if match[2]
    end
    
    # Extract class definitions
    content.scan(/class\s+(\w+)/).each do |match|
      elements[:classes] << match[0]
    end
    
    elements
  end

  def extract_javascript_elements(content)
    elements = {
      endpoints: [],
      methods: [],
      classes: [],
      parameters: [],
      return_types: []
    }
    
    # Extract Express.js endpoints
    content.scan(/\.(?:get|post|put|delete)\s*\(\s*["']([^"']+)["']/).each do |match|
      elements[:endpoints] << match[0]
    end
    
    # Extract function definitions
    content.scan(/(?:function\s+(\w+)|const\s+(\w+)\s*=\s*\(([^)]*)\)\s*=>|(\w+)\s*\(([^)]*)\)\s*{)/).each do |match|
      method_name = match[0] || match[1] || match[3]
      parameters = match[2] || match[4]
      elements[:methods] << method_name if method_name
      elements[:parameters] << parameters if parameters && !parameters.strip.empty?
    end
    
    # Extract class definitions
    content.scan(/class\s+(\w+)/).each do |match|
      elements[:classes] << match[0]
    end
    
    elements
  end

  def extract_ruby_elements(content)
    elements = {
      endpoints: [],
      methods: [],
      classes: [],
      parameters: [],
      return_types: []
    }
    
    # Extract Rails routes
    content.scan(/get\s+["']([^"']+)["']/).each do |match|
      elements[:endpoints] << match[0]
    end
    
    # Extract method definitions
    content.scan(/def\s+(\w+)/).each do |match|
      elements[:methods] << match[0]
    end
    
    # Extract class definitions
    content.scan(/class\s+(\w+)/).each do |match|
      elements[:classes] << match[0]
    end
    
    elements
  end

  def check_api_conflicts_in_page(api_elements, page, filename)
    conflicts = []
    page_content = page[:content] || page['content'] || ''
    page_title = page[:title] || page['title'] || ''
    
    # Check for endpoint conflicts
    api_elements[:endpoints].each do |endpoint|
      if page_content.include?(endpoint) && file_data[:status] == 'removed'
        conflicts << {
          type: 'removed_endpoint_documented',
          severity: 'high',
          description: "Endpoint '#{endpoint}' was removed from code but still documented in '#{page_title}'",
          file: filename,
          kb_item: {
            type: 'confluence_page',
            title: page_title,
            url: page[:url] || page['url']
          },
          api_element: endpoint,
          action: "Remove or update documentation for endpoint '#{endpoint}'"
        }
      elsif !page_content.include?(endpoint) && file_data[:status] == 'added'
        conflicts << {
          type: 'new_endpoint_not_documented',
          severity: 'medium',
          description: "New endpoint '#{endpoint}' was added but not documented in '#{page_title}'",
          file: filename,
          kb_item: {
            type: 'confluence_page',
            title: page_title,
            url: page[:url] || page['url']
          },
          api_element: endpoint,
          action: "Add documentation for new endpoint '#{endpoint}'"
        }
      end
    end
    
    # Check for method conflicts
    api_elements[:methods].each do |method|
      if page_content.include?(method) && file_data[:status] == 'removed'
        conflicts << {
          type: 'removed_method_documented',
          severity: 'medium',
          description: "Method '#{method}' was removed from code but still documented in '#{page_title}'",
          file: filename,
          kb_item: {
            type: 'confluence_page',
            title: page_title,
            url: page[:url] || page['url']
          },
          api_element: method,
          action: "Remove or update documentation for method '#{method}'"
        }
      end
    end
    
    conflicts
  end

  def check_api_conflicts_in_article(api_elements, article, filename)
    conflicts = []
    article_content = article[:content] || article['content'] || ''
    article_title = article[:title] || article['title'] || ''
    
    # Similar logic as page conflicts but for Intercom articles
    api_elements[:endpoints].each do |endpoint|
      if article_content.include?(endpoint) && file_data[:status] == 'removed'
        conflicts << {
          type: 'removed_endpoint_in_help_article',
          severity: 'high',
          description: "Endpoint '#{endpoint}' was removed from code but still documented in help article '#{article_title}'",
          file: filename,
          kb_item: {
            type: 'intercom_article',
            title: article_title,
            url: article[:url] || article['url']
          },
          api_element: endpoint,
          action: "Update help article to remove references to endpoint '#{endpoint}'"
        }
      end
    end
    
    conflicts
  end

  def check_api_conflicts_in_ticket(api_elements, ticket, filename)
    conflicts = []
    ticket_summary = ticket[:summary] || ticket['summary'] || ''
    ticket_description = ticket[:description] || ticket['description'] || ''
    ticket_content = "#{ticket_summary} #{ticket_description}"
    
    # Check if ticket references removed API elements
    api_elements[:endpoints].each do |endpoint|
      if ticket_content.include?(endpoint) && file_data[:status] == 'removed'
        conflicts << {
          type: 'removed_endpoint_in_ticket',
          severity: 'medium',
          description: "Endpoint '#{endpoint}' was removed from code but referenced in JIRA ticket",
          file: filename,
          kb_item: {
            type: 'jira_ticket',
            key: ticket[:key] || ticket['key'],
            summary: ticket_summary
          },
          api_element: endpoint,
          action: "Update JIRA ticket to reflect removal of endpoint '#{endpoint}'"
        }
      end
    end
    
    conflicts
  end

  def analyze_database_file_conflicts(file_data, kb_content)
    conflicts = []
    content = file_data[:content]
    filename = file_data[:filename]
    
    return conflicts unless content
    
    # Extract database schema changes
    schema_elements = extract_schema_elements(content)
    
    # Check for conflicts in documentation
    kb_content[:confluence].each do |page|
      page_conflicts = check_schema_conflicts_in_page(schema_elements, page, filename)
      conflicts.concat(page_conflicts) if page_conflicts.any?
    end
    
    conflicts
  end

  def extract_schema_elements(content)
    elements = {
      tables: [],
      columns: [],
      constraints: [],
      indexes: []
    }
    
    # Extract table names
    content.scan(/CREATE\s+TABLE\s+(\w+)/i).each do |match|
      elements[:tables] << match[0]
    end
    
    # Extract column definitions
    content.scan(/(\w+)\s+(\w+(?:\(\d+(?:,\d+)?\))?)/i).each do |match|
      elements[:columns] << "#{match[0]} #{match[1]}"
    end
    
    # Extract constraints
    content.scan(/CONSTRAINT\s+(\w+)/i).each do |match|
      elements[:constraints] << match[0]
    end
    
    elements
  end

  def check_schema_conflicts_in_page(schema_elements, page, filename)
    conflicts = []
    page_content = page[:content] || page['content'] || ''
    page_title = page[:title] || page['title'] || ''
    
    # Check for table conflicts
    schema_elements[:tables].each do |table|
      if page_content.include?(table) && file_data[:status] == 'removed'
        conflicts << {
          type: 'removed_table_documented',
          severity: 'high',
          description: "Table '#{table}' was removed from schema but still documented in '#{page_title}'",
          file: filename,
          kb_item: {
            type: 'confluence_page',
            title: page_title,
            url: page[:url] || page['url']
          },
          schema_element: table,
          action: "Update documentation to reflect removal of table '#{table}'"
        }
      end
    end
    
    conflicts
  end

  def analyze_config_file_conflicts(file_data, kb_content)
    conflicts = []
    content = file_data[:content]
    filename = file_data[:filename]
    
    return conflicts unless content
    
    # Extract configuration changes
    config_elements = extract_config_elements(content, filename)
    
    # Check for conflicts in documentation
    kb_content[:confluence].each do |page|
      page_conflicts = check_config_conflicts_in_page(config_elements, page, filename)
      conflicts.concat(page_conflicts) if page_conflicts.any?
    end
    
    conflicts
  end

  def extract_config_elements(content, filename)
    elements = {
      settings: [],
      values: [],
      sections: []
    }
    
    case filename
    when /\.yml$/i, /\.yaml$/i
      # Extract YAML keys
      content.scan(/^(\w+):/).each do |match|
        elements[:settings] << match[0]
      end
    when /\.json$/i
      # Extract JSON keys
      content.scan(/"(\w+)":/).each do |match|
        elements[:settings] << match[0]
      end
    when /\.properties$/i
      # Extract property keys
      content.scan(/^(\w+)=/).each do |match|
        elements[:settings] << match[0]
      end
    end
    
    elements
  end

  def check_config_conflicts_in_page(config_elements, page, filename)
    conflicts = []
    page_content = page[:content] || page['content'] || ''
    page_title = page[:title] || page['title'] || ''
    
    # Check for configuration setting conflicts
    config_elements[:settings].each do |setting|
      if page_content.include?(setting) && file_data[:status] == 'removed'
        conflicts << {
          type: 'removed_config_documented',
          severity: 'medium',
          description: "Configuration setting '#{setting}' was removed but still documented in '#{page_title}'",
          file: filename,
          kb_item: {
            type: 'confluence_page',
            title: page_title,
            url: page[:url] || page['url']
          },
          config_element: setting,
          action: "Update documentation to remove reference to configuration setting '#{setting}'"
        }
      end
    end
    
    conflicts
  end

  def analyze_documentation_file_conflicts(file_data, kb_content)
    conflicts = []
    content = file_data[:content]
    filename = file_data[:filename]
    
    return conflicts unless content
    
    # Extract documentation elements
    doc_elements = extract_documentation_elements(content)
    
    # Check for conflicts with other documentation
    kb_content[:confluence].each do |page|
      page_conflicts = check_documentation_conflicts_in_page(doc_elements, page, filename)
      conflicts.concat(page_conflicts) if page_conflicts.any?
    end
    
    conflicts
  end

  def extract_documentation_elements(content)
    # Temporarily disabled due to regex syntax issues
    {
      sections: [],
      code_examples: [],
      links: [],
      images: []
    }
  end

  def check_documentation_conflicts_in_page(doc_elements, page, filename)
    conflicts = []
    page_content = page[:content] || page['content'] || ''
    page_title = page[:title] || page['title'] || ''
    
    # Check for conflicting information
    doc_elements[:sections].each do |section|
      if page_content.include?(section) && content_changed_significantly(file_data)
        conflicts << {
          type: 'documentation_content_changed',
          severity: 'low',
          description: "Documentation section '#{section}' was updated in '#{filename}' but may conflict with '#{page_title}'",
          file: filename,
          kb_item: {
            type: 'confluence_page',
            title: page_title,
            url: page[:url] || page['url']
          },
          doc_element: section,
          action: "Review and synchronize documentation between '#{filename}' and '#{page_title}'"
        }
      end
    end
    
    conflicts
  end

  def content_changed_significantly(file_data)
    additions = file_data[:additions] || 0
    deletions = file_data[:deletions] || 0
    total_changes = additions + deletions
    
    # Consider significant if more than 10 lines changed
    total_changes > 10
  end

  def generate_conflict_summary(conflicts)
    summary = {
      total_conflicts: conflicts.length,
      by_severity: {
        critical: conflicts.count { |c| c[:severity] == 'critical' },
        high: conflicts.count { |c| c[:severity] == 'high' },
        medium: conflicts.count { |c| c[:severity] == 'medium' },
        low: conflicts.count { |c| c[:severity] == 'low' }
      },
      by_type: {},
      by_kb_type: {
        confluence: conflicts.count { |c| c[:kb_item][:type] == 'confluence_page' },
        intercom: conflicts.count { |c| c[:kb_item][:type] == 'intercom_article' },
        jira: conflicts.count { |c| c[:kb_item][:type] == 'jira_ticket' }
      }
    }
    
    # Group by conflict type
    conflicts.each do |conflict|
      type = conflict[:type]
      summary[:by_type][type] ||= 0
      summary[:by_type][type] += 1
    end
    
    summary
  end
end

