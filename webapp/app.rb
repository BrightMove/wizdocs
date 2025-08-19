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
require_relative 'github_integration'
require_relative 'github_webhook_handler'
require_relative 'knowledge_base_manager'
require_relative 'models/crm_models'

# Enable static file serving
set :public_folder, 'public'

# Load environment variables
Dotenv.load('config.env') if File.exist?('config.env')

# Wiseguy - Agentic AI Platform for BrightMove Product Management
# Main sections: Audits and Sales Tools

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
    
    # Group by similar titles and content
    duplicates = []
    processed = Set.new
    
    issues.each_with_index do |issue, i|
      next if processed.include?(i)
      
      similar = []
      title_words = issue[:summary].downcase.split(/\s+/)
      description_words = issue[:description]&.downcase&.split(/\s+/) || []
      
      issues.each_with_index do |other_issue, j|
        next if i == j || processed.include?(j)
        
        other_title_words = other_issue[:summary].downcase.split(/\s+/)
        other_description_words = other_issue[:description]&.downcase&.split(/\s+/) || []
        
        # Calculate similarity scores
        title_common = title_words & other_title_words
        description_common = description_words & other_description_words
        
        # Title similarity (more weight)
        title_similarity = title_common.length > 0 ? 
          (title_common.length.to_f / [title_words.length, other_title_words.length].max) : 0
        
        # Description similarity (less weight)
        description_similarity = description_common.length > 0 ? 
          (description_common.length.to_f / [description_words.length, other_description_words.length].max) : 0
        
        # Combined similarity score
        combined_similarity = (title_similarity * 0.7) + (description_similarity * 0.3)
        
        # If combined similarity is high enough, consider it a potential duplicate
        if combined_similarity > 0.4
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

  def make_request(endpoint, method = :get, data = nil)
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI.parse("https://api.intercom.io#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

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

    request['Authorization'] = "Bearer #{@access_token}"
    request['Accept'] = 'application/json'
    request.body = data.to_json if data

    response = http.request(request)
    
    puts "Intercom API Request: #{method.upcase} #{endpoint}"
    puts "Response Code: #{response.code}"
    puts "Response Body Length: #{response.body.length}"
    
    if response.code == '200'
      parsed_response = JSON.parse(response.body)
      puts "Response Keys: #{parsed_response.keys}" if parsed_response.is_a?(Hash)
      parsed_response
    else
      puts "Error Response: #{response.body}"
      { error: "Intercom API HTTP #{response.code}: #{response.body}" }
    end
  rescue => e
    puts "Request Error: #{e.message}"
    { error: "Intercom API request error: #{e.message}" }
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

  def get_help_center_articles
    return { error: 'Intercom not configured' } unless connected?

    begin
      # Try different possible endpoints for Help Center articles
      endpoints = ['/articles', '/help_center/articles', '/help-center/articles', '/content/articles']
      
      articles = []
      endpoints.each do |endpoint|
        begin
          response = make_request(endpoint)
          if response.is_a?(Hash) && response[:error]
            puts "Tried #{endpoint}: #{response[:error]}"
            next
          end
          
          if response['data'] && response['data'].is_a?(Array)
            articles = response['data']
            puts "Found articles using endpoint: #{endpoint}"
            break
          elsif response.is_a?(Array)
            articles = response
            puts "Found articles using endpoint: #{endpoint}"
            break
          end
        rescue => e
          puts "Error with endpoint #{endpoint}: #{e.message}"
          next
        end
      end
      
      articles.map do |article|
        {
          id: article['id'] || article['article_id'],
          title: article['title'] || article['name'],
          body: article['body'] || article['content'] || article['description'],
          url: article['url'] || article['link'],
          author_id: article['author_id'],
          state: article['state'] || article['status'],
          translated_content_url: article['translated_content_url'],
          created_at: article['created_at'],
          updated_at: article['updated_at'],
          type: 'help_center_article'
        }
      end
    rescue => e
      { error: "Intercom Help Center API error: #{e.message}" }
    end
  end

  def get_light_hub_content
    return { error: 'Intercom not configured' } unless connected?

    begin
      # Try different possible endpoints for Light Hub content
      endpoints = ['/light_hub', '/light-hub', '/content/light_hub', '/help_center/light_hub']
      
      content = []
      endpoints.each do |endpoint|
        begin
          response = make_request(endpoint)
          if response.is_a?(Hash) && response[:error]
            puts "Tried #{endpoint}: #{response[:error]}"
            next
          end
          
          if response['data'] && response['data'].is_a?(Array)
            content = response['data']
            puts "Found content using endpoint: #{endpoint}"
            break
          elsif response.is_a?(Array)
            content = response
            puts "Found content using endpoint: #{endpoint}"
            break
          end
        rescue => e
          puts "Error with endpoint #{endpoint}: #{e.message}"
          next
        end
      end
      
      content.map do |item|
        {
          id: item['id'] || item['content_id'],
          title: item['title'] || item['name'],
          body: item['body'] || item['content'] || item['description'],
          url: item['url'] || item['link'],
          type: item['type'] || 'light_hub',
          created_at: item['created_at'],
          updated_at: item['updated_at'],
          content_type: 'light_hub'
        }
      end
    rescue => e
      { error: "Intercom Light Hub API error: #{e.message}" }
    end
  end

  def get_public_content
    return { error: 'Intercom not configured' } unless connected?

    # First test if the token is valid
    test_response = make_request('/me')
    if test_response.is_a?(Hash) && test_response[:error]
      if test_response[:error].include?('unauthorized') || test_response[:error].include?('Access Token Invalid')
        return { 
          error: 'Invalid Intercom access token. Please generate a new token from your Intercom developer settings.',
          details: 'The current token is either expired, incorrect, or lacks proper permissions. Visit https://developers.intercom.com/ to generate a new access token.'
        }
      end
    end

    help_center = get_help_center_articles
    light_hub = get_light_hub_content

    all_content = []
    
    if help_center.is_a?(Array)
      all_content.concat(help_center)
    end
    
    if light_hub.is_a?(Array)
      all_content.concat(light_hub)
    end

    {
      content: all_content,
      count: all_content.length,
      help_center_count: help_center.is_a?(Array) ? help_center.length : 0,
      light_hub_count: light_hub.is_a?(Array) ? light_hub.length : 0
    }
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
      jira_quality_issues: [],
      jira_closure_candidates: [],
      jira_priority_definitions: [],
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
      quality_issues = analyze_ticket_quality_and_ideas(project_key)
      closure_candidates = analyze_tickets_for_closure(project_key)
      priority_definitions = analyze_priority_definitions(project_key)
      
      results[:jira_obsolete] = obsolete_issues unless obsolete_issues.is_a?(Hash) && obsolete_issues[:error]
      results[:jira_duplicates] = duplicate_candidates unless duplicate_candidates.is_a?(Hash) && duplicate_candidates[:error]
      results[:jira_hygiene_issues] = hygiene_issues
      results[:jira_priority_issues] = priority_issues
      results[:jira_customer_impact] = customer_impact_issues
      results[:jira_resource_allocation] = resource_allocation_issues
      results[:jira_quality_issues] = quality_issues
      results[:jira_closure_candidates] = closure_candidates
      results[:jira_priority_definitions] = priority_definitions
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
      jira_quality_count: results[:jira_quality_issues].length,
      jira_closure_count: results[:jira_closure_candidates].length,
      jira_priority_definitions_count: results[:jira_priority_definitions].length,
      intercom_old_count: results[:intercom_old].length,
      total_issues: results[:jira_obsolete].length + results[:jira_duplicates].flatten.length + 
                   results[:jira_hygiene_issues].length + results[:jira_priority_issues].length + 
                   results[:jira_customer_impact].length + results[:jira_resource_allocation].length + 
                   results[:jira_quality_issues].length + results[:jira_closure_candidates].length + 
                   results[:jira_priority_definitions].length + results[:intercom_old].length,
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
      # Skip closed tickets for hygiene analysis
      next if issue[:status]&.downcase == 'closed' || issue[:status]&.downcase == 'resolved'
      
      problems = []
      
      # Founder rule: Check for missing description, parent, priority, or customer association
      has_description = issue[:description] && !issue[:description].strip.empty?
      has_priority = issue[:priority] && !issue[:priority].empty?
      has_customer_ref = issue[:description]&.downcase&.include?('customer') || 
                        issue[:summary]&.downcase&.include?('customer') ||
                        issue[:labels]&.any? { |label| label.downcase.include?('customer') }
      
      # Check for parent ticket (we'll need to add this to the JIRA service)
      # For now, we'll assume parent is missing if it's not a sub-task
      has_parent = issue[:issue_type] == 'Sub-task'  # This is a simplification
      
      # Founder rule: If missing any of these, categorize as hygiene issue
      unless has_description && has_priority && has_customer_ref && has_parent
        if !has_description
          problems << "Missing description"
        end
        if !has_priority
          problems << "Missing priority"
        end
        if !has_customer_ref
          problems << "No customer association"
        end
        if !has_parent && issue[:issue_type] != 'Epic'
          problems << "Missing parent ticket"
        end
      end
      
      # Check for proper type (Epic, Improvement, Feature, Story, Bug)
      valid_types = ['Epic', 'Improvement', 'Feature', 'Story', 'Bug', 'Sub-task']
      unless valid_types.include?(issue[:issue_type])
        problems << "Invalid issue type: #{issue[:issue_type]}"
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
          project: issue[:project],
          has_description: has_description,
          has_priority: has_priority,
          has_customer_ref: has_customer_ref,
          has_parent: has_parent
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
      # Skip closed tickets - they don't need priority analysis
      next if issue[:status]&.downcase == 'closed' || issue[:status]&.downcase == 'resolved'
      
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
      
      # Founder rule: Poor description quality reduces priority
      if !issue[:description] || issue[:description].strip.empty?
        priority_score -= 3
        reasons << "No description - treat as idea, reduce priority"
      elsif issue[:description] && issue[:description].length < 50
        priority_score -= 2
        reasons << "Minimal description - may be just an idea"
      end
      
      # Founder rule: No recent customer activity suggests low priority
      if issue[:updated]
        days_since_update = (Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)
        if days_since_update > 365 && !issue[:description]&.downcase&.include?('customer')
          priority_score -= 4
          reasons << "No recent updates and no customer activity - consider closing"
        end
      end
      
      # Founder rule: Low priority tickets with no progress for 6+ months should become high priority
      if issue[:priority]&.downcase == 'low' && issue[:updated]
        days_since_update = (Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)
        if days_since_update > 180  # 6 months
          priority_score += 5
          reasons << "Low priority ticket with no progress for #{days_since_update.to_i} days - escalate to high priority"
        end
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
          project: issue[:project],
          description_length: issue[:description]&.length || 0,
          current_priority: issue[:priority]
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
      # Skip closed tickets - they don't need customer impact analysis
      next if issue[:status]&.downcase == 'closed' || issue[:status]&.downcase == 'resolved'
      
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
      # Skip closed tickets for resource allocation analysis
      next if issue[:status]&.downcase == 'closed' || issue[:status]&.downcase == 'resolved'
      
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

  def analyze_ticket_quality_and_ideas(project_key = nil)
    # Analyze tickets for quality issues and idea classification based on founder rules
    issues = @jira_service.get_issues("", 500, project_key)
    return [] if issues.is_a?(Hash) && issues[:error]
    
    quality_issues = []
    issues.each do |issue|
      # Skip closed tickets
      next if issue[:status]&.downcase == 'closed' || issue[:status]&.downcase == 'resolved'
      
      problems = []
      quality_score = 0
      
      # Check for missing or poor description
      if !issue[:description] || issue[:description].strip.empty?
        problems << "No description provided"
        quality_score -= 5
      elsif issue[:description] && issue[:description].length < 50
        problems << "Minimal description (may be just an idea)"
        quality_score -= 3
      end
      
      # Founder rule: Check for comments (we'll need to add this to JIRA service)
      # For now, we'll use description length as a proxy for engagement
      has_comments = issue[:description] && issue[:description].length > 100  # Simplified check
      
      # Check for customer references
      has_customer_ref = issue[:description]&.downcase&.include?('customer') || 
                        issue[:summary]&.downcase&.include?('customer') ||
                        issue[:labels]&.any? { |label| label.downcase.include?('customer') }
      
      unless has_customer_ref
        problems << "No customer reference found"
        quality_score -= 2
      end
      
      # Check for old tickets with no activity
      if issue[:updated]
        days_since_update = (Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)
        if days_since_update > 365 && !has_customer_ref
          problems << "No recent activity and no customer reference - consider closing"
          quality_score -= 4
        end
      end
      
      # Check for proper issue type
      valid_types = ['Epic', 'Improvement', 'Feature', 'Story', 'Bug', 'Sub-task']
      unless valid_types.include?(issue[:issue_type])
        problems << "Invalid issue type: #{issue[:issue_type]}"
        quality_score -= 2
      end
      
      # Check for proper priority
      unless issue[:priority] && !issue[:priority].empty?
        problems << "Missing priority"
        quality_score -= 2
      end
      
      if problems.any?
        quality_issues << {
          key: issue[:key],
          summary: issue[:summary],
          problems: problems,
          quality_score: quality_score,
          issue_type: issue[:issue_type],
          status: issue[:status],
          created: issue[:created],
          updated: issue[:updated],
          project: issue[:project],
          description_length: issue[:description]&.length || 0,
          has_customer_reference: has_customer_ref,
          days_since_update: issue[:updated] ? ((Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)).to_i : nil
        }
      end
    end
    
    # Sort by quality score (lowest first - most problematic)
    quality_issues.sort_by { |issue| issue[:quality_score] }
  end

  def analyze_tickets_for_closure(project_key = nil)
    # Analyze tickets that should be closed based on founder rules
    issues = @jira_service.get_issues("", 500, project_key)
    return [] if issues.is_a?(Hash) && issues[:error]
    
    closure_candidates = []
    issues.each do |issue|
      # Skip already closed tickets
      next if issue[:status]&.downcase == 'closed' || issue[:status]&.downcase == 'resolved'
      
      closure_reasons = []
      closure_score = 0
      
      # Founder rule: Old tickets (365+ days) with no customer activity
      if issue[:updated]
        days_since_update = (Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)
        if days_since_update > 365
          has_customer_ref = issue[:description]&.downcase&.include?('customer') || 
                           issue[:summary]&.downcase&.include?('customer')
          
          if !has_customer_ref
            closure_reasons << "No recent activity and no customer reference"
            closure_score += 8
          else
            closure_reasons << "No recent activity (#{days_since_update.to_i} days)"
            closure_score += 5
          end
        end
      end
      
      # Founder rule: Tickets with no description
      if !issue[:description] || issue[:description].strip.empty?
        closure_reasons << "No description provided"
        closure_score += 6
      end
      
      # Founder rule: Minimal description (likely just an idea)
      if issue[:description] && issue[:description].length < 30
        closure_reasons << "Minimal description - likely just an idea"
        closure_score += 4
      end
      
      # Founder rule: No description and no comments
      has_comments = issue[:description] && issue[:description].length > 100  # Simplified check
      if (!issue[:description] || issue[:description].strip.empty?) && !has_comments
        closure_reasons << "No description and no comments - treat as idea"
        closure_score += 5
      end
      
      # Founder rule: No description and no comments for 365+ days
      if issue[:updated] && (!issue[:description] || issue[:description].strip.empty?) && !has_comments
        days_since_update = (Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)
        if days_since_update > 365
          closure_reasons << "No description and no comments for #{days_since_update.to_i} days - treat as idea"
          closure_score += 7
        end
      end
      
      # Founder rule: No customer reference
      unless issue[:description]&.downcase&.include?('customer') || 
             issue[:summary]&.downcase&.include?('customer') ||
             issue[:labels]&.any? { |label| label.downcase.include?('customer') }
        closure_reasons << "No customer reference found"
        closure_score += 3
      end
      
      # Founder rule: Invalid issue type
      valid_types = ['Epic', 'Improvement', 'Feature', 'Story', 'Bug', 'Sub-task']
      unless valid_types.include?(issue[:issue_type])
        closure_reasons << "Invalid issue type: #{issue[:issue_type]}"
        closure_score += 2
      end
      
      if closure_score > 0
        closure_candidates << {
          key: issue[:key],
          summary: issue[:summary],
          closure_score: closure_score,
          closure_reasons: closure_reasons,
          issue_type: issue[:issue_type],
          status: issue[:status],
          created: issue[:created],
          updated: issue[:updated],
          project: issue[:project],
          description_length: issue[:description]&.length || 0,
          days_since_update: issue[:updated] ? ((Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)).to_i : nil
        }
      end
    end
    
    # Sort by closure score (highest first - most likely to close)
    closure_candidates.sort_by { |issue| -issue[:closure_score] }
  end

  def analyze_priority_definitions(project_key = nil)
    # Analyze tickets based on founder priority definitions
    issues = @jira_service.get_issues("", 500, project_key)
    return [] if issues.is_a?(Hash) && issues[:error]
    
    priority_issues = []
    issues.each do |issue|
      # Skip closed tickets
      next if issue[:status]&.downcase == 'closed' || issue[:status]&.downcase == 'resolved'
      
      priority_analysis = {
        key: issue[:key],
        summary: issue[:summary],
        current_priority: issue[:priority],
        issue_type: issue[:issue_type],
        status: issue[:status],
        created: issue[:created],
        updated: issue[:updated],
        project: issue[:project],
        priority_definition: nil,
        priority_recommendation: nil,
        reasons: []
      }
      
      # Founder rule: High priority = important and urgent (1-3 sprints)
      if issue[:priority]&.downcase == 'high'
        priority_analysis[:priority_definition] = "Important and urgent - needs completion within 1-3 sprints"
        priority_analysis[:priority_recommendation] = "high"
        priority_analysis[:reasons] << "High priority tickets should be completed ASAP"
      end
      
      # Founder rule: Low priority = important but not urgent (3-12 months)
      if issue[:priority]&.downcase == 'low'
        priority_analysis[:priority_definition] = "Important but not urgent - complete when resources available or within 3-12 months"
        priority_analysis[:priority_recommendation] = "low"
        priority_analysis[:reasons] << "Low priority tickets can be completed when resources are available"
        
        # Check if low priority ticket has been stagnant for 6+ months
        if issue[:updated]
          days_since_update = (Time.now - Time.parse(issue[:updated])) / (24 * 60 * 60)
          if days_since_update > 180  # 6 months
            priority_analysis[:priority_recommendation] = "high"
            priority_analysis[:reasons] << "Low priority ticket with no progress for #{days_since_update.to_i} days - should be escalated to high priority"
          end
        end
      end
      
      # Check for missing priority
      unless issue[:priority] && !issue[:priority].empty?
        priority_analysis[:priority_recommendation] = "medium"
        priority_analysis[:reasons] << "Missing priority - assign appropriate priority level"
      end
      
      priority_issues << priority_analysis
    end
    
    priority_issues
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

    # JIRA quality and idea recommendations
    analysis[:jira_quality_issues].each do |issue|
      quality_level = issue[:quality_score] <= -5 ? 'high' : 
                     issue[:quality_score] <= -3 ? 'medium' : 'low'
      
      recommendations << {
        type: 'jira_quality',
        id: issue[:key],
        title: issue[:summary],
        reason: "Quality score: #{issue[:quality_score]} - #{issue[:problems].join(', ')}",
        action: 'Review ticket quality and consider closing if just an idea',
        priority: quality_level,
        created: issue[:created],
        updated: issue[:updated],
        project: issue[:project],
        quality_score: issue[:quality_score],
        problems: issue[:problems],
        description_length: issue[:description_length],
        has_customer_reference: issue[:has_customer_reference],
        days_since_update: issue[:days_since_update]
      }
    end

    # JIRA closure recommendations
    analysis[:jira_closure_candidates].each do |issue|
      closure_level = issue[:closure_score] >= 8 ? 'high' : 
                     issue[:closure_score] >= 5 ? 'medium' : 'low'
      
      recommendations << {
        type: 'jira_closure',
        id: issue[:key],
        title: issue[:summary],
        reason: "Closure score: #{issue[:closure_score]} - #{issue[:closure_reasons].join(', ')}",
        action: 'Consider closing this ticket',
        priority: closure_level,
        created: issue[:created],
        updated: issue[:updated],
        project: issue[:project],
        closure_score: issue[:closure_score],
        closure_reasons: issue[:closure_reasons],
        description_length: issue[:description_length],
        days_since_update: issue[:days_since_update]
      }
    end

    # JIRA priority definition recommendations
    analysis[:jira_priority_definitions].each do |issue|
      recommendations << {
        type: 'jira_priority_definition',
        id: issue[:key],
        title: issue[:summary],
        reason: "Priority definition: #{issue[:priority_definition]} - #{issue[:reasons].join(', ')}",
        action: 'Review priority definition and timeline',
        priority: issue[:priority_recommendation] || 'medium',
        created: issue[:created],
        updated: issue[:updated],
        project: issue[:project],
        current_priority: issue[:current_priority],
        priority_definition: issue[:priority_definition],
        priority_recommendation: issue[:priority_recommendation],
        reasons: issue[:reasons]
      }
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
    @intercom_file = File.join(@cache_dir, 'intercom.json')
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

  def sync_intercom_content
    puts "Starting Intercom public content sync..."
    
    intercom_service = IntercomService.new
    return { error: 'Intercom not configured' } unless intercom_service.connected?
    
    begin
      public_content = intercom_service.get_public_content
      
      if public_content[:content]
        save_intercom_content(public_content[:content])
        puts "Intercom sync completed: #{public_content[:count]} content items"
        puts "  - Help Center articles: #{public_content[:help_center_count]}"
        puts "  - Light Hub content: #{public_content[:light_hub_count]}"
        
        { success: true, count: public_content[:count], help_center: public_content[:help_center_count], light_hub: public_content[:light_hub_count] }
      else
        { error: 'Failed to get Intercom public content' }
      end
    rescue => e
      { error: "Intercom sync error: #{e.message}" }
    end
  end

  def analyze_content_duplication_and_accuracy
    puts "Starting content analysis..."
    
    confluence_content = get_confluence_content
    intercom_content = get_intercom_content
    jira_tickets = get_all_tickets
    
    return { error: 'No content available for analysis' } if confluence_content.empty? && intercom_content.empty? || jira_tickets.empty?
    
    content_analysis_service = ContentAnalysisService.new
    
    # Combine all content sources
    all_content = confluence_content + intercom_content
    
    analysis_results = {
      duplications: content_analysis_service.analyze_content_duplication(all_content, jira_tickets),
      accuracy_issues: content_analysis_service.analyze_content_accuracy(all_content, jira_tickets),
      orphaned_content: content_analysis_service.find_orphaned_content(all_content, jira_tickets),
      summary: {
        total_confluence_items: confluence_content.length,
        total_intercom_items: intercom_content.length,
        total_content_items: all_content.length,
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
    puts "  - Confluence items: #{confluence_content.length}"
    puts "  - Intercom items: #{intercom_content.length}"
    
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

  def get_intercom_content
    return [] unless File.exist?(@intercom_file)
    
    begin
      JSON.parse(File.read(@intercom_file))
    rescue => e
      puts "Error reading Intercom cache: #{e.message}"
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

  def save_intercom_content(content)
    File.write(@intercom_file, JSON.pretty_generate(content))
  end
end

# Main Application
set :port, ENV['PORT'] || 3000
set :environment, ENV['ENVIRONMENT'] || 'development'

configure do
  enable :sessions
  set :session_secret, 'your-secret-key'
end

helpers do
    def number_with_delimiter(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end

  before do
    begin
      @ticket_analysis = TicketAnalysisService.new
      @ticket_cache = TicketCacheService.new
      @sales_tools_manager = SalesToolsManager.new
      puts "Initializing KnowledgeBaseManager..."
      @knowledge_base_manager = KnowledgeBaseManager.new
      puts "KnowledgeBaseManager initialized successfully"
    rescue => e
      puts "Warning: Could not initialize services: #{e.message}"
      puts "Error details: #{e.backtrace.first(5).join("\n")}"
      @ticket_analysis = nil
      @ticket_cache = nil
      @sales_tools_manager = nil
      @knowledge_base_manager = nil
    end
  end

    get '/' do
    @active_tab = 'dashboard'
    @sales_summary = @sales_tools_manager.get_sales_tools_summary

    # Get knowledge base summary
    begin
      @knowledge_summary = {
        total_sources: @knowledge_base_manager.get_content_sources.keys.length,
        total_content: 0,
        recent_searches: [],
        vector_relationships: 0,
        last_sync: Time.now.strftime("%Y-%m-%d %H:%M")
      }

      # Get content counts from each source
      sources = @knowledge_base_manager.get_content_sources
      sources.each do |source_type, config|
        content = @knowledge_base_manager.get_content_from_sources([source_type])
        @knowledge_summary[:total_content] += content[source_type]&.length || 0
      end
    rescue => e
      @knowledge_summary = {
        total_sources: 0,
        total_content: 0,
        recent_searches: [],
        vector_relationships: 0,
        last_sync: "Never",
        error: e.message
      }
    end

    erb :index_content, layout: :layout
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

  get '/github-impact' do
    erb :github_impact
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

  # Intercom Integration Routes
  get '/api/intercom/sync' do
    content_type :json
    sync_stats = @ticket_cache.sync_intercom_content
    sync_stats.to_json
  end

  get '/api/intercom/content' do
    content_type :json
    content = @ticket_cache.get_intercom_content
    {
      content: content,
      count: content.length,
      last_sync: @ticket_cache.get_sync_stats['last_sync']
    }.to_json
  end

  get '/api/intercom/help-center' do
    content_type :json
    intercom_service = IntercomService.new
    articles = intercom_service.get_help_center_articles
    {
      articles: articles,
      count: articles.is_a?(Array) ? articles.length : 0
    }.to_json
  end

  get '/api/intercom/light-hub' do
    content_type :json
    intercom_service = IntercomService.new
    content = intercom_service.get_light_hub_content
    {
      content: content,
      count: content.is_a?(Array) ? content.length : 0
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
    @active_tab = 'settings'
    @jira_connected = JiraService.new.connected?
    @intercom_connected = IntercomService.new.connected?
    
    # Check Redis connection status
    begin
      redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
      redis.ping
      @redis_connected = true
      @redis_info = {
        dbsize: redis.dbsize,
        memory: redis.info('memory'),
        keyspace: redis.info('keyspace')
      }
    rescue => e
      @redis_connected = false
      @redis_error = e.message
    end
    
    # Check GitHub connection status
    @github_connected = !ENV['GITHUB_TOKEN'].nil? && !ENV['GITHUB_TOKEN'].empty?
    

    
    erb :settings_content, layout: :layout
  end

  # Legacy audit management routes (keeping existing functionality)
  get '/audits' do
    @active_tab = 'audits'
    @project_manager = ProjectManager.new
    @audits = @project_manager.list_audits.map { |a| @project_manager.get_audit_info(a) }
    erb :audits_content, layout: :layout
  end

  get '/audit/:name' do
    @active_tab = 'audits'
    @project_manager = ProjectManager.new
    @audit = @project_manager.get_audit_info(params[:name])
    erb :audit_detail, layout: :layout
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

  # Error handling
  error 404 do
    @error_message = "Page not found"
    erb :error, layout: :layout
  end

  error 500 do
    @error_message = "Internal server error"
    erb :error, layout: :layout
  end

  # Sales Tools Routes
  get '/sales-tools' do
    @active_tab = 'sales-tools'
    @sales_tools_manager = SalesToolsManager.new
    @rfp_projects = @sales_tools_manager.list_rfp_projects.map { |p| @sales_tools_manager.get_rfp_project_info(p) }
    @sow_projects = @sales_tools_manager.list_sow_projects.map { |p| @sales_tools_manager.get_sow_project_info(p) }
    @proposal_projects = @sales_tools_manager.list_proposal_projects.map { |p| @sales_tools_manager.get_proposal_project_info(p) }
    
    erb :sales_tools_content, layout: :layout
  end

  get '/crm' do
    @active_tab = 'crm'
    @current_tab = params[:tab] || 'overview'
    @selected_type = params[:type] || 'all'
    
    # Add taxonomy information for CRM organizations
    begin
      require_relative '../content-repo/knowledge_base_manager'
      @kb_manager = KnowledgeBaseManager.new
      @taxonomy_manager = @kb_manager.taxonomy_manager
      
      # Get all organizations including organization 0
      @crm_organizations = []
      
      # Get taxonomy organizations
      if Dir.exist?(@taxonomy_manager.organizations_path)
        Dir.entries(@taxonomy_manager.organizations_path).each do |entry|
          next if entry.start_with?('.')
          org_id = entry.gsub('org_', '')
          org_info = @taxonomy_manager.get_organization(org_id)
          if org_info
            org_info['content_sources'] = @taxonomy_manager.list_content_sources(org_id)
            org_info['content_source_count'] = org_info['content_sources'].length
            
            # Get bound repositories for this organization
            org_dir = File.join(@taxonomy_manager.organizations_path, "org_#{org_id}")
            bound_repos_dir = File.join(org_dir, 'bound_repositories')
            org_info['bound_repositories'] = []
            if Dir.exist?(bound_repos_dir)
              Dir.glob(File.join(bound_repos_dir, '*.json')).each do |file|
                next if file.include?('_credentials.json')
                begin
                  repo_data = JSON.parse(File.read(file))
                  org_info['bound_repositories'] << repo_data
                rescue => e
                  # Skip corrupted files
                  next
                end
              end
            end
            org_info['bound_repo_count'] = org_info['bound_repositories'].length
            org_info['organization_type'] = 'taxonomy'
            # Set organization types for taxonomy organizations
            if org_id == '0'
              org_info['organization_types'] = ['Self']
            else
              org_info['organization_types'] = ['Customer'] # Default for other taxonomy orgs
            end
            
            @crm_organizations << org_info
          end
        end
      end
      
      # Get CRM organizations and convert them to the same format
      begin
        crm_orgs_response = Net::HTTP.get_response(URI('http://localhost:3000/api/crm/organizations'))
        if crm_orgs_response.code == '200'
          crm_orgs = JSON.parse(crm_orgs_response.body)
          crm_orgs.each do |crm_org|
            org_info = {
              'organization_id' => crm_org['id'],
              'name' => crm_org['name'],
              'description' => "#{crm_org['industry']} organization",
              'content_sources' => [],
              'content_source_count' => 0,
              'bound_repositories' => [],
              'bound_repo_count' => 0,
              'organization_type' => 'crm',
              'organization_types' => crm_org['organization_types'] || ['Customer'],
              'industry' => crm_org['industry'],
              'created_at' => crm_org['created_at'],
              'updated_at' => crm_org['updated_at']
            }
            @crm_organizations << org_info
          end
        end
      rescue => e
        # If CRM organizations can't be loaded, continue with just taxonomy organizations
        puts "Warning: Could not load CRM organizations: #{e.message}"
      end
      
      # Sort organizations: taxonomy org_0 first, then other taxonomy orgs, then CRM orgs
      @crm_organizations.sort_by! do |org| 
        if org['organization_type'] == 'taxonomy' && org['organization_id'] == '0'
          0
        elsif org['organization_type'] == 'taxonomy'
          1
        else
          2
        end
      end
      
      # Filter organizations by type if specified
      if @selected_type != 'all'
        @crm_organizations.select! { |org| org['organization_types']&.include?(@selected_type) }
      end
      
    rescue => e
      @taxonomy_error = e.message
      @crm_organizations = []
    end
    
    erb :crm_dashboard, layout: :layout
  end

  get '/sales-tools/rfp/:name' do
    @active_tab = 'sales-tools'
    @sales_tools_manager = SalesToolsManager.new
    @sales_tools = @sales_tools_manager
    @project = @sales_tools_manager.get_rfp_project_info(params[:name])
    
    if @project.nil?
      status 404
      @error_message = "RFP project '#{params[:name]}' not found"
      erb :error, layout: :layout
    else
      erb :rfp_project_detail, layout: :layout
    end
  end

  get '/sales-tools/sow/:name' do
    @active_tab = 'sales-tools'
    @sales_tools_manager = SalesToolsManager.new
    @sales_tools = @sales_tools_manager
    @project = @sales_tools_manager.get_sow_project_info(params[:name])
    
    if @project.nil?
      status 404
      @error_message = "SOW project '#{params[:name]}' not found"
      erb :error, layout: :layout
    else
      erb :sow_project_detail, layout: :layout
    end
  end

  get '/sales-tools/proposal/:name' do
    @active_tab = 'sales-tools'
    @sales_tools_manager = SalesToolsManager.new
    @sales_tools = @sales_tools_manager
    @project = @sales_tools_manager.get_proposal_project_info(params[:name])
    
    if @project.nil?
      status 404
      @error_message = "Proposal project '#{params[:name]}' not found"
      erb :error, layout: :layout
    else
      erb :proposal_project_detail, layout: :layout
    end
  end

  # Knowledge Base Management Routes
  get '/knowledge-base' do
    @active_tab = 'knowledge-base'
    erb :knowledge_base_content, layout: :layout
  end

  get '/api/knowledge-base/sources' do
    content_type :json
    @knowledge_base_manager.get_content_sources.to_json
  end

  post '/api/knowledge-base/search' do
    content_type :json
    data = JSON.parse(request.body.read)
    query = data['query']
    source_types = data['source_types'] || []
    page = data['page'] || 1
    page_size = data['page_size'] || 10
    
    begin
      # Convert source_types to symbols if they're strings
      source_types = source_types.map(&:to_sym) if source_types.any?
      
      # If no source types specified, search all sources
      if source_types.empty?
        source_types = @knowledge_base_manager.get_content_sources.keys
      end
      
      results = @knowledge_base_manager.search_knowledge_base(query, source_types, page, page_size)
      results.to_json
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  # Organization Management API endpoints
  get '/api/organizations' do
    content_type :json
    begin
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager
      
      organizations = []
      if Dir.exist?(taxonomy_manager.organizations_path)
        Dir.entries(taxonomy_manager.organizations_path).each do |entry|
          next if entry.start_with?('.')
          org_id = entry.gsub('org_', '')
          org_info = taxonomy_manager.get_organization(org_id)
          if org_info
            org_info['content_sources'] = taxonomy_manager.list_content_sources(org_id)
            org_info['content_source_count'] = org_info['content_sources'].length
            organizations << org_info
          end
        end
      end
      
      organizations.sort_by! { |org| org['organization_id'] == '0' ? 0 : 1 }
      organizations.to_json
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  post '/api/organizations/create' do
    content_type :json
    begin
      data = JSON.parse(request.body.read)
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager
      
      result = taxonomy_manager.create_organization(
        data['org_id'], 
        data['name'], 
        data['description']
      )
      
      if result
        { success: true, message: "Organization created successfully" }.to_json
      else
        { success: false, message: "Failed to create organization" }.to_json
      end
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  post '/api/organizations/:org_id/content-sources/add' do
    content_type :json
    begin
      data = JSON.parse(request.body.read)
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager
      
      result = taxonomy_manager.add_content_source(
        params[:org_id],
        data['source_name'],
        data['source_type'],
        data['visibility'],
        data['sync_strategy'],
        data['connector']
      )
      
      if result
        { success: true, message: "Content source added successfully" }.to_json
      else
        { success: false, message: "Failed to add content source" }.to_json
      end
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  put '/api/organizations/:org_id/update' do
    content_type :json
    begin
      data = JSON.parse(request.body.read)
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager
      
      # Update organization metadata
      org_dir = File.join(taxonomy_manager.organizations_path, "org_#{params[:org_id]}")
      org_file = File.join(org_dir, 'organization.json')
      
      if File.exist?(org_file)
        org_data = JSON.parse(File.read(org_file))
        org_data['name'] = data['name'] if data['name']
        org_data['description'] = data['description'] if data['description']
        org_data['updated_at'] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
        
        File.write(org_file, JSON.pretty_generate(org_data))
        { success: true, message: "Organization updated successfully" }.to_json
      else
        { success: false, message: "Organization not found" }.to_json
      end
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  get '/api/organizations/:org_id/content-sources' do
    content_type :json
    begin
      # Always use taxonomy manager; if the org directory doesn't exist (e.g., CRM org), create it on-demand
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager

      org_dir = File.join(taxonomy_manager.organizations_path, "org_#{params[:org_id]}")
      unless Dir.exist?(org_dir)
        # Try to create from CRM record if available
        crm_org = nil
        begin
          crm_manager = CRMManager.new
          crm_org = crm_manager.get_organization(params[:org_id])
        rescue => _e
          crm_org = nil
        end
        if crm_org
          taxonomy_manager.create_organization(params[:org_id], crm_org['name'] || params[:org_id], crm_org['notes'])
        else
          # Create minimal structure with fallback name
          taxonomy_manager.create_organization(params[:org_id], params[:org_id], nil)
        end
      end

      content_sources = taxonomy_manager.list_content_sources(params[:org_id]) || []
      content_sources.to_json
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  get '/api/organizations/:org_id/content-sources/:source_name' do
    content_type :json
    begin
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager
      
      source = taxonomy_manager.get_content_source(params[:org_id], params[:source_name])
      if source
        source.to_json
      else
        status 404
        { error: 'Content source not found' }.to_json
      end
    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  post '/api/organizations/:org_id/content-sources' do
    content_type :json
    begin
      data = JSON.parse(request.body.read)
      
      # Always use taxonomy manager; ensure org directory exists (works for taxonomy and CRM orgs)
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager

      org_dir = File.join(taxonomy_manager.organizations_path, "org_#{params[:org_id]}")
      unless Dir.exist?(org_dir)
        # Try to create from CRM record if available
        crm_org = nil
        begin
          crm_manager = CRMManager.new
          crm_org = crm_manager.get_organization(params[:org_id])
        rescue => _e
          crm_org = nil
        end
        if crm_org
          taxonomy_manager.create_organization(params[:org_id], crm_org['name'] || params[:org_id], crm_org['notes'])
        else
          taxonomy_manager.create_organization(params[:org_id], params[:org_id], nil)
        end
      end

      result = taxonomy_manager.add_content_source(params[:org_id], data)
      if result[:success]
        { success: true, message: 'Content source added successfully' }.to_json
      else
        status 400
        { success: false, message: result[:error] }.to_json
      end
    rescue => e
      status 500
      { success: false, error: e.message }.to_json
    end
  end

  put '/api/organizations/:org_id/content-sources/:source_name' do
    content_type :json
    begin
      data = JSON.parse(request.body.read)
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager
      
      result = taxonomy_manager.update_content_source(params[:org_id], params[:source_name], data)
      if result[:success]
        { success: true, message: 'Content source updated successfully' }.to_json
      else
        status 400
        { success: false, message: result[:error] }.to_json
      end
    rescue => e
      status 500
      { success: false, error: e.message }.to_json
    end
  end

  delete '/api/organizations/:org_id/content-sources/:source_name' do
    content_type :json
    begin
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager
      
      result = taxonomy_manager.delete_content_source(params[:org_id], params[:source_name])
      if result[:success]
        { success: true, message: 'Content source deleted successfully' }.to_json
      else
        status 400
        { success: false, message: result[:error] }.to_json
      end
    rescue => e
      status 500
      { success: false, error: e.message }.to_json
    end
  end

  # Bind Content Repository to Organization
  post '/api/organizations/:org_id/bind-repo' do
    content_type :json
    begin
      data = JSON.parse(request.body.read)
      
      # Always use taxonomy manager; ensure org directory exists (works for taxonomy and CRM orgs)
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager

      # Ensure org directory exists
      org_dir = File.join(taxonomy_manager.organizations_path, "org_#{params[:org_id]}")
      unless Dir.exist?(org_dir)
        crm_org = nil
        begin
          crm_manager = CRMManager.new
          crm_org = crm_manager.get_organization(params[:org_id])
        rescue => _e
          crm_org = nil
        end
        if crm_org
          taxonomy_manager.create_organization(params[:org_id], crm_org['name'] || params[:org_id], crm_org['notes'])
        else
          taxonomy_manager.create_organization(params[:org_id], params[:org_id], nil)
        end
      end

      # Create the bound repositories directory structure
      bound_repos_dir = File.join(org_dir, 'bound_repositories')
      FileUtils.mkdir_p(bound_repos_dir) unless Dir.exist?(bound_repos_dir)
      
      # Create repository metadata file
      repo_id = data['repo_name'].downcase.gsub(/[^a-z0-9]/, '_')
      repo_file = File.join(bound_repos_dir, "#{repo_id}.json")
      
      repo_data = {
        repo_id: repo_id,
        repo_name: data['repo_name'],
        repo_type: data['repo_type'],
        repo_url: data['repo_url'],
        repo_branch: data['repo_branch'],
        repo_access: data['repo_access'],
        repo_description: data['repo_description'],
        auto_sync: data['auto_sync'],
        sync_history: data['sync_history'],
        sync_metadata: data['sync_metadata'],
        sync_attachments: data['sync_attachments'],
        bound_at: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        last_sync: nil,
        sync_status: 'pending',
        content_count: 0
      }
      
      # Store credentials securely (in a real implementation, this would be encrypted)
      if data['repo_credentials'] && !data['repo_credentials'].empty?
        credentials_file = File.join(bound_repos_dir, "#{repo_id}_credentials.json")
        credentials_data = {
          repo_id: repo_id,
          access_method: data['repo_access'],
          credentials: data['repo_credentials'],
          stored_at: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
        }
        File.write(credentials_file, JSON.pretty_generate(credentials_data))
      end
      
      File.write(repo_file, JSON.pretty_generate(repo_data))
      
      { success: true, message: "Repository bound successfully", repo_id: repo_id }.to_json
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  # Test Repository Connection
  post '/api/repos/test-connection' do
    content_type :json
    begin
      data = JSON.parse(request.body.read)
      
      # Basic validation
      unless data['repo_url'] && !data['repo_url'].empty?
        return { success: false, message: "Repository URL is required" }.to_json
      end
      
      repo_type = data['repo_type']
      repo_url = data['repo_url']
      
      # Test connection based on repository type
      case repo_type
      when 'github'
        # Test GitHub API connection
        if repo_url.include?('github.com')
          # For now, just validate the URL format
          if repo_url.match?(/^https:\/\/github\.com\/[^\/]+\/[^\/]+/)
            { success: true, message: "GitHub repository URL format is valid" }.to_json
          else
            { success: false, message: "Invalid GitHub repository URL format" }.to_json
          end
        else
          { success: false, message: "URL does not appear to be a GitHub repository" }.to_json
        end
      when 'gitlab'
        # Test GitLab connection
        if repo_url.include?('gitlab.com')
          { success: true, message: "GitLab repository URL format is valid" }.to_json
        else
          { success: false, message: "URL does not appear to be a GitLab repository" }.to_json
        end
      when 'bitbucket'
        # Test Bitbucket connection
        if repo_url.include?('bitbucket.org')
          { success: true, message: "Bitbucket repository URL format is valid" }.to_json
        else
          { success: false, message: "URL does not appear to be a Bitbucket repository" }.to_json
        end
      when 'confluence'
        # Test Confluence connection
        if repo_url.include?('atlassian.net')
          { success: true, message: "Confluence URL format is valid" }.to_json
        else
          { success: false, message: "URL does not appear to be a Confluence instance" }.to_json
        end
      when 'local'
        # Test local directory
        if Dir.exist?(repo_url)
          { success: true, message: "Local directory exists and is accessible" }.to_json
        else
          { success: false, message: "Local directory does not exist or is not accessible" }.to_json
        end
      else
        # Generic URL validation
        if repo_url.match?(/^https?:\/\//)
          { success: true, message: "Repository URL format is valid" }.to_json
        else
          { success: false, message: "Invalid repository URL format" }.to_json
        end
      end
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  # List Bound Repositories for Organization
  get '/api/organizations/:org_id/bound-repos' do
    content_type :json
    begin
      # Always use taxonomy manager; ensure org directory exists (works for taxonomy and CRM orgs)
      require_relative '../content-repo/knowledge_base_manager'
      kb_manager = KnowledgeBaseManager.new
      taxonomy_manager = kb_manager.taxonomy_manager

      org_dir = File.join(taxonomy_manager.organizations_path, "org_#{params[:org_id]}")
      unless Dir.exist?(org_dir)
        crm_org = nil
        begin
          crm_manager = CRMManager.new
          crm_org = crm_manager.get_organization(params[:org_id])
        rescue => _e
          crm_org = nil
        end
        if crm_org
          taxonomy_manager.create_organization(params[:org_id], crm_org['name'] || params[:org_id], crm_org['notes'])
        else
          taxonomy_manager.create_organization(params[:org_id], params[:org_id], nil)
        end
      end

      bound_repos_dir = File.join(org_dir, 'bound_repositories')
      bound_repos = []
      if Dir.exist?(bound_repos_dir)
        Dir.glob(File.join(bound_repos_dir, '*.json')).each do |file|
          next if file.include?('_credentials.json')
          begin
            repo_data = JSON.parse(File.read(file))
            bound_repos << repo_data
          rescue => e
            # Skip corrupted files
            next
          end
        end
      end
      
      bound_repos.to_json
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  get '/api/knowledge-base/status' do
    content_type :json
    begin
      sources = @knowledge_base_manager.get_content_sources
      status_info = {}
      
      sources.each do |source_type, config|
        # Get stored content count
        stored_content = @knowledge_base_manager.get_stored_content(source_type)
        status_info[source_type] = {
          name: config[:name],
          enabled: config[:enabled],
          last_sync: config[:last_sync],
          content_count: stored_content.length,
          sync_interval: config[:sync_interval]
        }
      end
      
      {
        success: true,
        sources: status_info,
        timestamp: Time.now.iso8601
      }.to_json
    rescue => e
      status 500
      { error: e.message, success: false }.to_json
    end
  end

  post '/api/knowledge-base/sources/register' do
    content_type :json
    data = JSON.parse(request.body.read)
    result = @knowledge_base_manager.register_content_source(data['source_type'], data['config'])
    result.to_json
  end

  post '/api/knowledge-base/sources/unregister' do
    content_type :json
    data = JSON.parse(request.body.read)
    result = @knowledge_base_manager.unregister_content_source(data['source_type'])
    result.to_json
  end

  post '/api/knowledge-base/sources/update' do
    content_type :json
    data = JSON.parse(request.body.read)
    result = @knowledge_base_manager.update_content_source_config(data['source_type'], data['config'])
    result.to_json
  end

  # Settings API routes
  post '/api/settings/test-redis' do
    content_type :json
    data = JSON.parse(request.body.read)
    redis_url = data['redis_url'] || 'redis://localhost:6379'
    
    begin
      redis = Redis.new(url: redis_url)
      redis.ping
      result = {
        success: true,
        message: 'Redis connection successful',
        info: {
          dbsize: redis.dbsize,
          memory: redis.info('memory'),
          keyspace: redis.info('keyspace')
        }
      }
    rescue => e
      result = {
        success: false,
        message: "Redis connection failed: #{e.message}"
      }
    end
    
    result.to_json
  end

  post '/api/settings/save-redis' do
    content_type :json
    data = JSON.parse(request.body.read)
    redis_url = data['redis_url']
    
    # Update config.env with new Redis URL
    config_file = 'config.env'
    if File.exist?(config_file)
      config_content = File.read(config_file)
      
      # Replace existing REDIS_URL or add new one
      if config_content.include?('REDIS_URL=')
        config_content.gsub!(/REDIS_URL=.*/, "REDIS_URL=#{redis_url}")
      else
        config_content += "\nREDIS_URL=#{redis_url}"
      end
      
      File.write(config_file, config_content)
      result = { success: true, message: 'Redis configuration saved. Please restart the application for changes to take effect.' }
    else
      result = { success: false, message: 'Config file not found' }
    end
    
    result.to_json
  end

  post '/api/settings/test-github' do
    content_type :json
    data = JSON.parse(request.body.read)
    token = data['github_token']
    
    begin
      require 'net/http'
      require 'json'
      
      uri = URI('https://api.github.com/user')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "token #{token}"
      request['User-Agent'] = 'Wiseguy-WebApp'
      
      response = http.request(request)
      
      if response.code == '200'
        user_info = JSON.parse(response.body)
        result = {
          success: true,
          message: "GitHub connection successful. Connected as: #{user_info['login']}",
          user: user_info
        }
      else
        result = {
          success: false,
          message: "GitHub API error: #{response.code} - #{response.body}"
        }
      end
    rescue => e
      result = {
        success: false,
        message: "GitHub connection failed: #{e.message}"
      }
    end
    
    result.to_json
  end

  post '/api/settings/save-github' do
    content_type :json
    data = JSON.parse(request.body.read)
    token = data['github_token']
    
    # Update config.env with new GitHub token
    config_file = 'config.env'
    if File.exist?(config_file)
      config_content = File.read(config_file)
      
      # Replace existing GITHUB_TOKEN or add new one
      if config_content.include?('GITHUB_TOKEN=')
        config_content.gsub!(/GITHUB_TOKEN=.*/, "GITHUB_TOKEN=#{token}")
      else
        config_content += "\nGITHUB_TOKEN=#{token}"
      end
      
      File.write(config_file, config_content)
      result = { success: true, message: 'GitHub configuration saved. Please restart the application for changes to take effect.' }
    else
      result = { success: false, message: 'Config file not found' }
    end
    
    result.to_json
  end

  # Wiz Chat Agent API routes
  post '/api/wiz/chat' do
    content_type :json
    data = JSON.parse(request.body.read)
    message = data['message']
    context = data['context'] || 'general'
    
    begin
      # Initialize Wiz Chat Agent
      wiz_response = generate_wiz_response(message, context)
      result = {
        success: true,
        response: wiz_response,
        context: context,
        timestamp: Time.now.iso8601
      }
    rescue => e
      result = {
        success: false,
        error: e.message,
        response: "I'm sorry, I encountered an error while processing your request. Please try again."
      }
    end
    
    result.to_json
  end

  post '/api/wiz/analyze' do
    content_type :json
    data = JSON.parse(request.body.read)
    query = data['query']
    source_type = data['source_type'] || 'all'
    
    begin
      # Perform analysis using knowledge base
      analysis_results = @knowledge_base_manager.search_knowledge_base(query, [source_type.to_sym], 1, 10)
      
      # Generate Wiz analysis
      wiz_analysis = generate_wiz_analysis(query, analysis_results)
      
      result = {
        success: true,
        analysis: wiz_analysis,
        results: analysis_results,
        query: query,
        source_type: source_type
      }
    rescue => e
      result = {
        success: false,
        error: e.message,
        analysis: "I'm sorry, I couldn't analyze that query. Please check your request and try again."
      }
    end
    
    result.to_json
  end

  # Wiz Agent Health Check
  get '/api/wiz/health' do
    content_type :json
    
    begin
      require 'net/http'
      require 'uri'
      
      uri = URI('http://localhost:10001/health')
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      
      if response.code == '200'
        result = JSON.parse(response.body)
        {
          success: true,
          status: 'connected',
          microservice: 'wiz-agent',
          port: 10001,
          response: result
        }
      else
        {
          success: false,
          status: 'error',
          microservice: 'wiz-agent',
          port: 10001,
          error: "HTTP #{response.code}"
        }
      end
    rescue => e
      {
        success: false,
        status: 'disconnected',
        microservice: 'wiz-agent',
        port: 10001,
        error: e.message
      }
    end.to_json
  end

  post '/api/knowledge-base/sync' do
    content_type :json
    results = @knowledge_base_manager.sync_all_content_sources
    results.to_json
  end

  post '/api/knowledge-base/sync/:source_type' do
    content_type :json
    source_type = params[:source_type].to_sym
    config = @knowledge_base_manager.get_content_sources[source_type]
    result = @knowledge_base_manager.sync_content_source(source_type, config)
    result.to_json
  end

  post '/api/knowledge-base/sync-source-code' do
    content_type :json
    data = JSON.parse(request.body.read)
    repo = data['repository'] || 'brightmove/wiseguy'
    
    begin
      result = @knowledge_base_manager.get_github_source_code(repo)
      {
        success: true,
        repository: repo,
        source_code_files: result.length,
        files: result.map { |file| {
          title: file[:title],
          language: file[:language],
          file_path: file[:file_path],
          lines_of_code: file[:code_analysis][:lines_of_code],
          functions: file[:code_analysis][:functions].length,
          classes: file[:code_analysis][:classes].length
        }}
      }.to_json
    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  get '/api/knowledge-base/search' do
    content_type :json
    query = params[:q]
    source_types = params[:sources]&.split(',')&.map(&:to_sym)
    page = params[:page]&.to_i || 1
    page_size = params[:page_size]&.to_i || 10
    results = @knowledge_base_manager.search_knowledge_base(query, source_types, page, page_size)
    results.to_json
  end

  post '/api/knowledge-base/audit' do
    content_type :json
    data = JSON.parse(request.body.read)
    audit_type = data['audit_type'] || 'comprehensive'
    options = data['options'] || {}
    results = @knowledge_base_manager.perform_audit(audit_type, options)
    results.to_json
  end

  post '/api/knowledge-base/audit/schedule' do
    content_type :json
    data = JSON.parse(request.body.read)
    audit_type = data['audit_type']
    schedule_config = data['schedule_config']
    result = @knowledge_base_manager.schedule_audit(audit_type, schedule_config)
    result.to_json
  end

  get '/api/knowledge-base/audit/scheduled' do
    content_type :json
    audits = @knowledge_base_manager.get_scheduled_audits
    audits.to_json
  end

  post '/api/knowledge-base/audit/run-scheduled' do
    content_type :json
    results = @knowledge_base_manager.run_scheduled_audits
    results.to_json
  end



  # API routes for Sales Tools management
  post '/api/sales-tools/rfp/create' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.create_rfp_project(data['name'])
    result.to_json
  end

  post '/api/sales-tools/sow/create' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.create_sow_project(data['name'])
    result.to_json
  end

  post '/api/sales-tools/proposal/create' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.create_proposal_project(data['name'])
    result.to_json
  end

  post '/api/sales-tools/rfp/delete' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.delete_rfp_project(data['name'])
    result.to_json
  end

  post '/api/sales-tools/sow/delete' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.delete_sow_project(data['name'])
    result.to_json
  end

  post '/api/sales-tools/proposal/delete' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.delete_proposal_project(data['name'])
    result.to_json
  end

  post '/api/sales-tools/rfp/run-script' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.run_rfp_script(data['project_name'], data['script_name'])
    result.to_json
  end

  post '/api/sales-tools/sow/run-script' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.run_sow_script(data['project_name'], data['script_name'])
    result.to_json
  end

  post '/api/sales-tools/proposal/run-script' do
    content_type :json
    data = JSON.parse(request.body.read)
    sales_tools_manager = SalesToolsManager.new
    result = sales_tools_manager.run_proposal_script(data['project_name'], data['script_name'])
    result.to_json
  end

  # API routes for listing projects
                    get '/api/sales-tools/rfp/list' do
                    content_type :json
                    sales_tools_manager = SalesToolsManager.new
                    projects = sales_tools_manager.list_rfp_projects.map do |name| 
                      project_info = sales_tools_manager.get_rfp_project_info(name)
                      if project_info
                        project_info[:estimated_value] = sales_tools_manager.get_project_estimated_value(name, 'rfp')
                      end
                      project_info
                    end.compact
                    projects.to_json
                  end
                
                  get '/api/sales-tools/sow/list' do
                    content_type :json
                    sales_tools_manager = SalesToolsManager.new
                    projects = sales_tools_manager.list_sow_projects.map do |name| 
                      project_info = sales_tools_manager.get_sow_project_info(name)
                      if project_info
                        project_info[:estimated_value] = sales_tools_manager.get_project_estimated_value(name, 'sow')
                      end
                      project_info
                    end.compact
                    projects.to_json
                  end

                  get '/api/sales-tools/proposal/list' do
                    content_type :json
                    sales_tools_manager = SalesToolsManager.new
                    projects = sales_tools_manager.list_proposal_projects.map do |name| 
                      project_info = sales_tools_manager.get_proposal_project_info(name)
                      if project_info
                        project_info[:estimated_value] = sales_tools_manager.get_project_estimated_value(name, 'proposal')
                      end
                      project_info
                    end.compact
                    projects.to_json
                  end

  # File management endpoints
  get '/api/sales-tools/:type/file/:project/:filename' do
    content_type :text
    project_path = case params[:type]
                  when 'rfp'
                    File.join(@sales_tools_manager.instance_variable_get(:@rfp_dir), params[:project])
                  when 'sow'
                    File.join(@sales_tools_manager.instance_variable_get(:@sow_dir), params[:project])
                  when 'proposal'
                    File.join(@sales_tools_manager.instance_variable_get(:@proposal_dir), params[:project])
                  end
    
    file_path = File.join(project_path, params[:filename])
    if File.exist?(file_path)
      File.read(file_path)
    else
      status 404
      "File not found"
    end
  end

  get '/api/sales-tools/:type/files/:project/input' do
    content_type :json
    project_path = case params[:type]
                  when 'rfp'
                    File.join(@sales_tools_manager.instance_variable_get(:@rfp_dir), params[:project])
                  when 'sow'
                    File.join(@sales_tools_manager.instance_variable_get(:@sow_dir), params[:project])
                  when 'proposal'
                    File.join(@sales_tools_manager.instance_variable_get(:@proposal_dir), params[:project])
                  end
    
    input_dir = File.join(project_path, 'input')
    if Dir.exist?(input_dir)
      Dir.entries(input_dir).reject { |f| f.start_with?('.') }.to_json
    else
      [].to_json
    end
  end

  get '/api/sales-tools/:type/files/:project/custom' do
    content_type :json
    project_path = case params[:type]
                  when 'rfp'
                    File.join(@sales_tools_manager.instance_variable_get(:@rfp_dir), params[:project])
                  when 'sow'
                    File.join(@sales_tools_manager.instance_variable_get(:@sow_dir), params[:project])
                  when 'proposal'
                    File.join(@sales_tools_manager.instance_variable_get(:@proposal_dir), params[:project])
                  end
    
    # Get all files in project root except system files and directories
    if Dir.exist?(project_path)
      Dir.entries(project_path).select { |f| !f.start_with?('.') && File.file?(File.join(project_path, f)) && !['input', 'output'].include?(f) }.to_json
    else
      [].to_json
    end
  end

  post '/api/sales-tools/:type/save-file/:project' do
    content_type :json
    data = JSON.parse(request.body.read)
    filename = data['filename']
    content = data['content']
    
    project_path = case params[:type]
                  when 'rfp'
                    File.join(@sales_tools_manager.instance_variable_get(:@rfp_dir), params[:project])
                  when 'sow'
                    File.join(@sales_tools_manager.instance_variable_get(:@sow_dir), params[:project])
                  when 'proposal'
                    File.join(@sales_tools_manager.instance_variable_get(:@proposal_dir), params[:project])
                  end
    
    file_path = File.join(project_path, filename)
    
    begin
      File.write(file_path, content)
      { success: true, message: "File saved successfully" }.to_json
    rescue => e
      status 500
      { success: false, error: e.message }.to_json
    end
  end

  # CRM API Routes
  get '/api/crm/organizations' do
    content_type :json
    crm_manager = CRMManager.new
    type = params[:type]
    if type
      crm_manager.list_organizations_by_type(type).to_json
    else
      crm_manager.list_organizations.to_json
    end
  end

  get '/api/crm/organizations/:id' do
    content_type :json
    crm_manager = CRMManager.new
    organization = crm_manager.get_organization(params[:id])
    if organization
      organization.to_json
    else
      status 404
      { error: 'Organization not found' }.to_json
    end
  end

  post '/api/crm/organizations' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    organization = crm_manager.create_organization(data)
    if organization
      status 201
      organization.to_json
    else
      status 400
      { error: 'Failed to create organization' }.to_json
    end
  end

  put '/api/crm/organizations/:id' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    organization = crm_manager.update_organization(params[:id], data)
    if organization
      organization.to_json
    else
      status 404
      { error: 'Organization not found' }.to_json
    end
  end

  delete '/api/crm/organizations/:id' do
    content_type :json
    crm_manager = CRMManager.new
    crm_manager.delete_organization(params[:id])
    { success: true, message: 'Organization deleted' }.to_json
  end

  # Contact API Routes
  get '/api/crm/contacts' do
    content_type :json
    crm_manager = CRMManager.new
    organization_id = params[:organization_id]
    contacts = crm_manager.list_contacts(organization_id)
    contacts.to_json
  end

  get '/api/crm/contacts/:id' do
    content_type :json
    crm_manager = CRMManager.new
    contact = crm_manager.get_contact(params[:id])
    if contact
      contact.to_json
    else
      status 404
      { error: 'Contact not found' }.to_json
    end
  end

  post '/api/crm/contacts' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    contact = crm_manager.create_contact(data)
    if contact
      status 201
      contact.to_json
    else
      status 400
      { error: 'Failed to create contact' }.to_json
    end
  end

  put '/api/crm/contacts/:id' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    contact = crm_manager.update_contact(params[:id], data)
    if contact
      contact.to_json
    else
      status 404
      { error: 'Contact not found' }.to_json
    end
  end

  delete '/api/crm/contacts/:id' do
    content_type :json
    crm_manager = CRMManager.new
    crm_manager.delete_contact(params[:id])
    { success: true, message: 'Contact deleted' }.to_json
  end

  # Activity API Routes
  get '/api/crm/activities' do
    content_type :json
    crm_manager = CRMManager.new
    project_id = params[:project_id]
    organization_id = params[:organization_id]
    activities = crm_manager.list_activities(project_id, organization_id)
    activities.to_json
  end

  get '/api/crm/activities/:id' do
    content_type :json
    crm_manager = CRMManager.new
    activity = crm_manager.get_activity(params[:id])
    if activity
      activity.to_json
    else
      status 404
      { error: 'Activity not found' }.to_json
    end
  end

  post '/api/crm/activities' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    activity = crm_manager.create_activity(data)
    if activity
      status 201
      activity.to_json
    else
      status 400
      { error: 'Failed to create activity' }.to_json
    end
  end

  put '/api/crm/activities/:id' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    activity = crm_manager.update_activity(params[:id], data)
    if activity
      activity.to_json
    else
      status 404
      { error: 'Activity not found' }.to_json
    end
  end

  delete '/api/crm/activities/:id' do
    content_type :json
    crm_manager = CRMManager.new
    crm_manager.delete_activity(params[:id])
    { success: true, message: 'Activity deleted' }.to_json
  end

  # Note API Routes
  get '/api/crm/notes' do
    content_type :json
    crm_manager = CRMManager.new
    project_id = params[:project_id]
    organization_id = params[:organization_id]
    notes = crm_manager.list_notes(project_id, organization_id)
    notes.to_json
  end

  get '/api/crm/notes/:id' do
    content_type :json
    crm_manager = CRMManager.new
    note = crm_manager.get_note(params[:id])
    if note
      note.to_json
    else
      status 404
      { error: 'Note not found' }.to_json
    end
  end

  post '/api/crm/notes' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    note = crm_manager.create_note(data)
    if note
      status 201
      note.to_json
    else
      status 400
      { error: 'Failed to create note' }.to_json
    end
  end

  put '/api/crm/notes/:id' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    note = crm_manager.update_note(params[:id], data)
    if note
      note.to_json
    else
      status 404
      { error: 'Note not found' }.to_json
    end
  end

  delete '/api/crm/notes/:id' do
    content_type :json
    crm_manager = CRMManager.new
    crm_manager.delete_note(params[:id])
    { success: true, message: 'Note deleted' }.to_json
  end

  # Pipeline API Routes
  get '/api/crm/pipeline/stages' do
    content_type :json
    crm_manager = CRMManager.new
    crm_manager.get_pipeline_stages.to_json
  end

  get '/api/crm/pipeline/entries' do
    content_type :json
    crm_manager = CRMManager.new
    project_id = params[:project_id]
    organization_id = params[:organization_id]
    entries = crm_manager.list_pipeline_entries(project_id, organization_id)
    entries.to_json
  end

  get '/api/crm/pipeline/entries/:id' do
    content_type :json
    crm_manager = CRMManager.new
    entry = crm_manager.get_pipeline_entry(params[:id])
    if entry
      entry.to_json
    else
      status 404
      { error: 'Pipeline entry not found' }.to_json
    end
  end

  post '/api/crm/pipeline/entries' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    entry = crm_manager.create_pipeline_entry(data)
    if entry
      status 201
      entry.to_json
    else
      status 400
      { error: 'Failed to create pipeline entry' }.to_json
    end
  end

  put '/api/crm/pipeline/entries/:id' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    entry = crm_manager.update_pipeline_entry(params[:id], data)
    if entry
      entry.to_json
    else
      status 404
      { error: 'Pipeline entry not found' }.to_json
    end
  end

  delete '/api/crm/pipeline/entries/:id' do
    content_type :json
    crm_manager = CRMManager.new
    crm_manager.delete_pipeline_entry(params[:id])
    { success: true, message: 'Pipeline entry deleted' }.to_json
  end

  get '/api/crm/pipeline/summary' do
    content_type :json
    crm_manager = CRMManager.new
    crm_manager.get_pipeline_summary.to_json
  end

  # Project CRM Data API
  get '/api/crm/project/:project_id/:project_type' do
    content_type :json
    crm_manager = CRMManager.new
    crm_data = crm_manager.get_project_crm_data(params[:project_id], params[:project_type])
    crm_data.to_json
  end

  # Project Linking API
  post '/api/crm/project/link' do
    content_type :json
    data = JSON.parse(request.body.read)
    crm_manager = CRMManager.new
    link = crm_manager.link_project_to_organization(
      data['project_id'], 
      data['project_type'], 
      data['organization_id']
    )
    if link
      status 201
      link.to_json
    else
      status 400
      { error: 'Failed to link project' }.to_json
    end
  end

  delete '/api/crm/project/link/:project_id/:project_type' do
    content_type :json
    crm_manager = CRMManager.new
    result = crm_manager.unlink_project_from_organization(params[:project_id], params[:project_type])
    result.to_json
  end

  get '/api/crm/project/link/:project_id/:project_type' do
    content_type :json
    crm_manager = CRMManager.new
    link_data = crm_manager.get_project_organization(params[:project_id], params[:project_type])
    if link_data
      link_data.to_json
    else
      status 404
      { error: 'Project not linked to any organization' }.to_json
    end
  end

  get '/api/crm/organization/:organization_id/projects' do
    content_type :json
    crm_manager = CRMManager.new
    projects = crm_manager.get_organization_projects(params[:organization_id])
    projects.to_json
  end

  get '/api/crm/project-links' do
    content_type :json
    crm_manager = CRMManager.new
    links = crm_manager.get_all_project_links
    links.to_json
  end

  # GitHub Webhook Routes
  post '/webhook/github' do
    content_type :json
    
    # Get the webhook payload and signature
    payload = request.body.read
    signature = request.env['HTTP_X_HUB_SIGNATURE_256']
    
    # Handle the webhook
    webhook_handler = GitHubWebhookHandler.new
    result = webhook_handler.handle_webhook(payload, signature)
    
    if result[:error]
      status 400
      result.to_json
    else
      status 200
      result.to_json
    end
  end

  # GitHub PR Analysis Routes
  get '/api/github/pr/:repo/:pr_number/impact' do
    content_type :json
    
    repo = params[:repo]
    pr_number = params[:pr_number].to_i
    
    begin
      impact_analyzer = KnowledgeBaseImpactAnalyzer.new
      impact_report = impact_analyzer.analyze_pr_impact_on_knowledge_base(repo, pr_number)
      
      if impact_report.is_a?(Hash) && impact_report[:error]
        status 400
        impact_report.to_json
      else
        impact_report.to_json
      end
    rescue => e
      status 500
      { error: "Failed to analyze PR impact: #{e.message}" }.to_json
    end
  end

  get '/api/github/pr/:repo/:pr_number/conflicts' do
    content_type :json
    
    repo = params[:repo]
    pr_number = params[:pr_number].to_i
    
    begin
      github_integration = GitHubIntegration.new
      conflict_report = github_integration.detect_knowledge_base_conflicts(repo, pr_number)
      
      if conflict_report.is_a?(Hash) && conflict_report[:error]
        status 400
        conflict_report.to_json
      else
        conflict_report.to_json
      end
    rescue => e
      status 500
      { error: "Failed to detect conflicts: #{e.message}" }.to_json
    end
  end

  get '/api/github/pr/:repo/:pr_number/preliminary' do
    content_type :json
    
    repo = params[:repo]
    pr_number = params[:pr_number].to_i
    
    begin
      github_integration = GitHubIntegration.new
      preliminary_analysis = github_integration.perform_preliminary_analysis(repo, pr_number)
      
      if preliminary_analysis.is_a?(Hash) && preliminary_analysis[:error]
        status 400
        preliminary_analysis.to_json
      else
        preliminary_analysis.to_json
      end
    rescue => e
      status 500
      { error: "Failed to perform preliminary analysis: #{e.message}" }.to_json
    end
  end

  get '/api/github/impact-reports' do
    content_type :json
    
    cache_dir = 'cache'
    impact_reports = []
    
    if Dir.exist?(cache_dir)
      Dir.glob(File.join(cache_dir, 'impact_report_*.json')).each do |file|
        begin
          report_data = JSON.parse(File.read(file))
          impact_reports << {
            filename: File.basename(file),
            timestamp: report_data['timestamp'],
            pr_number: report_data['pr_analysis']['pr_number'],
            repo: report_data['pr_analysis']['repo'],
            impact_level: report_data['pr_analysis']['impact_level'],
            title: report_data['pr_analysis']['title']
          }
        rescue => e
          puts "Error reading impact report #{file}: #{e.message}"
        end
      end
    end
    
    # Sort by timestamp (newest first)
    impact_reports.sort_by { |r| r[:timestamp] }.reverse.to_json
  end

  get '/api/github/preliminary-analyses' do
    content_type :json
    
    cache_dir = 'cache'
    preliminary_analyses = []
    
    if Dir.exist?(cache_dir)
      Dir.glob(File.join(cache_dir, 'preliminary_analysis_*.json')).each do |file|
        begin
          analysis_data = JSON.parse(File.read(file))
          preliminary_analyses << {
            filename: File.basename(file),
            timestamp: analysis_data['timestamp'],
            pr_number: analysis_data['pr_number'],
            repo: analysis_data['repo'],
            impact_level: analysis_data['impact_level'],
            title: analysis_data['title']
          }
        rescue => e
          puts "Error reading preliminary analysis #{file}: #{e.message}"
        end
      end
    end
    
    # Sort by timestamp (newest first)
    preliminary_analyses.sort_by { |r| r[:timestamp] }.reverse.to_json
  end

# Sales Tools Management with Taxonomy Integration
class SalesToolsManager
  def initialize
    # Use the new taxonomy-based paths
    @rfp_dir = File.expand_path('../../content-repo/organizations/org_0/content_sources/general/private/static/rfp_projects', __FILE__)
    @sow_dir = File.expand_path('../../content-repo/organizations/org_0/content_sources/general/private/static/sow_projects', __FILE__)
    @proposal_dir = File.expand_path('../../content-repo/organizations/org_0/content_sources/general/private/static/proposal_projects', __FILE__)
  end

  def list_rfp_projects
    return [] unless Dir.exist?(@rfp_dir)
    
    begin
      Dir.entries(@rfp_dir).select do |entry|
        next if entry.start_with?('.')
        File.directory?(File.join(@rfp_dir, entry))
      end.sort.reverse
    rescue => e
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
      []
    end
  end

  def get_rfp_project_info(project_name)
    project_path = File.join(@rfp_dir, project_name)
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
      type: 'RFP',
      input_files: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      output_files: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      python_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.py') && !f.start_with?('.') }; rescue; []; end),
      text_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.txt', '.md') && !f.start_with?('.') }; rescue; []; end),
      input_count: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      output_count: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      created_date: created_date,
      last_modified: last_modified
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
      last_modified: last_modified
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
      type: 'PROPOSAL',
      input_files: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      output_files: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }; rescue; []; end) : [],
      python_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.py') && !f.start_with?('.') }; rescue; []; end),
      text_files: (begin; Dir.entries(project_path).select { |f| f.end_with?('.txt', '.md') && !f.start_with?('.') }; rescue; []; end),
      input_count: Dir.exist?(input_dir) ? (begin; Dir.entries(input_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      output_count: Dir.exist?(output_dir) ? (begin; Dir.entries(output_dir).reject { |f| f.start_with?('.') }.size; rescue; 0; end) : 0,
      created_date: created_date,
      last_modified: last_modified
    }
  end

  def create_rfp_project(project_name)
    project_path = File.join(@rfp_dir, project_name)
    return { success: false, error: 'Project already exists' } if Dir.exist?(project_path)

    begin
      Dir.mkdir(project_path)
      Dir.mkdir(File.join(project_path, 'input'))
      Dir.mkdir(File.join(project_path, 'output'))
      
      # Create .created file with timestamp
      created_timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      File.write(File.join(project_path, '.created'), created_timestamp)
      
      { success: true, message: "RFP Project '#{project_name}' created successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def create_sow_project(project_name)
    project_path = File.join(@sow_dir, project_name)
    return { success: false, error: 'Project already exists' } if Dir.exist?(project_path)

    begin
      Dir.mkdir(project_path)
      Dir.mkdir(File.join(project_path, 'input'))
      Dir.mkdir(File.join(project_path, 'output'))
      
      # Create .created file with timestamp
      created_timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      File.write(File.join(project_path, '.created'), created_timestamp)
      
      { success: true, message: "SOW Project '#{project_name}' created successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def create_proposal_project(project_name)
    project_path = File.join(@proposal_dir, project_name)
    return { success: false, error: 'Project already exists' } if Dir.exist?(project_path)

    begin
      Dir.mkdir(project_path)
      Dir.mkdir(File.join(project_path, 'input'))
      Dir.mkdir(File.join(project_path, 'output'))
      
      # Create .created file with timestamp
      created_timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      File.write(File.join(project_path, '.created'), created_timestamp)
      
      { success: true, message: "Proposal Project '#{project_name}' created successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def delete_rfp_project(project_name)
    project_path = File.join(@rfp_dir, project_name)
    return { success: false, error: 'Project does not exist' } unless Dir.exist?(project_path)

    begin
      FileUtils.rm_rf(project_path)
      { success: true, message: "RFP Project '#{project_name}' deleted successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def delete_sow_project(project_name)
    project_path = File.join(@sow_dir, project_name)
    return { success: false, error: 'Project does not exist' } unless Dir.exist?(project_path)

    begin
      FileUtils.rm_rf(project_path)
      { success: true, message: "SOW Project '#{project_name}' deleted successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def delete_proposal_project(project_name)
    project_path = File.join(@proposal_dir, project_name)
    return { success: false, error: 'Project does not exist' } unless Dir.exist?(project_path)

    begin
      FileUtils.rm_rf(project_path)
      { success: true, message: "Proposal Project '#{project_name}' deleted successfully" }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def run_rfp_script(project_name, script_name)
    project_path = File.join(@rfp_dir, project_name)
    return { success: false, error: 'Project does not exist' } unless Dir.exist?(project_path)

    script_path = File.join(project_path, script_name)
    return { success: false, error: 'Script does not exist' } unless File.exist?(script_path)

    begin
      Dir.chdir(project_path) do
        stdout, stderr, status = Open3.capture3("python3 #{script_name}")
        
        # Save execution log
        log_file = File.join(project_path, 'output', "#{script_name}_execution.log")
        File.write(log_file, "Script: #{script_name}\n\nSTDOUT:\n#{stdout}\n\nSTDERR:\n#{stderr}\n\nExit Code: #{status.exitstatus}")
        
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

  def run_sow_script(project_name, script_name)
    project_path = File.join(@sow_dir, project_name)
    return { success: false, error: 'Project does not exist' } unless Dir.exist?(project_path)

    script_path = File.join(project_path, script_name)
    return { success: false, error: 'Script does not exist' } unless File.exist?(script_path)

    begin
      Dir.chdir(project_path) do
        stdout, stderr, status = Open3.capture3("python3 #{script_name}")
        
        # Save execution log
        log_file = File.join(project_path, 'output', "#{script_name}_execution.log")
        File.write(log_file, "Script: #{script_name}\n\nSTDOUT:\n#{stdout}\n\nSTDERR:\n#{stderr}\n\nExit Code: #{status.exitstatus}")
        
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

  def run_proposal_script(project_name, script_name)
    project_path = File.join(@proposal_dir, project_name)
    return { success: false, error: 'Project does not exist' } unless Dir.exist?(project_path)

    script_path = File.join(project_path, script_name)
    return { success: false, error: 'Script does not exist' } unless File.exist?(script_path)

    begin
      Dir.chdir(project_path) do
        stdout, stderr, status = Open3.capture3("python3 #{script_name}")
        
        # Save execution log
        log_file = File.join(project_path, 'output', "#{script_name}_execution.log")
        File.write(log_file, "Script: #{script_name}\n\nSTDOUT:\n#{stdout}\n\nSTDERR:\n#{stderr}\n\nExit Code: #{status.exitstatus}")
        
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

  def get_sales_tools_summary
    rfp_projects = list_rfp_projects
    sow_projects = list_sow_projects
    proposal_projects = list_proposal_projects
    
    # Get recent projects (last 5)
    recent_rfp = rfp_projects.first(5).map { |name| get_rfp_project_info(name) }.compact
    recent_sow = sow_projects.first(5).map { |name| get_sow_project_info(name) }.compact
    recent_proposals = proposal_projects.first(5).map { |name| get_proposal_project_info(name) }.compact
    
    # Calculate estimated values
    rfp_total_value = calculate_rfp_total_value(rfp_projects)
    sow_total_value = calculate_sow_total_value(sow_projects)
    proposal_total_value = calculate_proposal_total_value(proposal_projects)
    total_value = rfp_total_value + sow_total_value + proposal_total_value
    
    {
      total_rfp: rfp_projects.size,
      total_sow: sow_projects.size,
      total_proposals: proposal_projects.size,
      total_all_proposals: rfp_projects.size + sow_projects.size + proposal_projects.size,
      recent_rfp: recent_rfp,
      recent_sow: recent_sow,
      recent_proposals: recent_proposals,
      open_rfp: rfp_projects.size,
      open_sow: sow_projects.size,
      open_proposals: proposal_projects.size,
      open_all_proposals: rfp_projects.size + sow_projects.size + proposal_projects.size,
      rfp_total_value: rfp_total_value,
      sow_total_value: sow_total_value,
      proposal_total_value: proposal_total_value,
      total_value: total_value
    }
  end

                  def calculate_rfp_total_value(projects)
                  total = 0
                  projects.each do |project_name|
                    project_info = get_rfp_project_info(project_name)
                    next unless project_info
                    
                    estimated_value = get_project_estimated_value(project_name, 'rfp')
                    total += estimated_value
                  end
                  total
                end
                
                def calculate_sow_total_value(projects)
                  total = 0
                  projects.each do |project_name|
                    project_info = get_sow_project_info(project_name)
                    next unless project_info
                    
                    estimated_value = get_project_estimated_value(project_name, 'sow')
                    total += estimated_value
                  end
                  total
                end

                def calculate_proposal_total_value(projects)
                  total = 0
                  projects.each do |project_name|
                    project_info = get_proposal_project_info(project_name)
                    next unless project_info
                    
                    estimated_value = get_project_estimated_value(project_name, 'proposal')
                    total += estimated_value
                  end
                  total
                end
                
                def get_project_estimated_value(project_name, project_type)
                  project_info = case project_type
                                when 'rfp'
                                  get_rfp_project_info(project_name)
                                when 'sow'
                                  get_sow_project_info(project_name)
                                when 'proposal'
                                  get_proposal_project_info(project_name)
                                end
                  return 0 unless project_info
                  
                  # Try to extract actual estimates from project files
                  actual_estimate = extract_actual_estimate(project_name, project_type)
                  return actual_estimate if actual_estimate > 0
                  
                  # Fallback to generic calculation if no actual estimate found
                  case project_type
                  when 'rfp'
                    base_value = 50000
                    complexity_bonus = project_info[:input_count] * 10000
                    base_value + complexity_bonus
                  when 'sow'
                    base_value = 75000
                    scope_bonus = project_info[:input_count] * 15000
                    base_value + scope_bonus
                  when 'proposal'
                    base_value = 25000
                    complexity_bonus = project_info[:input_count] * 5000
                    base_value + complexity_bonus
                  end
                end
                
                def extract_actual_estimate(project_name, project_type)
                  # Use absolute paths to ensure we can find the project directories
                  base_dir = File.expand_path('..', __FILE__)
                  project_path = case project_type
                                when 'rfp'
                                  File.join(base_dir, 'sales-tools/rfp-machine/projects', project_name)
                                when 'sow'
                                  File.join(base_dir, 'sales-tools/sow-machine/projects', project_name)
                                when 'proposal'
                                  File.join(base_dir, 'sales-tools/proposal-machine/projects', project_name)
                                end
                  
                  return 0 unless Dir.exist?(project_path)
                  
                  # Look for pricing information in various files
                  pricing_patterns = [
                    /\$([0-9,]+(?:\.\d{2})?)/,  # $1,234.56 or $1234
                    /Total.*Cost.*\$([0-9,]+(?:\.\d{2})?)/i,
                    /Cost.*Total.*\$([0-9,]+(?:\.\d{2})?)/i,
                    /Budget.*\$([0-9,]+(?:\.\d{2})?)/i,
                    /Estimated.*Cost.*\$([0-9,]+(?:\.\d{2})?)/i,
                    /This project cost is estimated at \$([0-9,]+(?:\.\d{2})?)/i,
                    /Licensing.*Cost.*\$([0-9,]+(?:\.\d{2})?)/i,
                    /Implementation.*Cost.*\$([0-9,]+(?:\.\d{2})?)/i
                  ]
                  
                  # Search in common files that might contain pricing
                  search_files = [
                    'AI_USER_PROMPT.md',
                    'README.md',
                    'pricing.md',
                    'estimate.md',
                    'cost.md',
                    'budget.md'
                  ]
                  
                  # Also search in output directory for final proposals
                  output_files = Dir.glob(File.join(project_path, 'output', '*.md')).map { |f| File.basename(f) }
                  search_files.concat(output_files)
                  
                  max_estimate = 0
                  
                  search_files.each do |filename|
                    file_path = File.join(project_path, filename)
                    next unless File.exist?(file_path)
                    
                    begin
                      content = File.read(file_path)
                      pricing_patterns.each do |pattern|
                        matches = content.scan(pattern)
                        matches.each do |match|
                          amount_str = match.is_a?(Array) ? match[0] : match
                          amount_str = amount_str.gsub(',', '')
                          amount = amount_str.to_f
                          max_estimate = [max_estimate, amount].max if amount > 0
                        end
                      end
                    rescue => e
                      # Skip files that can't be read
                      next
                    end
                  end
                  
                  # For RFP projects, also look for annual licensing costs and multiply by 3 years
                  if project_type == 'rfp'
                    annual_patterns = [
                      /Annual.*Licensing.*Cost.*\$([0-9,]+(?:\.\d{2})?)/i,
                      /Year.*Licensing.*Cost.*\$([0-9,]+(?:\.\d{2})?)/i,
                      /Licensing.*Cost.*\$([0-9,]+(?:\.\d{2})?)/i
                    ]
                    
                    search_files.each do |filename|
                      file_path = File.join(project_path, filename)
                      next unless File.exist?(file_path)
                      
                      begin
                        content = File.read(file_path)
                        annual_patterns.each do |pattern|
                          matches = content.scan(pattern)
                          matches.each do |match|
                            amount_str = match.is_a?(Array) ? match[0] : match
                            amount_str = amount_str.gsub(',', '')
                            annual_amount = amount_str.to_f
                            # Multiply by 3 years for total project value
                            three_year_value = annual_amount * 3
                            max_estimate = [max_estimate, three_year_value].max if three_year_value > 0
                          end
                        end
                      rescue => e
                        next
                      end
                    end
                  end
                  
                  max_estimate
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

# Wiz Chat Agent Helper Methods
def generate_wiz_response(message, context)
  # Connect to wiz-agent microservice
  begin
    require 'net/http'
    require 'uri'
    require 'json'
    
    # Prepare the request payload
    payload = {
      message: message,
      context: context,
      timestamp: Time.now.iso8601,
      session_id: SecureRandom.uuid
    }
    
    # Make HTTP request to wiz-agent microservice
    uri = URI('http://localhost:10001/chat')
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 30
    http.read_timeout = 60
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      return result['response'] || result['message'] || "I received a response from the AI service, but it was empty."
    else
      # Fallback to local response generation if microservice is unavailable
      puts "Wiz-agent microservice returned error: #{response.code} - #{response.body}"
      return generate_fallback_response(message, context)
    end
    
  rescue => e
    puts "Error connecting to wiz-agent microservice: #{e.message}"
    # Fallback to local response generation
    return generate_fallback_response(message, context)
  end
end

def generate_fallback_response(message, context)
  # Fallback response generation when microservice is unavailable
  case context
  when 'sales'
    generate_sales_response(message)
  when 'audit'
    generate_audit_response(message)
  when 'knowledge'
    generate_knowledge_response(message)
  else
    generate_general_response(message)
  end
end

def generate_sales_response(message)
  message_lower = message.downcase
  if message_lower.include?('rfp') || message_lower.include?('proposal')
    "I can help you with RFP and proposal generation! I can analyze requirements, generate responses, and track your sales pipeline. Would you like me to help you create a new RFP response or review existing ones?"
  elsif message_lower.include?('sow') || message_lower.include?('statement of work')
    "I can assist with Statement of Work creation! I can help you define project scope, estimate costs, and generate professional SOW documents. Would you like to start a new SOW project?"
  elsif message_lower.include?('pipeline') || message_lower.include?('sales')
    "I can help you track your sales pipeline! I can show you open RFPs, SOWs, and proposals, along with their total value and status. Would you like me to show you the current pipeline overview?"
  else
    "I'm here to help with your sales tools! I can assist with RFP responses, SOW creation, proposal generation, and pipeline tracking. What would you like to work on?"
  end
end

def generate_audit_response(message)
  message_lower = message.downcase
  if message_lower.include?('jira') || message_lower.include?('ticket')
    "I can help you audit JIRA tickets! I can identify obsolete tickets, find duplicates, and analyze ticket patterns. Would you like me to run a comprehensive JIRA audit?"
  elsif message_lower.include?('content') || message_lower.include?('documentation')
    "I can help you audit content and documentation! I can analyze content veracity, find inconsistencies, and suggest improvements. Would you like me to review your content?"
  elsif message_lower.include?('github') || message_lower.include?('code')
    "I can help you analyze GitHub impact! I can track code changes, identify affected documentation, and assess the impact of code modifications. Would you like me to analyze your GitHub repositories?"
  else
    "I'm here to help with audits and analysis! I can assist with JIRA ticket audits, content analysis, and GitHub impact assessment. What would you like to audit?"
  end
end

def generate_knowledge_response(message)
  message_lower = message.downcase
  if message_lower.include?('search') || message_lower.include?('find')
    "I can help you search the knowledge base! I can search across JIRA, Intercom, GitHub, and other sources to find relevant information. What would you like to search for?"
  elsif message_lower.include?('sync') || message_lower.include?('update')
    "I can help you sync the knowledge base! I can update content from all connected sources and ensure your knowledge base is current. Would you like me to sync all sources?"
  elsif message_lower.include?('relationship') || message_lower.include?('link')
    "I can help you explore content relationships! I can show you how different pieces of content are connected across sources. Would you like me to analyze content relationships?"
  else
    "I'm here to help with the knowledge base! I can assist with searching content, syncing sources, and exploring relationships between different pieces of information. What would you like to do?"
  end
end

def generate_general_response(message)
  message_lower = message.downcase
  if message_lower.include?('hello') || message_lower.include?('hi')
          "Hello! I'm Wiz, your AI assistant for Wiseguy. I can help you with sales tools, audits, and knowledge base management. What would you like to work on today?"
  elsif message_lower.include?('help') || message_lower.include?('what can you do')
    "I'm Wiz, your AI assistant! I can help you with:\n\n• **Sales Tools**: RFP responses, SOW creation, pipeline tracking\n• **Audits & Analysis**: JIRA audits, content analysis, GitHub impact\n• **Knowledge Base**: Content search, source syncing, relationship analysis\n\nWhat would you like to explore?"
  else
          "I'm Wiz, your AI assistant for Wiseguy! I can help you with sales tools, audits, and knowledge base management. How can I assist you today?"
  end
end

def generate_wiz_analysis(query, results)
  if results[:results]&.empty?
    return "I searched for '#{query}' but didn't find any relevant content in the knowledge base. You might want to try different keywords or check if the content sources are properly synced."
  end
  
  result_count = results[:results].length
  sources = results[:sources_queried] || []
  
  analysis = "I found #{result_count} relevant result(s) for '#{query}' from #{sources.join(', ')} sources.\n\n"
  
  # Add insights based on results
  if result_count > 5
    analysis += "📊 **High Relevance**: This query returned many results, indicating strong content coverage.\n"
  elsif result_count > 0
    analysis += "📊 **Moderate Relevance**: This query found some relevant content.\n"
  end
  
  # Check for vector relationships
  has_relationships = results[:results].any? { |r| r[:vector_relationships]&.any? }
  if has_relationships
    analysis += "🔗 **Content Relationships**: Some results have related content across different sources.\n"
  end
  
  analysis += "\nWould you like me to show you the detailed results or help you explore specific content?"
  
  analysis
end

# Start the application
if __FILE__ == $0
  puts "Wiseguy Veracity Audit System started at http://localhost:#{ENV['PORT'] || 3000}"
  puts "Make sure to configure your API credentials in config.env"
end 