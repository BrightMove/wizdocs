#!/usr/bin/env ruby

require_relative 'vector_manager'
require_relative 'content_categorizer'
require 'json'
require 'sinatra'

# Integration class to connect Vector Relationship System with WizDocs
class WizDocsVectorIntegration
  attr_reader :vector_manager, :categorizer

  def initialize
    @vector_manager = VectorRelationshipManager.new
    @categorizer = ContentCategorizer.new(@vector_manager.config, @vector_manager.categories)
  end

  # API endpoints for WizDocs integration
  def setup_routes(app)
    # Content Management Endpoints
    app.post '/api/vector/content/add' do
      content_type :json
      
      begin
        data = JSON.parse(request.body.read, symbolize_names: true)
        
        # Categorize content
        categorization = @categorizer.categorize_content(
          content: data[:content],
          source: data[:source],
          metadata: data[:metadata] || {}
        )
        
        # Add to vector manager
        content_id = @vector_manager.add_content(
          content: data[:content],
          source: data[:source],
          category: categorization[:category],
          metadata: categorization[:metadata]
        )
        
        {
          success: true,
          content_id: content_id,
          category: categorization[:category],
          confidence: categorization[:confidence]
        }.to_json
      rescue => e
        status 400
        { success: false, error: e.message }.to_json
      end
    end

    app.get '/api/vector/content/search' do
      content_type :json
      
      query = params[:q]
      category = params[:category]
      limit = params[:limit]&.to_i || 10
      
      results = @vector_manager.search_content(
        query: query,
        category: category,
        limit: limit
      )
      
      {
        query: query,
        results: results,
        total: results.length
      }.to_json
    end

    app.get '/api/vector/content/:id' do
      content_type :json
      
      content_id = params[:id]
      content = @vector_manager.get_content(content_id)
      
      if content
        content.to_json
      else
        status 404
        { error: 'Content not found' }.to_json
      end
    end

    # Relationship Analysis Endpoints
    app.post '/api/vector/relationships/analyze' do
      content_type :json
      
      data = JSON.parse(request.body.read, symbolize_names: true)
      
      relationships = @vector_manager.analyze_relationships(
        content_id: data[:content_id],
        relationship_type: data[:relationship_type]
      )
      
      {
        content_id: data[:content_id],
        relationships: relationships,
        total: relationships.length
      }.to_json
    end

    app.post '/api/vector/relationships/impact' do
      content_type :json
      
      data = JSON.parse(request.body.read, symbolize_names: true)
      
      impacts = @vector_manager.analyze_impact(
        change_description: data[:change_description],
        categories: data[:categories]
      )
      
      {
        change_description: data[:change_description],
        impacts: impacts,
        total: impacts.length
      }.to_json
    end

    app.get '/api/vector/relationships/conflicts' do
      content_type :json
      
      conflicts = @vector_manager.detect_conflicts
      
      {
        conflicts: conflicts,
        total: conflicts.length
      }.to_json
    end

    # Vector Operations Endpoints
    app.post '/api/vector/embeddings/update' do
      content_type :json
      
      data = JSON.parse(request.body.read, symbolize_names: true)
      content_ids = data[:content_ids]
      
      @vector_manager.update_embeddings(content_ids: content_ids)
      
      {
        success: true,
        message: "Updated embeddings for #{content_ids ? content_ids.length : 'all'} content items"
      }.to_json
    end

    app.get '/api/vector/embeddings/similar' do
      content_type :json
      
      content_id = params[:content_id]
      limit = params[:limit]&.to_i || 10
      category = params[:category]
      
      similar = @vector_manager.find_similar_content(
        content_id: content_id,
        limit: limit,
        category: category
      )
      
      {
        content_id: content_id,
        similar: similar,
        total: similar.length
      }.to_json
    end

    # Statistics and Health Endpoints
    app.get '/api/vector/statistics' do
      content_type :json
      
      stats = @vector_manager.get_statistics
      stats.to_json
    end

    app.get '/api/vector/health' do
      content_type :json
      
      health = @vector_manager.health_check
      health.to_json
    end

    # Categorization Endpoints
    app.post '/api/vector/categorize' do
      content_type :json
      
      data = JSON.parse(request.body.read, symbolize_names: true)
      
      categorization = @categorizer.categorize_content(
        content: data[:content],
        source: data[:source],
        metadata: data[:metadata] || {}
      )
      
      categorization.to_json
    end

    app.post '/api/vector/categorize/suggest' do
      content_type :json
      
      data = JSON.parse(request.body.read, symbolize_names: true)
      
      suggestions = @categorizer.suggest_category(
        content: data[:content],
        source: data[:source]
      )
      
      {
        content: data[:content],
        source: data[:source],
        suggestions: suggestions
      }.to_json
    end

    # Batch Operations
    app.post '/api/vector/batch/add' do
      content_type :json
      
      data = JSON.parse(request.body.read, symbolize_names: true)
      content_items = data[:content_items] || []
      
      results = @vector_manager.batch_add_content(content_items)
      
      {
        success: true,
        results: results,
        total: results.length
      }.to_json
    end

    app.post '/api/vector/batch/update' do
      content_type :json
      
      @vector_manager.batch_update_embeddings
      
      {
        success: true,
        message: "Batch update completed"
      }.to_json
    end
  end

  # Helper methods for WizDocs integration
  def sync_content_from_source(source_type, source_config)
    case source_type
    when 'confluence'
      sync_confluence_content(source_config)
    when 'jira'
      sync_jira_content(source_config)
    when 'github'
      sync_github_content(source_config)
    when 'intercom'
      sync_intercom_content(source_config)
    else
      raise ArgumentError, "Unknown source type: #{source_type}"
    end
  end

  def sync_confluence_content(config)
    # Implementation for Confluence sync
    # This would use the Confluence API to fetch pages and add them to the vector system
    puts "Syncing Confluence content from #{config[:base_url]}"
    # TODO: Implement actual Confluence API integration
  end

  def sync_jira_content(config)
    # Implementation for JIRA sync
    # This would use the JIRA API to fetch issues and add them to the vector system
    puts "Syncing JIRA content from #{config[:base_url]}"
    # TODO: Implement actual JIRA API integration
  end

  def sync_github_content(config)
    # Implementation for GitHub sync
    # This would use the GitHub API to fetch repositories and add them to the vector system
    puts "Syncing GitHub content from #{config[:base_url]}"
    # TODO: Implement actual GitHub API integration
  end

  def sync_intercom_content(config)
    # Implementation for Intercom sync
    # This would use the Intercom API to fetch articles and add them to the vector system
    puts "Syncing Intercom content from #{config[:base_url]}"
    # TODO: Implement actual Intercom API integration
  end

  # Impact analysis for WizDocs
  def analyze_change_impact(change_description, affected_categories = nil)
    impacts = @vector_manager.analyze_impact(
      change_description: change_description,
      categories: affected_categories
    )
    
    # Group impacts by category
    impacts_by_category = impacts.group_by { |impact| impact[:content][:category] }
    
    # Calculate risk scores
    risk_assessment = calculate_risk_assessment(impacts)
    
    {
      change_description: change_description,
      impacts: impacts,
      impacts_by_category: impacts_by_category,
      risk_assessment: risk_assessment,
      recommendations: generate_recommendations(impacts, risk_assessment)
    }
  end

  private

  def calculate_risk_assessment(impacts)
    total_impact_score = impacts.sum { |impact| impact[:impact_score] }
    high_impact_count = impacts.count { |impact| impact[:impact_score] > 0.8 }
    medium_impact_count = impacts.count { |impact| impact[:impact_score] > 0.5 && impact[:impact_score] <= 0.8 }
    
    risk_level = if high_impact_count > 5
      'high'
    elsif high_impact_count > 2 || medium_impact_count > 10
      'medium'
    else
      'low'
    end
    
    {
      risk_level: risk_level,
      total_impact_score: total_impact_score,
      high_impact_count: high_impact_count,
      medium_impact_count: medium_impact_count,
      total_affected_items: impacts.length
    }
  end

  def generate_recommendations(impacts, risk_assessment)
    recommendations = []
    
    case risk_assessment[:risk_level]
    when 'high'
      recommendations << "High risk change detected. Consider breaking down into smaller changes."
      recommendations << "Review all high-impact items before proceeding."
      recommendations << "Schedule additional testing and validation."
    when 'medium'
      recommendations << "Medium risk change. Review affected items before proceeding."
      recommendations << "Consider incremental rollout approach."
    when 'low'
      recommendations << "Low risk change. Standard review process should be sufficient."
    end
    
    if impacts.any? { |impact| impact[:content][:category] == 'knowledge_base' }
      recommendations << "Update documentation to reflect changes."
    end
    
    if impacts.any? { |impact| impact[:content][:category] == 'backlog' }
      recommendations << "Review and update related backlog items."
    end
    
    recommendations
  end
end

# Example usage in WizDocs webapp/app.rb
if __FILE__ == $0
  puts "🔗 WizDocs Vector Integration"
  puts "This module provides vector relationship analysis for WizDocs"
  puts "To integrate with WizDocs, add the following to your app.rb:"
  puts ""
  puts "require_relative '../content-repo/vector_relationships/integrate_with_wizdocs'"
  puts "vector_integration = WizDocsVectorIntegration.new"
  puts "vector_integration.setup_routes(self)"
  puts ""
  puts "Then you can use the vector analysis endpoints in your WizDocs UI."
end
