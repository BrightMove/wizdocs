#!/usr/bin/env ruby

require 'json'
require 'openssl'
require 'base64'
require 'time'

class GitHubWebhookHandler
  def initialize
    @github_webhook_secret = ENV['GITHUB_WEBHOOK_SECRET']
    @impact_analyzer = KnowledgeBaseImpactAnalyzer.new
    @notification_service = NotificationService.new
  end

  def handle_webhook(payload, signature)
    # Verify webhook signature
    unless verify_signature(payload, signature)
      return { error: 'Invalid webhook signature' }
    end

    # Parse the webhook payload
    begin
      event_data = JSON.parse(payload)
    rescue JSON::ParserError => e
      return { error: "Invalid JSON payload: #{e.message}" }
    end

    # Handle different webhook events
    case event_data['action']
    when 'closed'
      handle_pull_request_closed(event_data)
    when 'opened'
      handle_pull_request_opened(event_data)
    when 'synchronize'
      handle_pull_request_updated(event_data)
    when 'reopened'
      handle_pull_request_reopened(event_data)
    else
      { message: "Unhandled webhook action: #{event_data['action']}" }
    end
  end

  private

  def verify_signature(payload, signature)
    return true unless @github_webhook_secret # Skip verification if no secret configured
    
    expected_signature = "sha256=#{OpenSSL::HMAC.hexdigest('sha256', @github_webhook_secret, payload)}"
    Rack::Utils.secure_compare(expected_signature, signature)
  end

  def handle_pull_request_closed(event_data)
    pull_request = event_data['pull_request']
    
    # Only process if the PR was merged (not just closed)
    unless pull_request['merged']
      return { message: "PR ##{pull_request['number']} was closed but not merged" }
    end

    puts "Processing merged PR ##{pull_request['number']} in #{event_data['repository']['full_name']}"
    
    # Analyze the impact on knowledge base
    repo = event_data['repository']['full_name']
    pr_number = pull_request['number']
    
    begin
      impact_report = @impact_analyzer.analyze_pr_impact_on_knowledge_base(repo, pr_number)
      
      # Store the impact report
      store_impact_report(impact_report)
      
      # Send notifications if high impact
      if impact_report[:pr_analysis][:impact_level] == 'high' || 
         impact_report[:pr_analysis][:impact_level] == 'critical'
        send_high_impact_notification(impact_report)
      end
      
      # Create JIRA ticket for documentation updates if needed
      if impact_report[:recommendations].any? { |r| r[:priority] == 'high' || r[:priority] == 'critical' }
        create_documentation_update_ticket(impact_report)
      end
      
      # Create JIRA ticket for knowledge base conflicts if any found
      if impact_report[:conflict_analysis] && impact_report[:conflict_analysis][:conflicts_found] > 0
        create_conflict_resolution_ticket(impact_report)
      end
      
      {
        success: true,
        message: "Impact analysis completed for PR ##{pr_number}",
        impact_level: impact_report[:pr_analysis][:impact_level],
        recommendations_count: impact_report[:recommendations].length
      }
      
    rescue => e
      puts "Error analyzing PR impact: #{e.message}"
      {
        error: "Failed to analyze PR impact: #{e.message}",
        pr_number: pr_number,
        repo: repo
      }
    end
  end

  def handle_pull_request_opened(event_data)
    pull_request = event_data['pull_request']
    repo = event_data['repository']['full_name']
    pr_number = pull_request['number']
    
    puts "New PR ##{pr_number} opened in #{repo}"
    
    # Perform preliminary analysis for new PRs
    begin
      preliminary_analysis = perform_preliminary_analysis(repo, pr_number)
      
      # Store preliminary analysis
      store_preliminary_analysis(preliminary_analysis)
      
      {
        success: true,
        message: "Preliminary analysis completed for PR ##{pr_number}",
        impact_level: preliminary_analysis[:impact_level]
      }
      
    rescue => e
      puts "Error performing preliminary analysis: #{e.message}"
      {
        error: "Failed to perform preliminary analysis: #{e.message}",
        pr_number: pr_number,
        repo: repo
      }
    end
  end

  def handle_pull_request_updated(event_data)
    pull_request = event_data['pull_request']
    repo = event_data['repository']['full_name']
    pr_number = pull_request['number']
    
    puts "PR ##{pr_number} updated in #{repo}"
    
    # Update preliminary analysis if it exists
    begin
      updated_analysis = perform_preliminary_analysis(repo, pr_number)
      update_preliminary_analysis(updated_analysis)
      
      {
        success: true,
        message: "Updated analysis for PR ##{pr_number}",
        impact_level: updated_analysis[:impact_level]
      }
      
    rescue => e
      puts "Error updating analysis: #{e.message}"
      {
        error: "Failed to update analysis: #{e.message}",
        pr_number: pr_number,
        repo: repo
      }
    end
  end

  def handle_pull_request_reopened(event_data)
    pull_request = event_data['pull_request']
    repo = event_data['repository']['full_name']
    pr_number = pull_request['number']
    
    puts "PR ##{pr_number} reopened in #{repo}"
    
    # Re-perform preliminary analysis
    handle_pull_request_opened(event_data)
  end

  def perform_preliminary_analysis(repo, pr_number)
    # This is a lighter analysis for open PRs
    github_integration = GitHubIntegration.new
    
    # Get basic PR information
    pr = github_integration.get_pull_request(repo, pr_number)
    return { error: 'Failed to get PR information' } if pr.is_a?(Hash) && pr[:error]
    
    files = github_integration.get_pull_request_files(repo, pr_number)
    return { error: 'Failed to get PR files' } if files.is_a?(Hash) && files[:error]
    
    # Quick impact assessment
    impact_score = 0
    change_types = []
    
    files.each do |file|
      filename = file['filename']
      
      # API changes
      if filename.match?(/\.(java|py|js|ts|rb|php|go|cs)$/i) && 
         (filename.include?('controller') || filename.include?('api') || filename.include?('endpoint'))
        impact_score += 8
        change_types << 'api'
      end
      
      # Database changes
      if filename.match?(/\.(sql|migration|schema)$/i) || filename.include?('migration')
        impact_score += 6
        change_types << 'database'
      end
      
      # Security changes
      if filename.include?('security') || filename.include?('auth') || filename.include?('permission')
        impact_score += 5
        change_types << 'security'
      end
      
      # Documentation changes
      if filename.match?(/\.(md|rst|txt)$/i) || filename.include?('docs/') || filename.include?('README')
        impact_score += 2
        change_types << 'documentation'
      end
    end
    
    # Determine impact level
    impact_level = case impact_score
    when 0..3
      'low'
    when 4..8
      'medium'
    else
      'high'
    end
    
    {
      pr_number: pr_number,
      repo: repo,
      title: pr['title'],
      author: pr['user']['login'],
      impact_score: impact_score,
      impact_level: impact_level,
      change_types: change_types.uniq,
      changed_files: files.length,
      analysis_type: 'preliminary',
      timestamp: Time.now.iso8601
    }
  end

  def store_impact_report(impact_report)
    # Store the impact report in cache
    cache_dir = 'cache'
    FileUtils.mkdir_p(cache_dir) unless Dir.exist?(cache_dir)
    
    filename = "impact_report_#{impact_report[:pr_analysis][:repo].gsub('/', '_')}_#{impact_report[:pr_analysis][:pr_number]}_#{Time.now.to_i}.json"
    filepath = File.join(cache_dir, filename)
    
    File.write(filepath, JSON.pretty_generate(impact_report))
    puts "Impact report stored: #{filepath}"
  end

  def store_preliminary_analysis(analysis)
    # Store preliminary analysis in cache
    cache_dir = 'cache'
    FileUtils.mkdir_p(cache_dir) unless Dir.exist?(cache_dir)
    
    filename = "preliminary_analysis_#{analysis[:repo].gsub('/', '_')}_#{analysis[:pr_number]}.json"
    filepath = File.join(cache_dir, filename)
    
    File.write(filepath, JSON.pretty_generate(analysis))
    puts "Preliminary analysis stored: #{filepath}"
  end

  def update_preliminary_analysis(analysis)
    # Update existing preliminary analysis
    store_preliminary_analysis(analysis)
  end

  def send_high_impact_notification(impact_report)
    # Send notification for high-impact changes
    pr_analysis = impact_report[:pr_analysis]
    
    notification = {
      type: 'high_impact_pr_merged',
      title: "High Impact PR Merged: #{pr_analysis[:title]}",
      message: "PR ##{pr_analysis[:pr_number]} in #{pr_analysis[:repo]} has been merged with #{pr_analysis[:impact_level]} impact on knowledge base",
      details: {
        pr_number: pr_analysis[:pr_number],
        repo: pr_analysis[:repo],
        impact_level: pr_analysis[:impact_level],
        changed_files: pr_analysis[:changed_files],
        recommendations_count: impact_report[:recommendations].length,
        affected_content: impact_report[:content_impact][:affected_confluence_pages].length + 
                         impact_report[:content_impact][:affected_intercom_articles].length
      },
      timestamp: Time.now.iso8601
    }
    
    @notification_service.send_notification(notification)
  end

  def create_documentation_update_ticket(impact_report)
    # Create JIRA ticket for documentation updates
    pr_analysis = impact_report[:pr_analysis]
    
    ticket_data = {
      summary: "Update documentation after PR ##{pr_analysis[:pr_number]} merge",
      description: generate_ticket_description(impact_report),
      issue_type: 'Task',
      priority: impact_report[:pr_analysis][:impact_level] == 'high' ? 'High' : 'Medium',
      labels: ['documentation', 'pr-impact', "pr-#{pr_analysis[:pr_number]}"],
      components: ['Documentation']
    }
    
    # This would integrate with the existing JiraService
    # For now, just log the ticket creation
    puts "Would create JIRA ticket: #{ticket_data[:summary]}"
    puts "Ticket description: #{ticket_data[:description]}"
  end

  def create_conflict_resolution_ticket(impact_report)
    # Create JIRA ticket for knowledge base conflicts
    pr_analysis = impact_report[:pr_analysis]
    conflict_analysis = impact_report[:conflict_analysis]
    
    ticket_data = {
      summary: "Resolve knowledge base conflicts after PR ##{pr_analysis[:pr_number]} merge",
      description: generate_conflict_ticket_description(impact_report),
      issue_type: 'Bug',
      priority: conflict_analysis[:summary][:by_severity][:critical] > 0 ? 'Critical' : 'High',
      labels: ['kb-conflict', 'documentation', 'pr-impact', "pr-#{pr_analysis[:pr_number]}"],
      components: ['Documentation']
    }
    
    # This would integrate with the existing JiraService
    # For now, just log the ticket creation
    puts "Would create conflict resolution JIRA ticket: #{ticket_data[:summary]}"
    puts "Ticket description: #{ticket_data[:description]}"
  end

  def generate_ticket_description(impact_report)
    pr_analysis = impact_report[:pr_analysis]
    
    description = <<~DESC
      Documentation updates required after PR ##{pr_analysis[:pr_number]} was merged.
      
      **PR Details:**
      - Repository: #{pr_analysis[:repo]}
      - Title: #{pr_analysis[:title]}
      - Author: #{pr_analysis[:author]}
      - Impact Level: #{pr_analysis[:impact_level].upcase}
      - Changed Files: #{pr_analysis[:changed_files]}
      
      **Impact Analysis:**
      - API Changes: #{pr_analysis[:api_changes].length}
      - Database Changes: #{pr_analysis[:database_changes].length}
      - Security Implications: #{pr_analysis[:security_implications].length}
      - Configuration Changes: #{pr_analysis[:configuration_changes].length}
      
      **Recommendations:**
    DESC
    
    impact_report[:recommendations].each do |rec|
      description += "- **#{rec[:priority].upcase}**: #{rec[:description]}\n"
      description += "  - Action: #{rec[:action]}\n"
    end
    
    description += "\n**Affected Content:**\n"
    
    if impact_report[:content_impact][:affected_confluence_pages].any?
      description += "- Confluence Pages: #{impact_report[:content_impact][:affected_confluence_pages].length}\n"
    end
    
    if impact_report[:content_impact][:affected_intercom_articles].any?
      description += "- Intercom Articles: #{impact_report[:content_impact][:affected_intercom_articles].length}\n"
    end
    
    description
  end

  def generate_conflict_ticket_description(impact_report)
    pr_analysis = impact_report[:pr_analysis]
    conflict_analysis = impact_report[:conflict_analysis]
    
    description = <<~DESC
      Knowledge base conflicts detected after PR ##{pr_analysis[:pr_number]} was merged.
      
      **PR Details:**
      - Repository: #{pr_analysis[:repo]}
      - Title: #{pr_analysis[:title]}
      - Author: #{pr_analysis[:author]}
      - Impact Level: #{pr_analysis[:impact_level].upcase}
      
      **Conflict Summary:**
      - Total Conflicts: #{conflict_analysis[:conflicts_found]}
      - Critical: #{conflict_analysis[:summary][:by_severity][:critical]}
      - High: #{conflict_analysis[:summary][:by_severity][:high]}
      - Medium: #{conflict_analysis[:summary][:by_severity][:medium]}
      - Low: #{conflict_analysis[:summary][:by_severity][:low]}
      
      **Conflict Types:**
    DESC
    
    conflict_analysis[:summary][:by_type].each do |type, count|
      description += "- #{type}: #{count}\n"
    end
    
    description += "\n**Affected Knowledge Base Items:**\n"
    conflict_analysis[:summary][:by_kb_type].each do |type, count|
      description += "- #{type.capitalize}: #{count}\n"
    end
    
    description += "\n**Detailed Conflicts:**\n"
    conflict_analysis[:conflicts].each do |conflict|
      description += "- **#{conflict[:severity].upcase}**: #{conflict[:description]}\n"
      description += "  - File: #{conflict[:file]}\n"
      description += "  - KB Item: #{conflict[:kb_item][:type]} - #{conflict[:kb_item][:title]}\n"
      description += "  - Action: #{conflict[:action]}\n\n"
    end
    
    description
  end
end

class NotificationService
  def initialize
    @slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
    @email_recipients = ENV['NOTIFICATION_EMAILS']&.split(',') || []
  end

  def send_notification(notification)
    # Send to Slack if configured
    send_slack_notification(notification) if @slack_webhook_url
    
    # Send email if configured
    send_email_notification(notification) if @email_recipients.any?
    
    # Log notification
    puts "Notification sent: #{notification[:title]}"
  end

  private

  def send_slack_notification(notification)
    require 'net/http'
    require 'uri'
    
    slack_message = {
      text: notification[:title],
      attachments: [
        {
          color: notification[:details][:impact_level] == 'high' ? '#ff0000' : '#ffa500',
          fields: [
            {
              title: 'Repository',
              value: notification[:details][:repo],
              short: true
            },
            {
              title: 'PR Number',
              value: "##{notification[:details][:pr_number]}",
              short: true
            },
            {
              title: 'Impact Level',
              value: notification[:details][:impact_level].upcase,
              short: true
            },
            {
              title: 'Changed Files',
              value: notification[:details][:changed_files].to_s,
              short: true
            },
            {
              title: 'Recommendations',
              value: notification[:details][:recommendations_count].to_s,
              short: true
            },
            {
              title: 'Affected Content',
              value: notification[:details][:affected_content].to_s,
              short: true
            }
          ]
        }
      ]
    }
    
    uri = URI(@slack_webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = slack_message.to_json
    
    response = http.request(request)
    
    unless response.code == '200'
      puts "Slack notification failed: #{response.code} - #{response.body}"
    end
  rescue => e
    puts "Error sending Slack notification: #{e.message}"
  end

  def send_email_notification(notification)
    # This would integrate with an email service
    # For now, just log the email notification
    puts "Would send email notification to: #{@email_recipients.join(', ')}"
    puts "Subject: #{notification[:title]}"
    puts "Body: #{notification[:message]}"
  end
end
