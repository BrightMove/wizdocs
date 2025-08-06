#!/usr/bin/env ruby

require 'sinatra'
require 'erb'
require 'json'
require 'fileutils'
require 'open3'
require 'time'
require 'chronic'
require 'active_support/time'
require 'dotenv'

# Load environment variables
Dotenv.load('config.env') if File.exist?('config.env')

# JIRA Integration using direct HTTP calls
class JiraService
  def initialize
    @site = ENV['JIRA_SITE']
    @username = ENV['JIRA_USERNAME']
    @api_token = ENV['JIRA_API_TOKEN']
    
    unless @site && @username && @api_token
      puts "Warning: JIRA credentials not configured. Set JIRA_SITE, JIRA_USERNAME, and JIRA_API_TOKEN in config.env"
    end
  end

  def connected?
    @site && @username && @api_token
  end

  def make_request(endpoint, method = :get, data = nil)
    require 'net/http'
    require 'json'
    
    uri = URI("#{@site}/rest/api/2#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    request = case method
    when :get
      Net::HTTP::Get.new(uri)
    when :post
      Net::HTTP::Post.new(uri)
    when :put
      Net::HTTP::Put.new(uri)
    when :delete
      Net::HTTP::Delete.new(uri)
    end
    
    request.basic_auth(@username, @api_token)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    
    if data
      request.body = data.to_json
    end
    
    response = http.request(request)
    
    case response.code
    when '200', '201'
      JSON.parse(response.body)
    when '401'
      { error: 'Authentication failed' }
    when '403'
      { error: 'Permission denied' }
    when '404'
      { error: 'Resource not found' }
    else
      { error: "HTTP #{response.code}: #{response.body}" }
    end
  rescue => e
    { error: "Request failed: #{e.message}" }
  end

  def get_projects
    return { error: 'JIRA not configured' } unless connected?

    result = make_request('/project')
    return result if result.is_a?(Hash) && result[:error]
    
    result.map do |project|
      {
        key: project['key'],
        name: project['name'],
        id: project['id'],
        lead: project['lead']&.dig('displayName')
      }
    end
  end

  def get_issues(jql = nil, max_results = 100, project_key = nil)
    return { error: 'JIRA not configured' } unless connected?

    # Build JQL query with project filter if specified
    if project_key && !project_key.empty?
      project_filter = "project = '#{project_key}'"
      jql = jql ? "#{project_filter} AND #{jql}" : project_filter
    end
    
    jql ||= 'ORDER BY created DESC'
    
    # Use search endpoint
    search_data = {
      jql: jql,
      maxResults: max_results,
      fields: ['summary', 'status', 'priority', 'assignee', 'reporter', 'created', 'updated', 'resolution', 'description', 'labels', 'components', 'issuetype', 'project']
    }
    
    result = make_request('/search', :post, search_data)
    return result if result.is_a?(Hash) && result[:error]
    
    return [] if result['issues'].empty?
    
    result['issues'].map do |issue|
      fields = issue['fields']
      {
        key: issue['key'],
        summary: fields['summary'],
        status: fields['status']&.dig('name'),
        priority: fields['priority']&.dig('name'),
        assignee: fields['assignee']&.dig('displayName'),
        reporter: fields['reporter']&.dig('displayName'),
        created: fields['created'],
        updated: fields['updated'],
        resolution: fields['resolution']&.dig('name'),
        description: fields['description'],
        labels: fields['labels'] || [],
        components: (fields['components'] || []).map { |c| c['name'] },
        issue_type: fields['issuetype']&.dig('name'),
        project: fields['project']&.dig('key')
      }
    end
  end

  def get_obsolete_issues(project_key = nil)
    # Find issues that are old and haven't been updated
    old_date = 6.months.ago.strftime('%Y-%m-%d')
    jql = "updated < '#{old_date}' ORDER BY updated ASC"
    get_issues(jql, 200, project_key)
  end

  def get_duplicate_candidates(project_key = nil)
    # Find issues with similar titles (potential duplicates)
    jql = ""
    issues = get_issues(jql, 500, project_key)
    
    return issues if issues.is_a?(Hash) && issues[:error]
    
    # Group by similar titles
    duplicates = []
    processed = Set.new
    
    issues.each_with_index do |issue, i|
      next if processed.include?(i)
      
      similar = []
      title_words = issue[:summary].downcase.split(/\s+/)
      
      issues.each_with_index do |other_issue, j|
        next if i == j || processed.include?(j)
        
        other_words = other_issue[:summary].downcase.split(/\s+/)
        common_words = title_words & other_words
        
        # If more than 50% of words match, consider it a potential duplicate
        if common_words.length > 0 && (common_words.length.to_f / [title_words.length, other_words.length].max) > 0.5
          similar << other_issue
          processed.add(j)
        end
      end
      
      if similar.any?
        similar.unshift(issue)
        duplicates << similar
        processed.add(i)
      end
    end
    
    duplicates
  end
end

# Intercom Integration
class IntercomService
  def initialize
    @access_token = ENV['INTERCOM_ACCESS_TOKEN']
    @client_id = ENV['INTERCOM_CLIENT_ID']
    @client_secret = ENV['INTERCOM_CLIENT_SECRET']
    
    unless @access_token
      puts "Warning: Intercom credentials not configured. Set INTERCOM_ACCESS_TOKEN in config.env"
    end
  end

  def connected?
    @access_token
  end

  def get_conversations(days_back = 30)
    return { error: 'Intercom not configured' } unless connected?

    # Intercom gem is not working properly, return error
    { error: 'Intercom functionality temporarily disabled - gem installation issue' }
  end

  def get_old_conversations
    # Get conversations older than 3 months
    get_conversations(90)
  end
end

# Confluence Service for wiki content analysis
class ConfluenceService
  def initialize
    @site = ENV['JIRA_SITE'] # Using same site as JIRA
    @username = ENV['JIRA_USERNAME']
    @api_token = ENV['JIRA_API_TOKEN']
    
    unless @site && @username && @api_token
      puts "Warning: Confluence credentials not configured. Set JIRA_SITE, JIRA_USERNAME, and JIRA_API_TOKEN in config.env"
    end
  end

  def connected?
    @site && @username && @api_token
  end

  def make_request(endpoint, method = :get, data = nil)
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI.parse("#{@site}/wiki/rest/api/#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    request = case method
              when :get
                Net::HTTP::Get.new(uri.request_uri)
              when :post
                Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
              when :put
                Net::HTTP::Put.new(uri.request_uri, 'Content-Type' => 'application/json')
              else
                raise "Unsupported HTTP method: #{method}"
              end

    request.basic_auth(@username, @api_token)
    request.body = data.to_json if data

    response = http.request(request)
    
    # Debug logging
    puts "HTTP Status: #{response.code}"
    puts "Response body length: #{response.body.length}"
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      { error: "Confluence API HTTP #{response.code}: #{response.body}" }
    end
  rescue => e
    { error: "Confluence API request error: #{e.message}" }
  end

  def get_spaces
    return { error: 'Confluence not configured' } unless connected?
    begin
      response = make_request('space')
      return response if response.is_a?(Hash) && response[:error]

      response['results'].map do |space|
        {
          key: space['key'],
          name: space['name'],
          type: space['type'],
          id: space['id']
        }
      end
    rescue => e
      { error: "Confluence API error: #{e.message}" }
    end
  end

  def get_content_by_space(space_key, limit = 100)
    return { error: 'Confluence not configured' } unless connected?
    begin
      response = make_request("content?spaceKey=#{space_key}&limit=#{limit}&expand=body.storage,version")
      
      # Debug logging
      puts "Confluence API response for space #{space_key}: #{response.class}"
      puts "Response keys: #{response.keys if response.is_a?(Hash)}"
      
      return { error: "Confluence API error: #{response}" } if response.is_a?(Hash) && response[:error]
      return { error: "Confluence API returned nil for space #{space_key}" } if response.nil?
      return { error: "Confluence API returned unexpected format for space #{space_key}" } unless response.is_a?(Hash) && response['results']

      response['results'].map do |content|
        begin
          {
            id: content['id'],
            title: content['title'],
            type: content['type'],
            status: content['status'],
            space_key: content['space']&.dig('key'),
            space_name: content['space']&.dig('name'),
            body: content['body']&.dig('storage', 'value') || '',
            version: content['version']&.dig('number'),
            created: content['created'],
            updated: content['updated'],
            author: content['by']&.dig('displayName'),
            url: content['_links']&.dig('webui') ? "#{@site}/wiki#{content['_links']['webui']}" : nil
          }
        rescue => e
          puts "Error processing content item: #{e.message}"
          nil
        end
      end.compact
    rescue => e
      { error: "Confluence API error: #{e.message}" }
    end
  end

  def search_content(query, limit = 100)
    return { error: 'Confluence not configured' } unless connected?
    begin
      encoded_query = URI.encode_www_form_component(query)
      response = make_request("content/search?cql=text~\"#{encoded_query}\"&limit=#{limit}&expand=body.storage,version")
      return response if response.is_a?(Hash) && response[:error]

      response['results'].map do |content|
        begin
          {
            id: content['id'],
            title: content['title'],
            type: content['type'],
            status: content['status'],
            space_key: content['space']&.dig('key'),
            space_name: content['space']&.dig('name'),
            body: content['body']&.dig('storage', 'value') || '',
            version: content['version']&.dig('number'),
            created: content['created'],
            updated: content['updated'],
            author: content['by']&.dig('displayName'),
            url: content['_links']&.dig('webui') ? "#{@site}/wiki#{content['_links']['webui']}" : nil
          }
        rescue => e
          puts "Error processing content item: #{e.message}"
          nil
        end
      end.compact
    rescue => e
      { error: "Confluence API error: #{e.message}" }
    end
  end

  def get_all_content(limit = 1000)
    return { error: 'Confluence not configured' } unless connected?
    begin
      all_content = []
      response = make_request("content?limit=#{limit}&expand=body.storage,version")
      return response if response.is_a?(Hash) && response[:error]

      response['results'].each do |content|
        begin
          all_content << {
            id: content['id'],
            title: content['title'],
            type: content['type'],
            status: content['status'],
            space_key: content['space']&.dig('key'),
            space_name: content['space']&.dig('name'),
            body: content['body']&.dig('storage', 'value') || '',
            version: content['version']&.dig('number'),
            created: content['created'],
            updated: content['updated'],
            author: content['by']&.dig('displayName'),
            url: content['_links']&.dig('webui') ? "#{@site}/wiki#{content['_links']['webui']}" : nil
          }
        rescue => e
          puts "Error processing content item: #{e.message}"
        end
      end

      all_content
    rescue => e
      { error: "Confluence API error: #{e.message}" }
    end
  end
end

# Content Analysis Service for duplication and accuracy detection
class ContentAnalysisService
  def initialize
    @confluence_service = ConfluenceService.new
  end

  def analyze_content_duplication(confluence_content, jira_tickets)
    duplications = []
    
    confluence_content.each do |confluence_item|
      jira_tickets.each do |ticket|
        similarity_score = calculate_similarity(confluence_item, ticket)
        
        if similarity_score > 0.7 # High similarity threshold
          duplications << {
            confluence_item: confluence_item,
            jira_ticket: ticket,
            similarity_score: similarity_score,
            type: 'high_similarity'
          }
        elsif similarity_score > 0.5 # Medium similarity threshold
          duplications << {
            confluence_item: confluence_item,
            jira_ticket: ticket,
            similarity_score: similarity_score,
            type: 'medium_similarity'
          }
        end
      end
    end
    
    duplications
  end

  def analyze_content_accuracy(confluence_content, jira_tickets)
    accuracy_issues = []
    
    confluence_content.each do |confluence_item|
      # Check for outdated information
      if confluence_item[:updated]
        days_since_update = (Time.now - Time.parse(confluence_item[:updated])) / (24 * 60 * 60)
        if days_since_update > 365
          accuracy_issues << {
            confluence_item: confluence_item,
            issue_type: 'outdated_content',
            days_since_update: days_since_update.to_i,
            severity: 'high'
          }
        elsif days_since_update > 180
          accuracy_issues << {
            confluence_item: confluence_item,
            issue_type: 'potentially_outdated',
            days_since_update: days_since_update.to_i,
            severity: 'medium'
          }
        end
      end
      
      # Check for broken links or references
      if confluence_item[:body]&.include?('jira') || confluence_item[:body]&.include?('JIRA')
        # Look for JIRA ticket references that might be outdated
        jira_references = extract_jira_references(confluence_item[:body])
        jira_references.each do |ref|
          unless jira_tickets.any? { |ticket| ticket[:key] == ref }
            accuracy_issues << {
              confluence_item: confluence_item,
              issue_type: 'broken_jira_reference',
              broken_reference: ref,
              severity: 'medium'
            }
          end
        end
      end
    end
    
    accuracy_issues
  end

  def find_orphaned_content(confluence_content, jira_tickets)
    orphaned = []
    
    confluence_content.each do |confluence_item|
      # Check if content is related to any JIRA tickets
      related_tickets = find_related_tickets(confluence_item, jira_tickets)
      
      if related_tickets.empty?
        orphaned << {
          confluence_item: confluence_item,
          issue_type: 'orphaned_content',
          reason: 'No related JIRA tickets found'
        }
      end
    end
    
    orphaned
  end

  private

  def calculate_similarity(confluence_item, jira_ticket)
    confluence_text = "#{confluence_item[:title]} #{confluence_item[:body]}".downcase
    jira_text = "#{jira_ticket[:summary]} #{jira_ticket[:description]}".downcase
    
    # Simple keyword-based similarity
    confluence_words = confluence_text.split(/\W+/).reject(&:empty?)
    jira_words = jira_text.split(/\W+/).reject(&:empty?)
    
    common_words = confluence_words & jira_words
    total_words = (confluence_words + jira_words).uniq.length
    
    return 0.0 if total_words == 0
    common_words.length.to_f / total_words
  end

  def extract_jira_references(text)
    # Extract JIRA ticket references like PROJ-123
    text.scan(/[A-Z]+-\d+/).uniq
  end

  def find_related_tickets(confluence_item, jira_tickets)
    confluence_text = "#{confluence_item[:title]} #{confluence_item[:body]}".downcase
    
    jira_tickets.select do |ticket|
      ticket_text = "#{ticket[:summary]} #{ticket[:description]}".downcase
      
      # Check for keyword overlap
      confluence_words = confluence_text.split(/\W+/).reject(&:empty?)
      ticket_words = ticket_text.split(/\W+/).reject(&:empty?)
      
      common_words = confluence_words & ticket_words
      common_words.length > 2 # At least 3 common words
    end
  end
end

# Ticket Analysis Service
class TicketAnalysisService
  def initialize
    @jira_service = JiraService.new
    @intercom_service = IntercomService.new
  end

  def analyze_obsolete_tickets(project_key = nil)
    results = {
      jira_obsolete: [],
      jira_duplicates: [],
      jira_hygiene_issues: [],
      jira_priority_issues: [],
      jira_customer_impact: [],
      jira_resource_allocation: [],
      intercom_old: [],
      summary: {},
      projects: []
    }

    # Get available projects
    if @jira_service.connected?
      projects = @jira_service.get_projects
      results[:projects] = projects unless projects.is_a?(Hash) && projects[:error]
    end

    # Analyze JIRA tickets
    if @jira_service.connected?
      obsolete_issues = @jira_service.get_obsolete_issues(project_key)
      duplicate_candidates = @jira_service.get_duplicate_candidates(project_key)
      hygiene_issues = analyze_hygiene_issues(project_key)
      priority_issues = analyze_priority_issues(project_key)
      customer_impact_issues = analyze_customer_impact_issues(project_key)
      resource_allocation_issues = analyze_resource_allocation(project_key)
      
      results[:jira_obsolete] = obsolete_issues unless obsolete_issues.is_a?(Hash) && obsolete_issues[:error]
      results[:jira_duplicates] = duplicate_candidates unless duplicate_candidates.is_a?(Hash) && duplicate_candidates[:error]
      results[:jira_hygiene_issues] = hygiene_issues
      results[:jira_priority_issues] = priority_issues
      results[:jira_customer_impact] = customer_impact_issues
      results[:jira_resource_allocation] = resource_allocation_issues
    end

    # Analyze Intercom conversations
    if @intercom_service.connected?
      old_conversations = @intercom_service.get_old_conversations
      results[:intercom_old] = old_conversations unless old_conversations.is_a?(Hash) && old_conversations[:error]
    end

    # Generate summary
    results[:summary] = {
      jira_obsolete_count: results[:jira_obsolete].length,
      jira_duplicate_groups: results[:jira_duplicates].length,
      jira_hygiene_count: results[:jira_hygiene_issues].length,
      jira_priority_count: results[:jira_priority_issues].length,
      jira_customer_impact_count: results[:jira_customer_impact].length,
      jira_resource_allocation_count: results[:jira_resource_allocation].length,
      intercom_old_count: results[:intercom_old].length,
      total_issues: results[:jira_obsolete].length + results[:jira_duplicates].flatten.length + 
                   results[:jira_hygiene_issues].length + results[:jira_priority_issues].length + 
                   results[:jira_customer_impact].length + results[:jira_resource_allocation].length + 
                   results[:intercom_old].length,
      selected_project: project_key
    }

    results
  end

  def analyze_hygiene_issues(project_key = nil)
    # Analyze tickets based on JIRA hygiene rules
    issues = @jira_service.get_issues("", 500, project_key)
    return [] if issues.is_a?(Hash) && issues[:error]
    
    hygiene_issues = []
    issues.each do |issue|
      problems = []
      
      # Check for proper type (Epic, Improvement, Feature, Story, Bug)
      valid_types = ['Epic', 'Improvement', 'Feature', 'Story', 'Bug', 'Sub-task']
      unless valid_types.include?(issue[:issue_type])
        problems << "Invalid issue type: #{issue[:issue_type]}"
      end
      
      # Check for proper priority
      unless issue[:priority] && !issue[:priority].empty?
        problems << "Missing priority"
      end
      
      # Check for customer reference
      unless issue[:description]&.include?('customer') || 
             issue[:summary]&.downcase&.include?('customer') ||
             issue[:labels]&.any? { |label| label.downcase.include?('customer') }
        problems << "No customer reference found"
      end
      
      # Check for review status
      unless issue[:status] && ['Review Completed', 'Reviewed but not Scheduled', 'Not Reviewed'].include?(issue[:status])
        problems << "Missing or invalid review status"
      end
      
      if problems.any?
        hygiene_issues << {
          key: issue[:key],
          summary: issue[:summary],
          problems: problems,
          priority: issue[:priority],
          issue_type: issue[:issue_type],
          status: issue[:status],
          created: issue[:created],
          updated: issue[:updated],
          project: issue[:project]
        }
      end
    end
    
    hygiene_issues
  end

  def analyze_priority_issues(project_key = nil)
    # Analyze tickets based on founder priority rules
    issues = @jira_service.get_issues("", 500, project_key)
    return [] if issues.is_a?(Hash) && issues[:error]
    
    priority_issues = []
    issues.each do |issue|
      priority_score = 0
      reasons = []
      
      # Founder rule: Bugs should take priority over feature requests
      if issue[:issue_type] == 'Bug'
        priority_score += 10
        reasons << "Bug takes priority over feature requests"
      elsif ['Feature', 'Improvement'].include?(issue[:issue_type])
        priority_score -= 5
        reasons << "Feature request has lower priority than bugs"
      end
      
      # Founder rule: Old tickets (365+ days) should likely be closed
      if issue[:updated]
        days_since_update = (Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)
        if days_since_update > 365
          priority_score += 8
          reasons << "Ticket hasn't been updated in #{days_since_update.to_i} days - consider closing"
        end
      end
      
      # Founder rule: Insperity tickets with customer impact priority
      if issue[:project] == 'INSPERITY' && 
         (issue[:summary]&.downcase&.include?('customer') || 
          issue[:description]&.downcase&.include?('customer'))
        priority_score += 7
        reasons << "Insperity ticket with potential customer impact"
      end
      
      # Founder rule: Multiple customer reports
      if issue[:description] && issue[:description].scan(/customer|client/i).length > 2
        priority_score += 6
        reasons << "Multiple customer references found"
      end
      
      # Founder rule: Resource allocation (80% new features, 20% tech debt/ops)
      if issue[:issue_type] == 'Feature' || issue[:issue_type] == 'New Feature'
        priority_score += 3
        reasons << "New feature development (80% resource allocation target)"
      elsif ['Technical Debt', 'Task', 'Sub-task'].include?(issue[:issue_type]) ||
            issue[:summary]&.downcase&.include?('technical debt') ||
            issue[:summary]&.downcase&.include?('refactor') ||
            issue[:summary]&.downcase&.include?('cleanup')
        priority_score -= 2
        reasons << "Technical debt/operational task (20% resource allocation target)"
      end
      
      if priority_score > 0
        priority_issues << {
          key: issue[:key],
          summary: issue[:summary],
          priority_score: priority_score,
          reasons: reasons,
          issue_type: issue[:issue_type],
          status: issue[:status],
          created: issue[:created],
          updated: issue[:updated],
          project: issue[:project]
        }
      end
    end
    
    # Sort by priority score (highest first)
    priority_issues.sort_by { |issue| -issue[:priority_score] }
  end

  def analyze_customer_impact_issues(project_key = nil)
    # Analyze tickets for customer impact based on business rules
    issues = @jira_service.get_issues("", 500, project_key)
    return [] if issues.is_a?(Hash) && issues[:error]
    
    customer_impact_issues = []
    issues.each do |issue|
      impact_score = 0
      reasons = []
      
      # Check for customer-specific language
      customer_keywords = ['customer', 'client', 'user', 'end user', 'customer success']
      customer_keywords.each do |keyword|
        if issue[:summary]&.downcase&.include?(keyword) || 
           issue[:description]&.downcase&.include?(keyword)
          impact_score += 3
          reasons << "Contains customer-related keywords"
          break
        end
      end
      
      # Check for revenue impact
      revenue_keywords = ['revenue', 'billing', 'payment', 'subscription', 'renewal']
      revenue_keywords.each do |keyword|
        if issue[:summary]&.downcase&.include?(keyword) || 
           issue[:description]&.downcase&.include?(keyword)
          impact_score += 5
          reasons << "Potential revenue impact"
          break
        end
      end
      
      # Check for security or compliance impact
      security_keywords = ['security', 'compliance', 'gdpr', 'privacy', 'data protection']
      security_keywords.each do |keyword|
        if issue[:summary]&.downcase&.include?(keyword) || 
           issue[:description]&.downcase&.include?(keyword)
          impact_score += 7
          reasons << "Security/compliance impact"
          break
        end
      end
      
      if impact_score > 0
        customer_impact_issues << {
          key: issue[:key],
          summary: issue[:summary],
          impact_score: impact_score,
          reasons: reasons,
          issue_type: issue[:issue_type],
          status: issue[:status],
          created: issue[:created],
          updated: issue[:updated],
          project: issue[:project]
        }
      end
    end
    
    # Sort by impact score (highest first)
    customer_impact_issues.sort_by { |issue| -issue[:impact_score] }
  end

  def analyze_resource_allocation(project_key = nil)
    # Analyze tickets based on 80/20 resource allocation rule
    issues = @jira_service.get_issues("", 500, project_key)
    return [] if issues.is_a?(Hash) && issues[:error]
    
    resource_allocation_issues = []
    new_feature_count = 0
    tech_debt_count = 0
    total_issues = 0
    
    issues.each do |issue|
      total_issues += 1
      
      # Categorize by resource allocation
      if ['Feature', 'New Feature', 'Story'].include?(issue[:issue_type]) ||
         issue[:summary]&.downcase&.include?('new feature') ||
         issue[:summary]&.downcase&.include?('enhancement')
        new_feature_count += 1
        resource_allocation_issues << {
          key: issue[:key],
          summary: issue[:summary],
          category: 'new_feature',
          reason: 'New feature development (80% target)',
          issue_type: issue[:issue_type],
          status: issue[:status],
          created: issue[:created],
          updated: issue[:updated],
          project: issue[:project]
        }
      elsif ['Technical Debt', 'Task', 'Sub-task'].include?(issue[:issue_type]) ||
            issue[:summary]&.downcase&.include?('technical debt') ||
            issue[:summary]&.downcase&.include?('refactor') ||
            issue[:summary]&.downcase&.include?('cleanup') ||
            issue[:summary]&.downcase&.include?('maintenance')
        tech_debt_count += 1
        resource_allocation_issues << {
          key: issue[:key],
          summary: issue[:summary],
          category: 'tech_debt',
          reason: 'Technical debt/operational task (20% target)',
          issue_type: issue[:issue_type],
          status: issue[:status],
          created: issue[:created],
          updated: issue[:updated],
          project: issue[:project]
        }
      end
    end
    
    # Add allocation summary
    if total_issues > 0
      new_feature_percentage = (new_feature_count.to_f / total_issues * 100).round(1)
      tech_debt_percentage = (tech_debt_count.to_f / total_issues * 100).round(1)
      
      resource_allocation_issues << {
        key: 'ALLOCATION_SUMMARY',
        summary: "Resource Allocation Analysis",
        category: 'summary',
        reason: "Current: #{new_feature_percentage}% new features, #{tech_debt_percentage}% tech debt. Target: 80% new features, 20% tech debt",
        new_feature_count: new_feature_count,
        tech_debt_count: tech_debt_count,
        total_issues: total_issues,
        new_feature_percentage: new_feature_percentage,
        tech_debt_percentage: tech_debt_percentage
      }
    end
    
    resource_allocation_issues
  end

  def get_ticket_recommendations(project_key = nil)
    analysis = analyze_obsolete_tickets(project_key)
    recommendations = []

    # JIRA obsolete recommendations
    analysis[:jira_obsolete].each do |issue|
      recommendations << {
        type: 'jira_obsolete',
        id: issue[:key],
        title: issue[:summary],
        reason: "Issue hasn't been updated in 6+ months",
        action: 'Consider closing or updating',
        priority: 'medium',
        created: issue[:created],
        updated: issue[:updated],
        project: issue[:project]
      }
    end

    # JIRA duplicate recommendations
    analysis[:jira_duplicates].each do |group|
      group.each_with_index do |issue, index|
        recommendation = {
          type: 'jira_duplicate',
          id: issue[:key],
          title: issue[:summary],
          action: 'Review and merge if duplicate',
          priority: 'high',
          group_size: group.length,
          created: issue[:created]
        }
        
        if index > 0
          recommendation[:reason] = "Potential duplicate of #{group[0][:key]}"
        end
        
        recommendations << recommendation
      end
    end

    # JIRA hygiene recommendations
    analysis[:jira_hygiene_issues].each do |issue|
      recommendations << {
        type: 'jira_hygiene',
        id: issue[:key],
        title: issue[:summary],
        reason: "Hygiene issues: #{issue[:problems].join(', ')}",
        action: 'Fix JIRA hygiene issues',
        priority: 'medium',
        created: issue[:created],
        updated: issue[:updated],
        project: issue[:project],
        problems: issue[:problems]
      }
    end

    # JIRA priority recommendations
    analysis[:jira_priority_issues].each do |issue|
      priority_level = issue[:priority_score] >= 8 ? 'high' : 
                     issue[:priority_score] >= 5 ? 'medium' : 'low'
      
      recommendations << {
        type: 'jira_priority',
        id: issue[:key],
        title: issue[:summary],
        reason: "Priority score: #{issue[:priority_score]} - #{issue[:reasons].join(', ')}",
        action: 'Review priority based on business rules',
        priority: priority_level,
        created: issue[:created],
        updated: issue[:updated],
        project: issue[:project],
        priority_score: issue[:priority_score],
        reasons: issue[:reasons]
      }
    end

    # JIRA customer impact recommendations
    analysis[:jira_customer_impact].each do |issue|
      impact_level = issue[:impact_score] >= 7 ? 'high' : 
                    issue[:impact_score] >= 5 ? 'medium' : 'low'
      
      recommendations << {
        type: 'jira_customer_impact',
        id: issue[:key],
        title: issue[:summary],
        reason: "Customer impact score: #{issue[:impact_score]} - #{issue[:reasons].join(', ')}",
        action: 'Review customer impact',
        priority: impact_level,
        created: issue[:created],
        updated: issue[:updated],
        project: issue[:project],
        impact_score: issue[:impact_score],
        reasons: issue[:reasons]
      }
    end

    # JIRA resource allocation recommendations
    analysis[:jira_resource_allocation].each do |issue|
      if issue[:key] == 'ALLOCATION_SUMMARY'
        # Special handling for allocation summary
        recommendations << {
          type: 'jira_resource_allocation_summary',
          id: 'ALLOCATION_SUMMARY',
          title: 'Resource Allocation Analysis',
          reason: issue[:reason],
          action: 'Review resource allocation balance',
          priority: 'medium',
          new_feature_count: issue[:new_feature_count],
          tech_debt_count: issue[:tech_debt_count],
          total_issues: issue[:total_issues],
          new_feature_percentage: issue[:new_feature_percentage],
          tech_debt_percentage: issue[:tech_debt_percentage]
        }
      else
        # Individual issue recommendations
        priority_level = issue[:category] == 'new_feature' ? 'high' : 'medium'
        
        recommendations << {
          type: 'jira_resource_allocation',
          id: issue[:key],
          title: issue[:summary],
          reason: issue[:reason],
          action: 'Review resource allocation',
          priority: priority_level,
          created: issue[:created],
          updated: issue[:updated],
          project: issue[:project],
          category: issue[:category]
        }
      end
    end

    # Intercom old conversations
    analysis[:intercom_old].each do |conversation|
      recommendations << {
        type: 'intercom_old',
        id: conversation[:id],
        title: conversation[:subject] || 'No subject',
        reason: "Conversation is over 3 months old",
        action: 'Consider archiving',
        priority: 'low',
        created: conversation[:created_at]
      }
    end

    recommendations.sort_by { |r| r[:priority] == 'high' ? 0 : r[:priority] == 'medium' ? 1 : 2 }
  end
end

# Ticket Cache Service for comprehensive cross-project analysis
class TicketCacheService
  def initialize
    @cache_dir = 'cache'
    @tickets_file = File.join(@cache_dir, 'tickets.json')
    @projects_file = File.join(@cache_dir, 'projects.json')
    @confluence_file = File.join(@cache_dir, 'confluence.json')
    @content_analysis_file = File.join(@cache_dir, 'content_analysis.json')
    @last_sync_file = File.join(@cache_dir, 'last_sync.json')
    
    # Create cache directory if it doesn't exist
    FileUtils.mkdir_p(@cache_dir) unless Dir.exist?(@cache_dir)
  end

  def sync_all_tickets(jira_service)
    puts "Starting comprehensive ticket sync..."
    
    # Get all projects
    projects = jira_service.get_projects
    return { error: 'Failed to fetch projects' } if projects.is_a?(Hash) && projects[:error]
    
    all_tickets = []
    sync_stats = {
      total_projects: projects.length,
      projects_processed: 0,
      total_tickets: 0,
      errors: []
    }
    
    projects.each do |project|
      begin
        puts "Syncing tickets for project: #{project[:key]} (#{project[:name]})"
        
        # Get tickets for this project
        tickets = jira_service.get_issues(nil, 1000, project[:key])
        
        if tickets.is_a?(Hash) && tickets[:error]
          sync_stats[:errors] << "Project #{project[:key]}: #{tickets[:error]}"
          next
        end
        
        # Add project info to each ticket
        tickets.each do |ticket|
          ticket[:project_key] = project[:key]
          ticket[:project_name] = project[:name]
          ticket[:synced_at] = Time.now.iso8601
        end
        
        all_tickets.concat(tickets)
        sync_stats[:projects_processed] += 1
        sync_stats[:total_tickets] += tickets.length
        
        puts "  - Found #{tickets.length} tickets"
        
      rescue => e
        sync_stats[:errors] << "Project #{project[:key]}: #{e.message}"
        puts "  - Error: #{e.message}"
      end
    end
    
    # Save to cache
    save_tickets(all_tickets)
    save_projects(projects)
    save_sync_stats(sync_stats)
    
    puts "Sync completed: #{sync_stats[:total_tickets]} tickets across #{sync_stats[:projects_processed]} projects"
    sync_stats
  end

  def sync_confluence_content
    puts "Starting Confluence content sync..."
    
    confluence_service = ConfluenceService.new
    return { error: 'Confluence not configured' } unless confluence_service.connected?
    
    sync_stats = {
      spaces_processed: 0,
      total_content: 0,
      errors: []
    }
    
    begin
      # Get all spaces
      spaces = confluence_service.get_spaces
      return { error: 'Failed to fetch Confluence spaces' } if spaces.is_a?(Hash) && spaces[:error]
      
      all_content = []
      
      spaces.each do |space|
        begin
          puts "Syncing content for space: #{space[:key]} (#{space[:name]})"
          
          # Get content for this space
          content = confluence_service.get_content_by_space(space[:key], 500)
          
          if content.is_a?(Hash) && content[:error]
            sync_stats[:errors] << "Space #{space[:key]}: #{content[:error]}"
            next
          end
          
          all_content.concat(content)
          sync_stats[:spaces_processed] += 1
          sync_stats[:total_content] += content.length
          
          puts "  - Found #{content.length} content items"
          
        rescue => e
          sync_stats[:errors] << "Space #{space[:key]}: #{e.message}"
          puts "  - Error: #{e.message}"
        end
      end
      
      # Save to cache
      save_confluence_content(all_content)
      save_sync_stats(sync_stats)
      
      puts "Confluence sync completed: #{sync_stats[:total_content]} content items across #{sync_stats[:spaces_processed]} spaces"
      sync_stats
      
    rescue => e
      { error: "Confluence sync error: #{e.message}" }
    end
  end

  def analyze_content_duplication_and_accuracy
    puts "Starting content analysis..."
    
    confluence_content = get_confluence_content
    jira_tickets = get_all_tickets
    
    return { error: 'No content available for analysis' } if confluence_content.empty? || jira_tickets.empty?
    
    content_analysis_service = ContentAnalysisService.new
    
    analysis_results = {
      duplications: content_analysis_service.analyze_content_duplication(confluence_content, jira_tickets),
      accuracy_issues: content_analysis_service.analyze_content_accuracy(confluence_content, jira_tickets),
      orphaned_content: content_analysis_service.find_orphaned_content(confluence_content, jira_tickets),
      summary: {
        total_confluence_items: confluence_content.length,
        total_jira_tickets: jira_tickets.length,
        duplications_found: 0,
        accuracy_issues_found: 0,
        orphaned_content_found: 0
      }
    }
    
    # Update summary counts
    analysis_results[:summary][:duplications_found] = analysis_results[:duplications].length
    analysis_results[:summary][:accuracy_issues_found] = analysis_results[:accuracy_issues].length
    analysis_results[:summary][:orphaned_content_found] = analysis_results[:orphaned_content].length
    
    # Save analysis results
    save_content_analysis(analysis_results)
    
    puts "Content analysis completed:"
    puts "  - Duplications: #{analysis_results[:summary][:duplications_found]}"
    puts "  - Accuracy issues: #{analysis_results[:summary][:accuracy_issues_found]}"
    puts "  - Orphaned content: #{analysis_results[:summary][:orphaned_content_found]}"
    
    analysis_results
  end

  def get_all_tickets
    return [] unless File.exist?(@tickets_file)
    
    begin
      JSON.parse(File.read(@tickets_file))
    rescue => e
      puts "Error reading ticket cache: #{e.message}"
      []
    end
  end

  def get_tickets_by_project(project_key)
    tickets = get_all_tickets
    tickets.select { |t| t['project_key'] == project_key }
  end

  def get_tickets_by_filter(filter_type, value = nil)
    tickets = get_all_tickets
    
    case filter_type
    when 'status'
      tickets.select { |t| t['status'] == value }
    when 'priority'
      tickets.select { |t| t['priority'] == value }
    when 'issue_type'
      tickets.select { |t| t['issue_type'] == value }
    when 'assignee'
      tickets.select { |t| t['assignee'] == value }
    when 'reporter'
      tickets.select { |t| t['reporter'] == value }
    when 'recent'
      # Tickets updated in last 30 days
      cutoff = 30.days.ago
      tickets.select { |t| Time.parse(t['updated']) > cutoff }
    when 'old'
      # Tickets not updated in last 6 months
      cutoff = 6.months.ago
      tickets.select { |t| Time.parse(t['updated']) < cutoff }
    when 'unassigned'
      tickets.select { |t| t['assignee'].nil? || t['assignee'].empty? }
    when 'high_priority'
      tickets.select { |t| ['Critical', 'High', 'Major'].include?(t['priority']) }
    else
      tickets
    end
  end

  def get_sync_stats
    return {} unless File.exist?(@last_sync_file)
    
    begin
      JSON.parse(File.read(@last_sync_file))
    rescue => e
      puts "Error reading sync stats: #{e.message}"
      {}
    end
  end

  def get_projects
    return [] unless File.exist?(@projects_file)
    
    begin
      JSON.parse(File.read(@projects_file))
    rescue => e
      puts "Error reading projects cache: #{e.message}"
      []
    end
  end

  def get_confluence_content
    return [] unless File.exist?(@confluence_file)
    
    begin
      JSON.parse(File.read(@confluence_file))
    rescue => e
      puts "Error reading Confluence cache: #{e.message}"
      []
    end
  end

  def get_content_analysis
    return {} unless File.exist?(@content_analysis_file)
    
    begin
      JSON.parse(File.read(@content_analysis_file))
    rescue => e
      puts "Error reading content analysis cache: #{e.message}"
      {}
    end
  end

  def search_tickets(query)
    tickets = get_all_tickets
    query = query.downcase
    
    tickets.select do |ticket|
      ticket['summary']&.downcase&.include?(query) ||
      ticket['description']&.downcase&.include?(query) ||
      ticket['key']&.downcase&.include?(query) ||
      ticket['project_name']&.downcase&.include?(query) ||
      ticket['assignee']&.downcase&.include?(query) ||
      ticket['reporter']&.downcase&.include?(query)
    end
  end

  def get_ticket_statistics
    tickets = get_all_tickets
    return {} if tickets.empty?
    
    {
      total_tickets: tickets.length,
      by_project: tickets.group_by { |t| t['project_key'] }.transform_values(&:length),
      by_status: tickets.group_by { |t| t['status'] }.transform_values(&:length),
      by_priority: tickets.group_by { |t| t['priority'] }.transform_values(&:length),
      by_type: tickets.group_by { |t| t['issue_type'] }.transform_values(&:length),
      by_assignee: tickets.group_by { |t| t['assignee'] }.transform_values(&:length),
      unassigned: tickets.count { |t| t['assignee'].nil? || t['assignee'].empty? },
      recent: tickets.count { |t| Time.parse(t['updated']) > 30.days.ago },
      old: tickets.count { |t| Time.parse(t['updated']) < 6.months.ago }
    }
  end

  private

  def save_tickets(tickets)
    File.write(@tickets_file, JSON.pretty_generate(tickets))
  end

  def save_projects(projects)
    File.write(@projects_file, JSON.pretty_generate(projects))
  end

  def save_sync_stats(stats)
    stats[:last_sync] = Time.now.iso8601
    File.write(@last_sync_file, JSON.pretty_generate(stats))
  end

  def save_confluence_content(content)
    File.write(@confluence_file, JSON.pretty_generate(content))
  end

  def save_content_analysis(analysis)
    File.write(@content_analysis_file, JSON.pretty_generate(analysis))
  end
end

# Main Application
class AdminUI < Sinatra::Base
  set :port, ENV['PORT'] || 3000
  set :environment, ENV['ENVIRONMENT'] || 'development'
  
  configure do
    enable :sessions
    set :session_secret, 'your-secret-key'
  end

  before do
    begin
      @ticket_analysis = TicketAnalysisService.new
      @ticket_cache = TicketCacheService.new
    rescue => e
      puts "Warning: Could not initialize services: #{e.message}"
      @ticket_analysis = nil
      @ticket_cache = nil
    end
  end

  get '/' do
    erb :index
  end

  get '/tickets' do
    if @ticket_analysis.nil?
      return "Ticket analysis service not available. Please check configuration."
    end
    project_key = params['project']
    @recommendations = @ticket_analysis.get_ticket_recommendations(project_key)
    @analysis = @ticket_analysis.analyze_obsolete_tickets(project_key)
    erb :tickets
  end

  get '/comprehensive-tickets' do
    erb :comprehensive_tickets
  end

  get '/content-analysis' do
    erb :content_analysis
  end

  get '/api/tickets/analysis' do
    content_type :json
    if @ticket_analysis.nil?
      return { error: "Ticket analysis service not available" }.to_json
    end
    project_key = params['project']
    @ticket_analysis.analyze_obsolete_tickets(project_key).to_json
  end

  get '/api/tickets/recommendations' do
    content_type :json
    project_key = params['project']
    @ticket_analysis.get_ticket_recommendations(project_key).to_json
  end

  get '/api/projects' do
    content_type :json
    jira_service = JiraService.new
    jira_service.get_projects.to_json
  end

  # Comprehensive Ticket Management Routes
  get '/api/tickets/sync' do
    content_type :json
    jira_service = JiraService.new
    sync_stats = @ticket_cache.sync_all_tickets(jira_service)
    sync_stats.to_json
  end

  get '/api/tickets/all' do
    content_type :json
    tickets = @ticket_cache.get_all_tickets
    {
      tickets: tickets,
      count: tickets.length,
      last_sync: @ticket_cache.get_sync_stats['last_sync']
    }.to_json
  end

  get '/api/tickets/search' do
    content_type :json
    query = params[:q]
    tickets = @ticket_cache.search_tickets(query)
    {
      tickets: tickets,
      count: tickets.length,
      query: query
    }.to_json
  end

  get '/api/tickets/filter/:filter_type' do
    content_type :json
    filter_type = params[:filter_type]
    value = params[:value]
    tickets = @ticket_cache.get_tickets_by_filter(filter_type, value)
    {
      tickets: tickets,
      count: tickets.length,
      filter_type: filter_type,
      filter_value: value
    }.to_json
  end

  get '/api/tickets/statistics' do
    content_type :json
    stats = @ticket_cache.get_ticket_statistics
    stats.to_json
  end

  get '/api/tickets/project/:project_key' do
    content_type :json
    project_key = params[:project_key]
    tickets = @ticket_cache.get_tickets_by_project(project_key)
    {
      tickets: tickets,
      count: tickets.length,
      project_key: project_key
    }.to_json
  end

  get '/api/tickets/sync-status' do
    content_type :json
    sync_stats = @ticket_cache.get_sync_stats
    sync_stats.to_json
  end

  # Confluence Integration Routes
  get '/api/confluence/sync' do
    content_type :json
    sync_stats = @ticket_cache.sync_confluence_content
    sync_stats.to_json
  end

  get '/api/confluence/content' do
    content_type :json
    content = @ticket_cache.get_confluence_content
    {
      content: content,
      count: content.length,
      last_sync: @ticket_cache.get_sync_stats['last_sync']
    }.to_json
  end

  get '/api/confluence/search' do
    content_type :json
    query = params[:q]
    confluence_service = ConfluenceService.new
    content = confluence_service.search_content(query)
    {
      content: content,
      count: content.length,
      query: query
    }.to_json
  end

  get '/api/confluence/spaces' do
    content_type :json
    confluence_service = ConfluenceService.new
    spaces = confluence_service.get_spaces
    spaces.to_json
  end

  get '/api/confluence/space/:space_key' do
    content_type :json
    space_key = params[:space_key]
    confluence_service = ConfluenceService.new
    content = confluence_service.get_content_by_space(space_key)
    {
      content: content,
      count: content.length,
      space_key: space_key
    }.to_json
  end

  # Content Analysis Routes
  get '/api/content/analyze' do
    content_type :json
    analysis_results = @ticket_cache.analyze_content_duplication_and_accuracy
    analysis_results.to_json
  end

  get '/api/content/analysis' do
    content_type :json
    analysis = @ticket_cache.get_content_analysis
    analysis.to_json
  end

  get '/api/content/duplications' do
    content_type :json
    analysis = @ticket_cache.get_content_analysis
    {
      duplications: analysis['duplications'] || [],
      count: (analysis['duplications'] || []).length
    }.to_json
  end

  get '/api/content/accuracy-issues' do
    content_type :json
    analysis = @ticket_cache.get_content_analysis
    {
      accuracy_issues: analysis['accuracy_issues'] || [],
      count: (analysis['accuracy_issues'] || []).length
    }.to_json
  end

  get '/api/content/orphaned' do
    content_type :json
    analysis = @ticket_cache.get_content_analysis
    {
      orphaned_content: analysis['orphaned_content'] || [],
      count: (analysis['orphaned_content'] || []).length
    }.to_json
  end

  post '/api/tickets/close' do
    content_type :json
    
    data = JSON.parse(request.body.read)
    ticket_id = data['ticket_id']
    ticket_type = data['ticket_type']
    
    # Here you would implement the actual closing logic
    # For now, we'll just return a success response
    {
      success: true,
      message: "Ticket #{ticket_id} marked for closure",
      ticket_type: ticket_type
    }.to_json
  end

  get '/settings' do
    @jira_connected = JiraService.new.connected?
    @intercom_connected = IntercomService.new.connected?
    erb :settings
  end

  # Legacy audit management routes (keeping existing functionality)
  get '/audits' do
    @project_manager = ProjectManager.new
    @audits = @project_manager.list_audits.map { |a| @project_manager.get_audit_info(a) }
    erb :audits
  end

  get '/audit/:name' do
    @project_manager = ProjectManager.new
    @audit = @project_manager.get_audit_info(params[:name])
    erb :audit_detail
  end

  # API routes for audit management
  post '/api/audits/create' do
    content_type :json
    data = JSON.parse(request.body.read)
    project_manager = ProjectManager.new
    result = project_manager.create_audit(data['name'])
    result.to_json
  end

  post '/api/audits/delete' do
    content_type :json
    data = JSON.parse(request.body.read)
    project_manager = ProjectManager.new
    result = project_manager.delete_audit(data['name'])
    result.to_json
  end

  post '/api/audits/run' do
    content_type :json
    data = JSON.parse(request.body.read)
    project_manager = ProjectManager.new
    result = project_manager.run_audit(data['name'], data['command'])
    result.to_json
  end
end

# Legacy AuditManager class (keeping for backward compatibility)
class ProjectManager
  def initialize
    @audits_dir = File.expand_path('../../audits', __FILE__)
    @output_dir = File.expand_path('../../audits', __FILE__)
  end

  def list_audits
    return [] unless Dir.exist?(@audits_dir)
    
    Dir.entries(@audits_dir).select do |entry|
      next if entry.start_with?('.')
      File.directory?(File.join(@audits_dir, entry))
    end.sort
  end

  def get_audit_info(audit_name)
    audit_path = File.join(@audits_dir, audit_name)
    return nil unless Dir.exist?(audit_path)

    input_dir = File.join(audit_path, 'input')
    output_dir = File.join(audit_path, 'output')
    
    {
      name: audit_name,
      input_files: Dir.exist?(input_dir) ? Dir.entries(input_dir).reject { |f| f.start_with?('.') } : [],
      output_files: Dir.exist?(output_dir) ? Dir.entries(output_dir).reject { |f| f.start_with?('.') } : [],
      input_count: Dir.exist?(input_dir) ? Dir.entries(input_dir).reject { |f| f.start_with?('.') }.size : 0,
      output_count: Dir.exist?(output_dir) ? Dir.entries(output_dir).reject { |f| f.start_with?('.') }.size : 0,
      last_modified: File.mtime(audit_path).strftime('%Y-%m-%d %H:%M:%S')
    }
  end

  def create_audit(audit_name)
    audit_path = File.join(@audits_dir, audit_name)
    return { success: false, error: 'Audit already exists' } if Dir.exist?(audit_path)

    begin
      Dir.mkdir(audit_path)
      Dir.mkdir(File.join(audit_path, 'input'))
      Dir.mkdir(File.join(audit_path, 'output'))
      { success: true, message: "Audit '#{audit_name}' created successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def delete_audit(audit_name)
    audit_path = File.join(@audits_dir, audit_name)
    return { success: false, error: 'Audit does not exist' } unless Dir.exist?(audit_path)

    begin
      FileUtils.rm_rf(audit_path)
      { success: true, message: "Audit '#{audit_name}' deleted successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def run_audit(audit_name, command = nil)
    audit_path = File.join(@audits_dir, audit_name)
    return { success: false, error: 'Audit does not exist' } unless Dir.exist?(audit_path)

    # Default command if none provided
    command ||= "echo 'Audit #{audit_name} executed at #{Time.now}' > output/execution.log"

    begin
      Dir.chdir(audit_path) do
        stdout, stderr, status = Open3.capture3(command)
        
        # Save execution log
        log_file = File.join(audit_path, 'output', 'execution.log')
        File.write(log_file, "Command: #{command}\n\nSTDOUT:\n#{stdout}\n\nSTDERR:\n#{stderr}\n\nExit Code: #{status.exitstatus}")
        
        {
          success: status.success?,
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          log_file: log_file
        }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end
end

# Start the application
if __FILE__ == $0
  puts "Wizdocs Veracity Audit System started at http://localhost:#{ENV['PORT'] || 3000}"
  puts "Make sure to configure your API credentials in config.env"
  AdminUI.run!
end 