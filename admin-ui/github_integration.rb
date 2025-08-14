#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'open3'
require 'fileutils'
require 'time'
require_relative 'knowledge_base_conflict_detector'

class GitHubIntegration
  def initialize
    @github_token = ENV['GITHUB_TOKEN']
    @github_webhook_secret = ENV['GITHUB_WEBHOOK_SECRET']
    @github_api_base = 'https://api.github.com'
    
    unless @github_token
      puts "Warning: GITHUB_TOKEN not configured. Set GITHUB_TOKEN in config.env"
    end
  end

  def connected?
    @github_token && !@github_token.empty?
  end

  def make_request(endpoint, method = :get, data = nil)
    uri = URI("#{@github_api_base}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = case method
    when :get
      Net::HTTP::Get.new(uri)
    when :post
      Net::HTTP::Post.new(uri)
    when :put
      Net::HTTP::Put.new(uri)
    when :patch
      Net::HTTP::Patch.new(uri)
    end
    
    request['Authorization'] = "token #{@github_token}"
    request['Accept'] = 'application/vnd.github.v3+json'
    request['Content-Type'] = 'application/json'
    
    if data
      request.body = data.to_json
    end
    
    response = http.request(request)
    
    case response.code
    when '200', '201'
      JSON.parse(response.body)
    when '401'
      { error: 'GitHub authentication failed' }
    when '403'
      { error: 'GitHub permission denied' }
    when '404'
      { error: 'GitHub resource not found' }
    else
      { error: "GitHub API error #{response.code}: #{response.body}" }
    end
  rescue => e
    { error: "GitHub request failed: #{e.message}" }
  end

  def get_pull_request(repo, pr_number)
    return { error: 'GitHub not configured' } unless connected?
    
    endpoint = "/repos/#{repo}/pulls/#{pr_number}"
    make_request(endpoint)
  end

  def get_pull_request_files(repo, pr_number)
    return { error: 'GitHub not configured' } unless connected?
    
    endpoint = "/repos/#{repo}/pulls/#{pr_number}/files"
    make_request(endpoint)
  end

  def get_pull_request_commits(repo, pr_number)
    return { error: 'GitHub not configured' } unless connected?
    
    endpoint = "/repos/#{repo}/pulls/#{pr_number}/commits"
    make_request(endpoint)
  end

  def get_commit_details(repo, commit_sha)
    return { error: 'GitHub not configured' } unless connected?
    
    endpoint = "/repos/#{repo}/commits/#{commit_sha}"
    make_request(endpoint)
  end

  def get_repository_content(repo, path, ref = 'main')
    return { error: 'GitHub not configured' } unless connected?
    
    endpoint = "/repos/#{repo}/contents/#{path}?ref=#{ref}"
    make_request(endpoint)
  end

  def analyze_pull_request_impact(repo, pr_number)
    puts "Analyzing PR ##{pr_number} impact on knowledge base..."
    
    # Get PR details
    pr = get_pull_request(repo, pr_number)
    return pr if pr.is_a?(Hash) && pr[:error]
    
    # Get changed files
    files = get_pull_request_files(repo, pr_number)
    return files if files.is_a?(Hash) && files[:error]
    
    # Get commits
    commits = get_pull_request_commits(repo, pr_number)
    return commits if commits.is_a?(Hash) && commits[:error]
    
    # Analyze impact
    impact_analysis = {
      pr_number: pr_number,
      repo: repo,
      title: pr['title'],
      description: pr['body'],
      author: pr['user']['login'],
      merged_at: pr['merged_at'],
      base_branch: pr['base']['ref'],
      head_branch: pr['head']['ref'],
      changed_files: files.length,
      commits_count: commits.length,
      impact_level: 'low',
      knowledge_base_impact: [],
      documentation_updates_needed: [],
      api_changes: [],
      database_changes: [],
      configuration_changes: [],
      security_implications: [],
      breaking_changes: [],
      recommendations: []
    }
    
    # Analyze each changed file
    files.each do |file|
      file_impact = analyze_file_impact(file, repo)
      impact_analysis[:knowledge_base_impact] << file_impact if file_impact[:has_impact]
      
      # Categorize changes
      categorize_file_changes(file, impact_analysis)
    end
    
    # Determine overall impact level
    impact_analysis[:impact_level] = determine_impact_level(impact_analysis)
    
    # Generate recommendations
    impact_analysis[:recommendations] = generate_recommendations(impact_analysis)
    
    impact_analysis
  end

  def detect_knowledge_base_conflicts(repo, pr_number)
    puts "Detecting knowledge base conflicts from PR ##{pr_number}..."
    
    conflict_detector = KnowledgeBaseConflictDetector.new
    conflict_report = conflict_detector.detect_conflicts_from_pr(repo, pr_number)
    
    if conflict_report[:error]
      puts "Error detecting conflicts: #{conflict_report[:error]}"
      return conflict_report
    end
    
    puts "Found #{conflict_report[:conflicts_found]} conflicts in knowledge base"
    conflict_report
  end

  private

  def analyze_file_impact(file, repo)
    filename = file['filename']
    status = file['status']
    additions = file['additions'] || 0
    deletions = file['deletions'] || 0
    
    impact = {
      file: filename,
      status: status,
      additions: additions,
      deletions: deletions,
      has_impact: false,
      impact_type: [],
      description: []
    }
    
    # Check for documentation files
    if filename.match?(/\.(md|rst|txt)$/i) || filename.include?('docs/') || filename.include?('README')
      impact[:has_impact] = true
      impact[:impact_type] << 'documentation'
      impact[:description] << "Documentation file #{status}"
    end
    
    # Check for API changes
    if filename.match?(/\.(java|py|js|ts|rb|php|go|cs)$/i) && 
       (filename.include?('controller') || filename.include?('api') || filename.include?('endpoint'))
      impact[:has_impact] = true
      impact[:impact_type] << 'api'
      impact[:description] << "API code changes detected"
    end
    
    # Check for database changes
    if filename.match?(/\.(sql|migration|schema)$/i) || filename.include?('migration')
      impact[:has_impact] = true
      impact[:impact_type] << 'database'
      impact[:description] << "Database schema changes detected"
    end
    
    # Check for configuration changes
    if filename.match?(/\.(yml|yaml|json|properties|conf|config)$/i) || filename.include?('config/')
      impact[:has_impact] = true
      impact[:impact_type] << 'configuration'
      impact[:description] << "Configuration changes detected"
    end
    
    # Check for security-related changes
    if filename.include?('security') || filename.include?('auth') || filename.include?('permission')
      impact[:has_impact] = true
      impact[:impact_type] << 'security'
      impact[:description] << "Security-related changes detected"
    end
    
    # Check for significant code changes
    if additions > 50 || deletions > 50
      impact[:has_impact] = true
      impact[:impact_type] << 'significant_code'
      impact[:description] << "Significant code changes (#{additions} additions, #{deletions} deletions)"
    end
    
    impact
  end

  def categorize_file_changes(file, impact_analysis)
    filename = file['filename']
    status = file['status']
    
    # API changes
    if filename.match?(/\.(java|py|js|ts|rb|php|go|cs)$/i) && 
       (filename.include?('controller') || filename.include?('api') || filename.include?('endpoint'))
      impact_analysis[:api_changes] << {
        file: filename,
        status: status,
        description: "API endpoint or controller changes"
      }
    end
    
    # Database changes
    if filename.match?(/\.(sql|migration|schema)$/i) || filename.include?('migration')
      impact_analysis[:database_changes] << {
        file: filename,
        status: status,
        description: "Database schema or migration changes"
      }
    end
    
    # Configuration changes
    if filename.match?(/\.(yml|yaml|json|properties|conf|config)$/i) || filename.include?('config/')
      impact_analysis[:configuration_changes] << {
        file: filename,
        status: status,
        description: "Configuration or environment changes"
      }
    end
    
    # Security implications
    if filename.include?('security') || filename.include?('auth') || filename.include?('permission')
      impact_analysis[:security_implications] << {
        file: filename,
        status: status,
        description: "Security or authentication changes"
      }
    end
    
    # Breaking changes (based on file patterns)
    if filename.include?('breaking') || filename.include?('deprecate') || 
       (status == 'removed' && filename.match?(/\.(java|py|js|ts|rb|php|go|cs)$/i))
      impact_analysis[:breaking_changes] << {
        file: filename,
        status: status,
        description: "Potential breaking changes detected"
      }
    end
  end

  def determine_impact_level(impact_analysis)
    score = 0
    
    # High impact indicators
    score += 10 if impact_analysis[:breaking_changes].any?
    score += 8 if impact_analysis[:api_changes].any?
    score += 6 if impact_analysis[:database_changes].any?
    score += 5 if impact_analysis[:security_implications].any?
    
    # Medium impact indicators
    score += 3 if impact_analysis[:configuration_changes].any?
    score += 2 if impact_analysis[:changed_files] > 10
    score += 1 if impact_analysis[:commits_count] > 5
    
    # Low impact indicators
    score += 1 if impact_analysis[:knowledge_base_impact].any?
    
    case score
    when 0..3
      'low'
    when 4..8
      'medium'
    else
      'high'
    end
  end

  def generate_recommendations(impact_analysis)
    recommendations = []
    
    # API changes
    if impact_analysis[:api_changes].any?
      recommendations << {
        type: 'api_documentation',
        priority: 'high',
        description: 'Update API documentation to reflect endpoint changes',
        action: 'Review and update API documentation, OpenAPI specs, and integration guides'
      }
    end
    
    # Database changes
    if impact_analysis[:database_changes].any?
      recommendations << {
        type: 'database_documentation',
        priority: 'high',
        description: 'Update database documentation and migration guides',
        action: 'Review and update schema documentation, migration procedures, and data models'
      }
    end
    
    # Security changes
    if impact_analysis[:security_implications].any?
      recommendations << {
        type: 'security_documentation',
        priority: 'high',
        description: 'Update security documentation and procedures',
        action: 'Review and update security documentation, authentication procedures, and compliance docs'
      }
    end
    
    # Breaking changes
    if impact_analysis[:breaking_changes].any?
      recommendations << {
        type: 'breaking_changes',
        priority: 'critical',
        description: 'Document breaking changes and migration procedures',
        action: 'Create migration guide, update release notes, and notify stakeholders'
      }
    end
    
    # Configuration changes
    if impact_analysis[:configuration_changes].any?
      recommendations << {
        type: 'configuration_documentation',
        priority: 'medium',
        description: 'Update configuration documentation',
        action: 'Review and update deployment guides, configuration examples, and environment setup docs'
      }
    end
    
    # General documentation updates
    if impact_analysis[:knowledge_base_impact].any?
      recommendations << {
        type: 'general_documentation',
        priority: 'medium',
        description: 'Review and update related documentation',
        action: 'Review all documentation for accuracy and completeness based on code changes'
      }
    end
    
    recommendations
  end
end

class KnowledgeBaseImpactAnalyzer
  def initialize
    @github_integration = GitHubIntegration.new
    @content_analysis_service = ContentAnalysisService.new
  end

  def analyze_pr_impact_on_knowledge_base(repo, pr_number)
    puts "Analyzing PR ##{pr_number} impact on knowledge base..."
    
    # Get PR impact analysis
    pr_impact = @github_integration.analyze_pull_request_impact(repo, pr_number)
    return pr_impact if pr_impact.is_a?(Hash) && pr_impact[:error]
    
    # Detect knowledge base conflicts
    conflict_report = @github_integration.detect_knowledge_base_conflicts(repo, pr_number)
    
    # Get current knowledge base content
    confluence_content = get_confluence_content
    intercom_content = get_intercom_content
    jira_tickets = get_all_tickets
    
    # Analyze impact on existing content
    content_impact = analyze_content_impact(pr_impact, confluence_content, intercom_content, jira_tickets)
    
    # Generate comprehensive impact report
    {
      pr_analysis: pr_impact,
      content_impact: content_impact,
      conflict_analysis: conflict_report,
      recommendations: generate_knowledge_base_recommendations(pr_impact, content_impact, conflict_report),
      timestamp: Time.now.iso8601
    }
  end

  private

  def analyze_content_impact(pr_impact, confluence_content, intercom_content, jira_tickets)
    content_impact = {
      affected_confluence_pages: [],
      affected_intercom_articles: [],
      affected_jira_tickets: [],
      outdated_documentation: [],
      missing_documentation: [],
      accuracy_issues: []
    }
    
    # Analyze API changes impact
    if pr_impact[:api_changes].any?
      api_impact = analyze_api_changes_impact(pr_impact[:api_changes], confluence_content, intercom_content)
      content_impact[:affected_confluence_pages].concat(api_impact[:confluence_pages])
      content_impact[:affected_intercom_articles].concat(api_impact[:intercom_articles])
      content_impact[:outdated_documentation].concat(api_impact[:outdated_docs])
    end
    
    # Analyze database changes impact
    if pr_impact[:database_changes].any?
      db_impact = analyze_database_changes_impact(pr_impact[:database_changes], confluence_content, intercom_content)
      content_impact[:affected_confluence_pages].concat(db_impact[:confluence_pages])
      content_impact[:affected_intercom_articles].concat(db_impact[:intercom_articles])
      content_impact[:outdated_documentation].concat(db_impact[:outdated_docs])
    end
    
    # Analyze security changes impact
    if pr_impact[:security_implications].any?
      security_impact = analyze_security_changes_impact(pr_impact[:security_implications], confluence_content, intercom_content)
      content_impact[:affected_confluence_pages].concat(security_impact[:confluence_pages])
      content_impact[:affected_intercom_articles].concat(security_impact[:intercom_articles])
      content_impact[:outdated_documentation].concat(security_impact[:outdated_docs])
    end
    
    # Remove duplicates
    content_impact.each do |key, value|
      content_impact[key] = value.uniq if value.is_a?(Array)
    end
    
    content_impact
  end

  def analyze_api_changes_impact(api_changes, confluence_content, intercom_content)
    impact = {
      confluence_pages: [],
      intercom_articles: [],
      outdated_docs: []
    }
    
    api_changes.each do |change|
      file = change[:file]
      
      # Look for API-related content
      confluence_content.each do |page|
        if page[:content]&.downcase&.include?('api') || 
           page[:title]&.downcase&.include?('api') ||
           page[:content]&.downcase&.include?('endpoint')
          impact[:confluence_pages] << {
            page: page[:title],
            url: page[:url],
            reason: "API-related content that may be affected by changes in #{file}"
          }
        end
      end
      
      intercom_content.each do |article|
        if article[:content]&.downcase&.include?('api') || 
           article[:title]&.downcase&.include?('api') ||
           article[:content]&.downcase&.include?('endpoint')
          impact[:intercom_articles] << {
            article: article[:title],
            url: article[:url],
            reason: "API-related content that may be affected by changes in #{file}"
          }
        end
      end
    end
    
    impact
  end

  def analyze_database_changes_impact(db_changes, confluence_content, intercom_content)
    impact = {
      confluence_pages: [],
      intercom_articles: [],
      outdated_docs: []
    }
    
    db_changes.each do |change|
      file = change[:file]
      
      # Look for database-related content
      confluence_content.each do |page|
        if page[:content]&.downcase&.include?('database') || 
           page[:title]&.downcase&.include?('database') ||
           page[:content]&.downcase&.include?('schema') ||
           page[:content]&.downcase&.include?('table')
          impact[:confluence_pages] << {
            page: page[:title],
            url: page[:url],
            reason: "Database-related content that may be affected by changes in #{file}"
          }
        end
      end
      
      intercom_content.each do |article|
        if article[:content]&.downcase&.include?('database') || 
           article[:title]&.downcase&.include?('database') ||
           article[:content]&.downcase&.include?('schema') ||
           article[:content]&.downcase&.include?('table')
          impact[:intercom_articles] << {
            article: article[:title],
            url: article[:url],
            reason: "Database-related content that may be affected by changes in #{file}"
          }
        end
      end
    end
    
    impact
  end

  def analyze_security_changes_impact(security_changes, confluence_content, intercom_content)
    impact = {
      confluence_pages: [],
      intercom_articles: [],
      outdated_docs: []
    }
    
    security_changes.each do |change|
      file = change[:file]
      
      # Look for security-related content
      confluence_content.each do |page|
        if page[:content]&.downcase&.include?('security') || 
           page[:title]&.downcase&.include?('security') ||
           page[:content]&.downcase&.include?('auth') ||
           page[:content]&.downcase&.include?('permission')
          impact[:confluence_pages] << {
            page: page[:title],
            url: page[:url],
            reason: "Security-related content that may be affected by changes in #{file}"
          }
        end
      end
      
      intercom_content.each do |article|
        if article[:content]&.downcase&.include?('security') || 
           article[:title]&.downcase&.include?('security') ||
           article[:content]&.downcase&.include?('auth') ||
           article[:content]&.downcase&.include?('permission')
          impact[:intercom_articles] << {
            article: article[:title],
            url: article[:url],
            reason: "Security-related content that may be affected by changes in #{file}"
          }
        end
      end
    end
    
    impact
  end

  def generate_knowledge_base_recommendations(pr_impact, content_impact, conflict_report = nil)
    recommendations = []
    
    # High priority recommendations
    if pr_impact[:impact_level] == 'high' || pr_impact[:impact_level] == 'critical'
      recommendations << {
        priority: 'critical',
        type: 'immediate_review',
        description: 'High-impact changes detected - immediate knowledge base review required',
        action: 'Review all affected documentation within 24 hours',
        affected_content: content_impact[:affected_confluence_pages].length + content_impact[:affected_intercom_articles].length
      }
    end
    
    # Knowledge base conflict recommendations
    if conflict_report && conflict_report[:conflicts_found] > 0
      high_severity_conflicts = conflict_report[:summary][:by_severity][:high] + conflict_report[:summary][:by_severity][:critical]
      
      if high_severity_conflicts > 0
        recommendations << {
          priority: 'critical',
          type: 'kb_conflict_resolution',
          description: "#{high_severity_conflicts} high-severity knowledge base conflicts detected",
          action: 'Immediately resolve conflicts between code changes and documentation',
          conflicts_count: high_severity_conflicts,
          conflict_types: conflict_report[:summary][:by_type].keys
        }
      end
      
      if conflict_report[:conflicts_found] > 0
        recommendations << {
          priority: 'high',
          type: 'kb_sync_required',
          description: "#{conflict_report[:conflicts_found]} knowledge base conflicts found - documentation out of sync",
          action: 'Review and update all conflicting documentation to match code changes',
          conflicts_count: conflict_report[:conflicts_found],
          affected_kb_items: conflict_report[:summary][:by_kb_type]
        }
      end
    end
    
    # API documentation updates
    if pr_impact[:api_changes].any?
      recommendations << {
        priority: 'high',
        type: 'api_documentation',
        description: 'Update API documentation to reflect changes',
        action: 'Review and update API documentation, integration guides, and code examples',
        affected_content: content_impact[:affected_confluence_pages].select { |p| p[:reason].include?('API') }.length
      }
    end
    
    # Database documentation updates
    if pr_impact[:database_changes].any?
      recommendations << {
        priority: 'high',
        type: 'database_documentation',
        description: 'Update database documentation and migration guides',
        action: 'Review and update schema documentation, migration procedures, and data models',
        affected_content: content_impact[:affected_confluence_pages].select { |p| p[:reason].include?('database') }.length
      }
    end
    
    # Security documentation updates
    if pr_impact[:security_implications].any?
      recommendations << {
        priority: 'high',
        type: 'security_documentation',
        description: 'Update security documentation and procedures',
        action: 'Review and update security documentation, authentication procedures, and compliance docs',
        affected_content: content_impact[:affected_confluence_pages].select { |p| p[:reason].include?('security') }.length
      }
    end
    
    # General documentation review
    if content_impact[:affected_confluence_pages].any? || content_impact[:affected_intercom_articles].any?
      recommendations << {
        priority: 'medium',
        type: 'general_review',
        description: 'Review affected documentation for accuracy',
        action: 'Review all affected documentation for accuracy and completeness',
        affected_content: content_impact[:affected_confluence_pages].length + content_impact[:affected_intercom_articles].length
      }
    end
    
    recommendations
  end

  def get_confluence_content
    # This would integrate with the existing ConfluenceService
    # For now, return empty array
    []
  end

  def get_intercom_content
    # This would integrate with the existing IntercomService
    # For now, return empty array
    []
  end

  def get_all_tickets
    # This would integrate with the existing JiraService
    # For now, return empty array
    []
  end
end
