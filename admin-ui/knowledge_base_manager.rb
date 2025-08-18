#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'net/http'
require 'uri'
require 'open3'
require 'fileutils'
require 'time'
require 'langchainrb'
require 'redis'
require 'aws-sdk-bedrock'
require 'digest'

class KnowledgeBaseManager
  def initialize
    @confluence_service = ConfluenceService.new
    @intercom_service = IntercomService.new
    @jira_service = JiraService.new
    @github_integration = GitHubIntegration.new
    
    # Initialize Redis with error handling
    begin
      @redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
      @redis.ping # Test connection
      puts "Redis connection established"
    rescue => e
      puts "Warning: Redis not available: #{e.message}"
      @redis = nil
    end
    
    # Initialize in-memory storage for when Redis is not available
    @@memory_storage ||= {}
    
    # Note: No test content is added - only authentic content from real sources
    
    # Initialize LangChain components with AWS Bedrock
    initialize_langchain_components
    
    # Initialize Vector Relationship Manager
    begin
      require_relative '../content-repo/vector_relationships/vector_manager'
      @vector_manager = VectorRelationshipManager.new
      puts "Vector Relationship Manager initialized"
    rescue => e
      puts "Warning: Vector Relationship Manager not available: #{e.message}"
      @vector_manager = nil
    end
    
    # Registered content sources
    @content_sources = {
      confluence: {
        name: 'Confluence',
        enabled: true,
        sync_interval: 3600, # 1 hour
        last_sync: nil,
        spaces: ['WISDOM', 'BRIGHTMOVE', 'JOBGORILLA']
      },
      intercom: {
        name: 'Intercom Help Center',
        enabled: true,
        sync_interval: 1800, # 30 minutes
        last_sync: nil
      },
      jira: {
        name: 'JIRA Tickets',
        enabled: true,
        sync_interval: 900, # 15 minutes
        last_sync: nil,
        projects: ['WISDOM', 'BRIGHTMOVE', 'JOBGORILLA']
      },
      github: {
        name: 'GitHub Repositories',
        enabled: true,
        sync_interval: 7200, # 2 hours
        last_sync: nil,
        organization: 'brightmove',
        repositories: [] # Will be populated from organization
      },
      documentation: {
        name: 'Local Documentation',
        enabled: true,
        sync_interval: 3600, # 1 hour
        last_sync: nil,
        paths: ['README.md', 'docs/', '*.md']
      }
    }
  end

  # Content Source Management
  def register_content_source(source_type, config)
    @content_sources[source_type.to_sym] = config.merge(
      enabled: true,
      last_sync: nil
    )
    save_content_sources_config
  end

  def unregister_content_source(source_type)
    @content_sources.delete(source_type.to_sym)
    save_content_sources_config
  end

  def get_content_sources
    @content_sources
  end

  def update_content_source_config(source_type, config)
    return false unless @content_sources[source_type.to_sym]
    
    @content_sources[source_type.to_sym].merge!(config)
    save_content_sources_config
    true
  end

  # Content Synchronization
  def sync_all_content_sources
    results = {}
    
    @content_sources.each do |source_type, config|
      next unless config[:enabled]
      next unless should_sync?(source_type, config)
      
      puts "Syncing #{config[:name]}..."
      results[source_type] = sync_content_source(source_type, config)
      @content_sources[source_type][:last_sync] = Time.now.iso8601
    end
    
    save_content_sources_config
    results
  end

  def sync_content_source(source_type, config)
    case source_type
    when :confluence
      sync_confluence_content(config)
    when :intercom
      sync_intercom_content(config)
    when :jira
      sync_jira_content(config)
    when :github
      sync_github_content(config)
    when :documentation
      sync_documentation_content(config)
    else
      { error: "Unknown content source type: #{source_type}" }
    end
  end

  def should_sync?(source_type, config)
    return true unless config[:last_sync]
    
    last_sync = Time.parse(config[:last_sync])
    interval = config[:sync_interval] || 3600
    Time.now - last_sync >= interval
  end

  # Content Retrieval with RAG
  def search_knowledge_base(query, source_types = nil, page = 1, page_size = 10)
    puts "DEBUG: Search called with source_types: #{source_types}"
    # Get relevant content from specified sources
    content = get_content_from_sources(source_types)
    puts "DEBUG: Retrieved content for sources: #{content.keys}"
    content.each do |source, items|
      puts "DEBUG: Source #{source} has #{items.length} items"
    end
    
    # If no content found in specified sources, return empty results
    if content.values.all?(&:empty?)
      puts "No content found in specified sources: #{source_types}"
      return {
        query: query,
        results: [],
        sources_queried: source_types || @content_sources.keys,
        timestamp: Time.now.iso8601,
        pagination: {
          current_page: page,
          page_size: page_size,
          total_results: 0,
          total_pages: 0,
          has_next_page: false,
          has_previous_page: false
        }
      }
    end
    
    # Get all relevant content (no limit for pagination)
    all_relevant_content = perform_rag_search(query, content, nil)
    
    # Note: No need to filter again since we already filtered the content sources above
    # The search will only return results from the specified sources
    puts "DEBUG: Found #{all_relevant_content.length} relevant content items"
    if source_types && !source_types.empty?
      puts "DEBUG: Results by source: #{all_relevant_content.group_by { |r| r[:source_type] }.transform_values(&:length)}"
    end
    
    # Calculate pagination
    total_results = all_relevant_content.length
    total_pages = (total_results.to_f / page_size).ceil
    page = [page, 1].max # Ensure page is at least 1
    page = [page, total_pages].min if total_pages > 0 # Ensure page doesn't exceed total pages
    
    # Get paginated results
    start_index = (page - 1) * page_size
    end_index = start_index + page_size - 1
    paginated_results = all_relevant_content[start_index..end_index] || []
    
    # Enhance with LLM analysis using LangChain retrieval chain
    enhanced_results = enhance_with_rag_chain(query, paginated_results)
    
    # Add vector relationships to each result
    enhanced_results = add_vector_relationships(enhanced_results)
    
    {
      query: query,
      results: enhanced_results,
      sources_queried: source_types || @content_sources.keys,
      timestamp: Time.now.iso8601,
      pagination: {
        current_page: page,
        page_size: page_size,
        total_results: total_results,
        total_pages: total_pages,
        has_next_page: page < total_pages,
        has_previous_page: page > 1
      }
    }
  end

  def enhance_with_rag_chain(query, relevant_content)
    return enhance_with_llm(query, relevant_content) unless @llm && @vector_store
    
    begin
      # Create a retrieval chain
      retriever = @vector_store.as_retriever(
        search_type: "similarity",
        search_kwargs: { k: relevant_content.length }
      )
      
      # Create prompt template for the chain
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: "Based on the following context, answer the question. If you cannot answer the question based on the context, say so.\n\nContext: {context}\n\nQuestion: {question}\n\nAnswer:",
        input_variables: ["context", "question"]
      )
      
      # Create the retrieval chain
      chain = Langchain::Chains::RetrievalQA.new(
        llm: @llm,
        retriever: retriever,
        prompt: prompt
      )
      
      # Run the chain
      response = chain.run(question: query)
      
      # Add the chain response to all relevant content
      relevant_content.each do |result|
        result[:llm_analysis] = response
        result[:rag_chain_used] = true
      end
      
      relevant_content
    rescue => e
      puts "RAG chain failed, falling back to simple LLM enhancement: #{e.message}"
      enhance_with_llm(query, relevant_content)
    end
  end

  def perform_audit(audit_type = 'comprehensive', options = {})
    case audit_type
    when 'comprehensive'
      perform_comprehensive_audit(options)
    when 'consistency'
      perform_consistency_audit(options)
    when 'completeness'
      perform_completeness_audit(options)
    when 'accuracy'
      perform_accuracy_audit(options)
    else
      { error: "Unknown audit type: #{audit_type}" }
    end
  end

  def schedule_audit(audit_type, schedule_config)
    # Schedule audit using cron-like syntax
    schedule = {
      type: audit_type,
      config: schedule_config,
      next_run: calculate_next_run(schedule_config),
      created_at: Time.now.iso8601
    }
    
    if @redis
      @redis.hset('scheduled_audits', audit_type, schedule.to_json)
    end
    
    schedule
  end

  def get_scheduled_audits
    if @redis
      audits = @redis.hgetall('scheduled_audits')
      audits.transform_values { |v| JSON.parse(v) }
    else
      # Return empty hash when Redis is not available
      {}
    end
  end

  def run_scheduled_audits
    scheduled_audits = get_scheduled_audits
    results = {}
    
    scheduled_audits.each do |audit_type, config|
      next unless should_run_scheduled_audit?(config)
      
      puts "Running scheduled audit: #{audit_type}"
      results[audit_type] = perform_audit(audit_type, config['config'])
      
      # Update next run time if Redis is available
      if @redis
        config['next_run'] = calculate_next_run(config['config'])
        @redis.hset('scheduled_audits', audit_type, config.to_json)
      end
    end
    
    results
  end

  def get_stored_content(source_type)
    if @redis
      content = []
      metadata_key = "#{source_type}:metadata"
      
      metadata = @redis.get(metadata_key)
      return [] unless metadata
      
      metadata = JSON.parse(metadata)
      count = metadata['count']
      
      (0...count).each do |index|
        key = "#{source_type}:#{index}"
        item = @redis.get(key)
        content << JSON.parse(item) if item
      end
      
      content
    else
      # Get content from memory storage - use string keys for consistency
      storage_key = source_type.to_s
      content = @@memory_storage[storage_key] || []
      puts "Retrieved #{content.length} items from memory storage with key: #{storage_key}"
      content
    end
  end

  private

  def create_bedrock_llm
    # Create a custom LLM wrapper that implements the LangChain interface
    # but uses AWS Bedrock under the hood
    Class.new do
      def initialize(bedrock_client)
        @bedrock_client = bedrock_client
      end
      
      def complete(prompt:, **options)
        # Convert LangChain prompt to Bedrock Claude format
        bedrock_prompt = convert_to_bedrock_format(prompt)
        
        # Call AWS Bedrock
        response = @bedrock_client.invoke_model(
          model_id: 'anthropic.claude-3-sonnet-20240229-v1:0',
          body: bedrock_prompt.to_json,
          content_type: 'application/json'
        )
        
        # Parse response and return in LangChain format
        response_body = JSON.parse(response.body.string)
        completion = response_body.dig('content', 0, 'text') || response_body['completion'] || ''
        
        # Create a response object that mimics LangChain's response
        response_obj = Object.new
        response_obj.define_singleton_method(:completion) { completion }
        response_obj
      end
      
      private
      
      def convert_to_bedrock_format(prompt)
        {
          messages: [
            {
              role: "user",
              content: prompt
            }
          ],
          max_tokens: 1000,
          temperature: 0.3,
          top_p: 1
        }
      end
    end.new(@bedrock_client)
  end
  
  def create_bedrock_embeddings
    # Create a custom embeddings wrapper that implements the LangChain interface
    # but uses AWS Bedrock Titan embeddings under the hood
    Class.new do
      def initialize(bedrock_client)
        @bedrock_client = bedrock_client
      end
      
      def embed(text)
        # Call AWS Bedrock Titan embeddings
        response = @bedrock_client.invoke_model(
          model_id: 'amazon.titan-embed-text-v1',
          body: { inputText: text }.to_json,
          content_type: 'application/json'
        )
        
        # Parse response and return embeddings
        response_body = JSON.parse(response.body.string)
        response_body['embedding'] || []
      end
      
      def embed_documents(texts)
        texts.map { |text| embed(text) }
      end
    end.new(@bedrock_client)
  end

  def initialize_langchain_components
    return unless ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']
    
    begin
      # Initialize AWS Bedrock client
      @bedrock_client = Aws::Bedrock::Client.new(
        region: ENV['AWS_REGION'] || 'us-east-1',
        credentials: Aws::Credentials.new(
          ENV['AWS_ACCESS_KEY_ID'],
          ENV['AWS_SECRET_ACCESS_KEY']
        )
      )
      
      # Create custom LLM wrapper for AWS Bedrock
      @llm = create_bedrock_llm
      
      # Initialize vector store with Redis
      @vector_store = Langchain::Vectorsearch::Redis.new(
        redis_url: ENV['REDIS_URL'] || 'redis://localhost:6379',
        index_name: 'knowledge_base',
        llm: @llm
      )
      
      # Create custom embeddings wrapper for AWS Bedrock
      @embeddings = create_bedrock_embeddings
      
      puts "AWS Bedrock LangChain components initialized successfully"
    rescue => e
      puts "Warning: Could not initialize AWS Bedrock LangChain components: #{e.message}"
      @llm = nil
      @vector_store = nil
      @embeddings = nil
      @bedrock_client = nil
    end
  end

  def sync_confluence_content(config)
    begin
      spaces = config[:spaces] || ['WISDOM', 'BRIGHTMOVE', 'JOBGORILLA']
      all_content = []
      
      spaces.each do |space|
        content = @confluence_service.get_all_content(space)
        all_content.concat(content)
      end
      
      # Store in Redis with embeddings
      store_content_with_embeddings(:confluence, all_content)
      
      {
        success: true,
        content_count: all_content.length,
        spaces: spaces
      }
    rescue => e
      { error: e.message }
    end
  end

  def sync_intercom_content(config)
    begin
      articles = @intercom_service.get_help_center_articles
      store_content_with_embeddings(:intercom, articles)
      
      {
        success: true,
        content_count: articles.length
      }
    rescue => e
      { error: e.message }
    end
  end

  def sync_jira_content(config)
    begin
      projects = config[:projects] || ['WISDOM', 'BRIGHTMOVE', 'JOBGORILLA']
      all_tickets = []
      
      projects.each do |project|
        tickets = @jira_service.get_issues("project = #{project}")
        all_tickets.concat(tickets)
      end
      
      store_content_with_embeddings(:jira, all_tickets)
      
      {
        success: true,
        content_count: all_tickets.length,
        projects: projects
      }
    rescue => e
      { error: e.message }
    end
  end

  def sync_github_content(config)
    begin
      # Get all repositories from the BrightMove organization
      org_repos = @github_integration.get_organization_repositories('brightmove')
      
      if org_repos.is_a?(Hash) && org_repos[:error]
        puts "Error fetching organization repositories: #{org_repos[:error]}"
        # Fallback to hardcoded repositories if organization access fails
        repos = config[:repositories] || ['brightmove/wiseguy', 'brightmove/brightmove-ats', 'brightmove/jobgorilla']
      else
        repos = org_repos
        puts "Successfully fetched #{repos.length} repositories from BrightMove organization"
      end
      
      all_content = []
      documentation_count = 0
      source_code_count = 0
      
      repos.each do |repo|
        puts "Processing repository: #{repo}"
        
        # Get documentation (README files, docs, etc.)
        doc_content = get_github_documentation(repo)
        all_content.concat(doc_content)
        documentation_count += doc_content.length
        
        # Get source code files
        source_content = get_github_source_code(repo)
        all_content.concat(source_content)
        source_code_count += source_content.length
      end
      
      store_content_with_embeddings(:github, all_content)
      
      {
        success: true,
        content_count: all_content.length,
        documentation_count: documentation_count,
        source_code_count: source_code_count,
        repositories: repos
      }
    rescue => e
      puts "Error in sync_github_content: #{e.message}"
      { error: e.message }
    end
  end

  def sync_documentation_content(config)
    begin
      paths = config[:paths] || ['README.md', 'docs/', '*.md']
      all_content = []
      
      paths.each do |path|
        content = get_local_documentation(path)
        all_content.concat(content)
      end
      
      store_content_with_embeddings(:documentation, all_content)
      
      {
        success: true,
        content_count: all_content.length,
        paths: paths
      }
    rescue => e
      { error: e.message }
    end
  end

  def get_content_from_sources(source_types = nil)
    content = {}
    
    source_types ||= @content_sources.keys
    
    source_types.each do |source_type|
      # Use get_stored_content to retrieve content consistently
      stored_content = get_stored_content(source_type)
      if stored_content && !stored_content.empty?
        content[source_type] = stored_content
        puts "Retrieved #{content[source_type].length} authentic items from #{source_type}"
      else
        content[source_type] = []
        puts "No authentic content found for #{source_type} - content must be synced from real sources"
      end
    end
    
    content
  end

  def perform_rag_search(query, content, limit)
    puts "DEBUG: RAG search called with content sources: #{content.keys}"
    # Temporarily force simple search for debugging
    puts "DEBUG: Forcing simple search for debugging"
    return perform_simple_search(query, content, limit)
    
    return perform_simple_search(query, content, limit) unless @vector_store && @embeddings
    
    puts "DEBUG: Using vector store for search"
    
    begin
      # Convert content to documents for vector search
      documents = content_to_documents(content)
      
      # Add documents to vector store if not already present
      add_documents_to_vector_store(documents)
      
      # Perform similarity search - use a large limit if nil (for pagination)
      search_limit = limit || 1000
      similar_docs = @vector_store.similarity_search(
        query: query,
        k: search_limit
      )
      
      # Convert back to our format
      results = similar_docs.map do |doc|
        {
          source_type: doc.metadata['source_type'],
          item: doc.metadata['original_item'],
          relevance_score: doc.metadata['similarity_score'] || 0.8,
          content: doc.page_content
        }
      end
      
      # Apply limit if specified (for backward compatibility)
      limit ? results.first(limit) : results
    rescue => e
      puts "Vector search failed, falling back to simple search: #{e.message}"
      perform_simple_search(query, content, limit)
    end
  end

  def perform_simple_search(query, content, limit)
    # Fallback to simple keyword-based search
    results = []
    
    puts "DEBUG: Searching in content sources: #{content.keys}"
    
    content.each do |source_type, items|
      puts "DEBUG: Searching #{items.length} items in #{source_type}"
      items.each do |item|
        relevance_score = calculate_relevance(query, item)
        if relevance_score > 0.01 # Much lower threshold to get more results
          puts "DEBUG: Found match in #{source_type}: #{item['title']} (score: #{relevance_score})"
          results << {
            source_type: source_type,
            item: item,
            relevance_score: relevance_score
          }
        end
      end
    end
    
    # Sort by relevance and apply limit if specified
    sorted_results = results.sort_by { |r| -r[:relevance_score] }
    limit ? sorted_results.first(limit) : sorted_results
  end



  def add_vector_relationships(search_results)
    # For now, create mock vector relationships based on content similarity
    # This demonstrates the concept while the full vector system is being set up
    
    search_results.each do |result|
      begin
        # Create mock relationships based on content analysis
        mock_relationships = create_mock_relationships(result, search_results)
        
        # Group relationships by type and add to result
        result[:vector_relationships] = {
          implements: mock_relationships.select { |r| r[:type] == 'implements' },
          documents: mock_relationships.select { |r| r[:type] == 'documents' },
          requires: mock_relationships.select { |r| r[:type] == 'requires' },
          affects: mock_relationships.select { |r| r[:type] == 'affects' },
          depends: mock_relationships.select { |r| r[:type] == 'depends' },
          conflicts: mock_relationships.select { |r| r[:type] == 'conflicts' }
        }
        
        # Add summary of relationship counts
        result[:relationship_summary] = {
          total_relationships: mock_relationships.length,
          by_type: result[:vector_relationships].transform_values(&:length)
        }
        
      rescue => e
        puts "Warning: Could not add vector relationships for result: #{e.message}"
        result[:vector_relationships] = {}
        result[:relationship_summary] = { total_relationships: 0, by_type: {} }
      end
    end
    
    search_results
  end

  def create_mock_relationships(result, all_results)
    relationships = []
    current_content = result[:item]['content'] || result[:item]['description'] || ''
    current_title = result[:item]['title'] || ''
    
    # Find related content based on keywords and content similarity
    all_results.each do |other_result|
      next if other_result == result # Skip self
      
      other_content = other_result[:item]['content'] || other_result[:item]['description'] || ''
      other_title = other_result[:item]['title'] || ''
      
      # Calculate similarity score
      similarity = calculate_content_similarity(current_content, other_content)
      
      # Create relationships based on content analysis
      if similarity > 0.1 # Lower threshold for relationship
        relationship_type = determine_relationship_type(current_content, other_content, current_title, other_title)
        
        relationships << {
          type: relationship_type,
          to_content_id: generate_content_id_for_search_result(other_result),
          title: other_title,
          content_title: other_title,
          source: other_result[:source_type].to_s,
          source_type: other_result[:source_type].to_s,
          strength: similarity,
          description: "Related content based on similarity analysis"
        }
      end
    end
    relationships
  end

  def calculate_content_similarity(content1, content2)
    # Simple keyword-based similarity calculation
    words1 = content1.downcase.split(/\W+/).select { |w| w.length > 3 }
    words2 = content2.downcase.split(/\W+/).select { |w| w.length > 3 }
    
    common_words = words1 & words2
    total_words = (words1 + words2).uniq
    
    return 0.0 if total_words.empty?
    common_words.length.to_f / total_words.length
  end

  def determine_relationship_type(content1, content2, title1, title2)
    # Determine relationship type based on content analysis
    combined_text = "#{content1} #{content2} #{title1} #{title2}".downcase
    
    if combined_text.include?('implement') || combined_text.include?('code') || combined_text.include?('source')
      'implements'
    elsif combined_text.include?('document') || combined_text.include?('guide') || combined_text.include?('manual')
      'documents'
    elsif combined_text.include?('require') || combined_text.include?('need') || combined_text.include?('dependency')
      'requires'
    elsif combined_text.include?('affect') || combined_text.include?('impact') || combined_text.include?('change')
      'affects'
    elsif combined_text.include?('depend') || combined_text.include?('rely') || combined_text.include?('build')
      'depends'
    elsif combined_text.include?('conflict') || combined_text.include?('contradict') || combined_text.include?('oppose')
      'conflicts'
    else
      'documents' # Default relationship type
    end
  end

  def generate_content_id_for_search_result(result)
    # Generate a consistent ID based on the search result content
    content_hash = Digest::MD5.hexdigest("#{result[:source_type]}:#{result[:item][:title]}:#{result[:item][:content]}")
    "search_result_#{content_hash}"
  end

  def enhance_with_llm(query, relevant_content)
    return relevant_content unless @llm
    
    begin
      # Create context from relevant content
      context = relevant_content.map { |r| format_content_for_llm(r[:item]) }.join("\n\n")
      
      # Create prompt template
      prompt = Langchain::Prompt::PromptTemplate.new(
        template: "You are a knowledge base assistant. Analyze the provided content and answer the query with relevant information. Cite sources when possible.\n\nQuery: {query}\n\nContext:\n{context}",
        input_variables: ["query", "context"]
      )
      
      # Generate enhanced response using LangChain LLM
      response = @llm.complete(
        prompt: prompt.format(query: query, context: context)
      )
      
      # Add LLM analysis to results
      relevant_content.each do |result|
        result[:llm_analysis] = response.completion
      end
      
      relevant_content
    rescue => e
      puts "LLM enhancement failed: #{e.message}"
      relevant_content
    end
  end

  def perform_comprehensive_audit(options)
    # Sync all content sources first
    sync_results = sync_all_content_sources
    
    # Perform various audit checks
    consistency_results = perform_consistency_audit(options)
    completeness_results = perform_completeness_audit(options)
    accuracy_results = perform_accuracy_audit(options)
    
    # Perform LLM-enhanced analysis if available
    llm_analysis = perform_llm_audit_analysis(options) if @llm
    
    {
      audit_type: 'comprehensive',
      sync_results: sync_results,
      consistency_audit: consistency_results,
      completeness_audit: completeness_results,
      accuracy_audit: accuracy_results,
      llm_analysis: llm_analysis,
      summary: generate_audit_summary([consistency_results, completeness_results, accuracy_results]),
      timestamp: Time.now.iso8601
    }
  end

  def perform_llm_audit_analysis(options)
    return nil unless @llm
    
    begin
      # Get all content for analysis
      content = get_content_from_sources
      
      # Create a comprehensive analysis prompt
      analysis_prompt = Langchain::Prompt::PromptTemplate.new(
        template: "Analyze the following knowledge base content and provide insights on:\n1. Overall quality and completeness\n2. Potential gaps or inconsistencies\n3. Recommendations for improvement\n4. Content freshness and relevance\n\nContent Summary:\n{content_summary}\n\nProvide a detailed analysis:",
        input_variables: ["content_summary"]
      )
      
      # Create content summary
      content_summary = content.map do |source_type, items|
        "#{source_type}: #{items.length} items"
      end.join("\n")
      
      # Generate analysis
      response = @llm.complete(
        prompt: analysis_prompt.format(content_summary: content_summary)
      )
      
      {
        analysis: response.completion,
        generated_at: Time.now.iso8601
      }
    rescue => e
      puts "LLM audit analysis failed: #{e.message}"
      nil
    end
  end

  def perform_consistency_audit(options)
    # Check for inconsistencies across content sources
    inconsistencies = []
    
    # Get content from all sources
    content = get_content_from_sources
    
    # Check for conflicting information
    content.each do |source_type, items|
      items.each do |item|
        conflicts = find_content_conflicts(item, content)
        inconsistencies.concat(conflicts) if conflicts.any?
      end
    end
    
    {
      audit_type: 'consistency',
      inconsistencies_found: inconsistencies.length,
      inconsistencies: inconsistencies,
      severity_distribution: categorize_inconsistencies(inconsistencies)
    }
  end

  def perform_completeness_audit(options)
    # Check for missing documentation
    gaps = []
    
    # Get code elements from GitHub
    code_elements = extract_code_elements_from_github
    
    # Check if code elements are documented
    code_elements.each do |element|
      if !is_element_documented?(element)
        gaps << {
          type: 'missing_documentation',
          element: element,
          severity: 'medium',
          recommendation: "Add documentation for #{element[:type]} '#{element[:name]}'"
        }
      end
    end
    
    {
      audit_type: 'completeness',
      gaps_found: gaps.length,
      gaps: gaps,
      coverage_percentage: calculate_coverage_percentage(code_elements, gaps)
    }
  end

  def perform_accuracy_audit(options)
    # Check for outdated information
    outdated_items = []
    
    # Get content from all sources
    content = get_content_from_sources
    
    content.each do |source_type, items|
      items.each do |item|
        if is_content_outdated?(item)
          outdated_items << {
            source_type: source_type,
            item: item,
            last_updated: item[:last_updated] || item['last_updated'],
            recommendation: "Review and update content"
          }
        end
      end
    end
    
    {
      audit_type: 'accuracy',
      outdated_items_found: outdated_items.length,
      outdated_items: outdated_items,
      accuracy_percentage: calculate_accuracy_percentage(content, outdated_items)
    }
  end

  def store_content_with_embeddings(source_type, content)
    if @redis
      # Store content in Redis
      content.each_with_index do |item, index|
        key = "#{source_type}:#{index}"
        @redis.setex(key, 86400, item.to_json) # 24 hour TTL
      end
      
      # Store metadata
      metadata = {
        count: content.length,
        last_updated: Time.now.iso8601,
        source_type: source_type
      }
      @redis.setex("#{source_type}:metadata", 86400, metadata.to_json)
    else
      # Store content in memory - use string keys for consistency
      storage_key = source_type.to_s
      @@memory_storage[storage_key] = content
      @@memory_storage["#{storage_key}:metadata"] = {
        count: content.length,
        last_updated: Time.now.iso8601,
        source_type: source_type
      }
      puts "Stored #{content.length} items from #{source_type} in memory with key: #{storage_key}"
    end
    
    # Add to vector store if available
    add_content_to_vector_store(source_type, content) if @vector_store && @embeddings
  end

  def add_content_to_vector_store(source_type, content)
    begin
      documents = content.map do |item|
        text = extract_text_from_item(item)
        metadata = {
          source_type: source_type,
          original_item: item,
          title: item['title'] || item[:title] || 'Untitled',
          url: item['url'] || item[:url] || '',
          last_updated: item['last_updated'] || item[:last_updated] || Time.now.iso8601
        }
        
        Langchain::Document.new(
          page_content: text,
          metadata: metadata
        )
      end
      
      # Add documents to vector store
      @vector_store.add_documents(documents)
      puts "Added #{documents.length} documents from #{source_type} to vector store"
    rescue => e
      puts "Failed to add #{source_type} content to vector store: #{e.message}"
    end
  end

  def calculate_relevance(query, item)
    # Improved keyword matching with better relevance scoring
    query_terms = query.downcase.split(/\s+/)
    content_text = extract_text_from_item(item).downcase
    title_text = (item['title'] || item[:title] || '').downcase
    
    # Check for exact file name matches (highest priority)
    if query.include?('.') && title_text.include?(query.downcase)
      return 2.0 # Very high score for exact file name match
    end
    
    # Check for exact matches first
    exact_matches = query_terms.count { |term| content_text.include?(term) || title_text.include?(term) }
    
    # Check for partial matches (substring matching)
    partial_matches = query_terms.count do |term|
      content_text.include?(term) || 
      title_text.include?(term) ||
      content_text.split(/\s+/).any? { |word| word.start_with?(term) || word.end_with?(term) }
    end
    
    # Give higher weight to title matches
    title_matches = query_terms.count { |term| title_text.include?(term) }
    
    # Check for file path matches (for source code files)
    file_path = item['file_path'] || item[:file_path] || ''
    file_path_matches = query_terms.count { |term| file_path.downcase.include?(term) }
    
    # Calculate relevance score - more lenient approach
    if exact_matches > 0
      # Base score from exact matches
      score = exact_matches.to_f / query_terms.length
      # Bonus for title matches
      score += (title_matches.to_f / query_terms.length) * 0.5
      # Bonus for file path matches
      score += (file_path_matches.to_f / query_terms.length) * 0.8
      # Bonus for partial matches
      score += (partial_matches.to_f / query_terms.length) * 0.2
      score
    elsif partial_matches > 0
      # Give a lower score for partial matches even without exact matches
      score = (partial_matches.to_f / query_terms.length) * 0.3
      # Bonus for title matches
      score += (title_matches.to_f / query_terms.length) * 0.2
      # Bonus for file path matches
      score += (file_path_matches.to_f / query_terms.length) * 0.6
      score
    else
      # Check for word similarity (e.g., "know" in "knowledge")
      similarity_matches = query_terms.count do |term|
        content_text.split(/\s+/).any? { |word| word.include?(term) || term.include?(word) }
      end
      
      if similarity_matches > 0
        (similarity_matches.to_f / query_terms.length) * 0.1
      else
        0.0
      end
    end
  end

  def format_content_for_llm(item)
    case item['type'] || item[:type]
    when 'confluence_page'
      "Confluence Page: #{item['title']}\n#{item['content']}"
    when 'intercom_article'
      "Help Article: #{item['title']}\n#{item['content']}"
    when 'jira_ticket'
      "JIRA Ticket: #{item['key']} - #{item['summary']}\n#{item['description']}"
    else
      item['content'] || item[:content] || item.to_s
    end
  end

  def find_content_conflicts(item, all_content)
    conflicts = []
    item_text = extract_text_from_item(item)
    
    all_content.each do |source_type, items|
      items.each do |other_item|
        next if other_item == item
        
        other_text = extract_text_from_item(other_item)
        
        # Check for conflicting information
        if has_conflicting_information?(item_text, other_text)
          conflicts << {
            item1: item,
            item2: other_item,
            source1: item['source_type'] || 'unknown',
            source2: source_type,
            conflict_type: 'information_mismatch'
          }
        end
      end
    end
    
    conflicts
  end

  def extract_text_from_item(item)
    case item['type'] || item[:type]
    when 'confluence_page'
      "#{item['title']} #{item['content']}"
    when 'intercom_article'
      "#{item['title']} #{item['content']}"
    when 'jira_ticket'
      "#{item['summary']} #{item['description']}"
    else
      item['content'] || item[:content] || item.to_s
    end
  end

  def has_conflicting_information?(text1, text2)
    # Simple conflict detection for now
    # In production, this would use more sophisticated NLP
    text1.downcase.include?('deprecated') && text2.downcase.include?('new')
  end

  def extract_code_elements_from_github
    # This would extract API endpoints, classes, methods from GitHub
    # For now, return empty array
    []
  end

  def is_element_documented?(element)
    # Check if code element is documented in any content source
    # For now, return false
    false
  end

  def is_content_outdated?(item)
    # Check if content is older than 6 months
    last_updated = item[:last_updated] || item['last_updated']
    return true unless last_updated
    
    last_updated_date = Time.parse(last_updated)
    Time.now - last_updated_date > 180 * 24 * 3600 # 180 days
  end

  def calculate_coverage_percentage(elements, gaps)
    return 100 if elements.empty?
    ((elements.length - gaps.length).to_f / elements.length * 100).round(2)
  end

  def calculate_accuracy_percentage(content, outdated_items)
    total_items = content.values.flatten.length
    return 100 if total_items == 0
    ((total_items - outdated_items.length).to_f / total_items * 100).round(2)
  end

  def categorize_inconsistencies(inconsistencies)
    {
      critical: inconsistencies.count { |i| i[:severity] == 'critical' },
      high: inconsistencies.count { |i| i[:severity] == 'high' },
      medium: inconsistencies.count { |i| i[:severity] == 'medium' },
      low: inconsistencies.count { |i| i[:severity] == 'low' }
    }
  end

  def generate_audit_summary(audit_results)
    total_issues = audit_results.sum { |r| r[:inconsistencies_found] || r[:gaps_found] || r[:outdated_items_found] || 0 }
    
    {
      total_issues: total_issues,
      audit_count: audit_results.length,
      overall_status: total_issues == 0 ? 'clean' : 'issues_found',
      recommendations: generate_recommendations(audit_results)
    }
  end

  def generate_recommendations(audit_results)
    recommendations = []
    
    audit_results.each do |result|
      case result[:audit_type]
      when 'consistency'
        if result[:inconsistencies_found] > 0
          recommendations << "Resolve #{result[:inconsistencies_found]} inconsistencies across content sources"
        end
      when 'completeness'
        if result[:gaps_found] > 0
          recommendations << "Add documentation for #{result[:gaps_found]} missing items"
        end
      when 'accuracy'
        if result[:outdated_items_found] > 0
          recommendations << "Update #{result[:outdated_items_found]} outdated content items"
        end
      end
    end
    
    recommendations
  end

  def calculate_next_run(schedule_config)
    # Parse cron-like schedule and calculate next run time
    # For now, return 1 hour from now
    Time.now + 3600
  end

  def should_run_scheduled_audit?(config)
    return false unless config['next_run']
    
    next_run = Time.parse(config['next_run'])
    Time.now >= next_run
  end

  def content_to_documents(content)
    documents = []
    
    content.each do |source_type, items|
      items.each do |item|
        text = extract_text_from_item(item)
        metadata = {
          source_type: source_type,
          original_item: item,
          title: item['title'] || item[:title] || 'Untitled',
          url: item['url'] || item[:url] || '',
          last_updated: item['last_updated'] || item[:last_updated] || Time.now.iso8601
        }
        
        documents << Langchain::Document.new(
          page_content: text,
          metadata: metadata
        )
      end
    end
    
    documents
  end

  def add_documents_to_vector_store(documents)
    return unless @vector_store && documents.any?
    
    begin
      @vector_store.add_documents(documents)
      puts "Added #{documents.length} documents to vector store"
    rescue => e
      puts "Failed to add documents to vector store: #{e.message}"
    end
  end

  def get_github_documentation(repo)
    begin
      puts "Fetching documentation from repository: #{repo}"
      content_items = []
      
      # Get README files
      readme_files = ['README.md', 'README.txt', 'readme.md', 'readme.txt']
      
      readme_files.each do |readme_file|
        content = @github_integration.get_repository_content(repo, readme_file)
        if content.is_a?(Hash) && !content[:error]
          content_items << {
            id: "#{repo}-#{readme_file}",
            title: "#{repo} - #{readme_file}",
            content: Base64.decode64(content['content']),
            url: "https://github.com/#{repo}/blob/main/#{readme_file}",
            source_type: 'github',
            repository: repo,
            file_type: 'readme',
            last_updated: content['updated_at'] || Time.now.iso8601
          }
          puts "Found README: #{readme_file} in #{repo}"
        end
      end
      
      # Get documentation from docs/ directory
      docs_content = @github_integration.get_repository_content(repo, 'docs')
      if docs_content.is_a?(Array) && !docs_content.empty?
        docs_content.each do |doc_file|
          next unless doc_file['name'].match?(/\.(md|txt|rst)$/i)
          
          file_content = @github_integration.get_repository_content(repo, "docs/#{doc_file['name']}")
          if file_content.is_a?(Hash) && !file_content[:error]
            content_items << {
              id: "#{repo}-docs-#{doc_file['name']}",
              title: "#{repo} - docs/#{doc_file['name']}",
              content: Base64.decode64(file_content['content']),
              url: "https://github.com/#{repo}/blob/main/docs/#{doc_file['name']}",
              source_type: 'github',
              repository: repo,
              file_type: 'documentation',
              last_updated: file_content['updated_at'] || Time.now.iso8601
            }
            puts "Found documentation: docs/#{doc_file['name']} in #{repo}"
          end
        end
      end
      
      # Get any .md files in the root directory
      root_content = @github_integration.get_repository_content(repo, '')
      if root_content.is_a?(Array) && !root_content.empty?
        root_content.each do |file|
          next unless file['name'].match?(/\.(md|txt|rst)$/i) && !file['name'].downcase.start_with?('readme')
          
          file_content = @github_integration.get_repository_content(repo, file['name'])
          if file_content.is_a?(Hash) && !file_content[:error]
            content_items << {
              id: "#{repo}-#{file['name']}",
              title: "#{repo} - #{file['name']}",
              content: Base64.decode64(file_content['content']),
              url: "https://github.com/#{repo}/blob/main/#{file['name']}",
              source_type: 'github',
              repository: repo,
              file_type: 'markdown',
              last_updated: file_content['updated_at'] || Time.now.iso8601
            }
            puts "Found markdown file: #{file['name']} in #{repo}"
          end
        end
      end
      
      puts "Total documentation items found for #{repo}: #{content_items.length}"
      content_items
      
    rescue => e
      puts "Error fetching documentation from #{repo}: #{e.message}"
      []
    end
  end

  public

  def get_github_source_code(repo)
    begin
      puts "Fetching ALL repository contents from: #{repo}"
      content_items = []
      
      # Define file patterns for ALL file types we want to index
      file_patterns = {
        # Source code files
        'java' => /\.(java|kt)$/i,
        'python' => /\.(py|pyw)$/i,
        'javascript' => /\.(js|jsx|ts|tsx)$/i,
        'ruby' => /\.(rb|erb)$/i,
        'php' => /\.(php|phtml)$/i,
        'go' => /\.go$/i,
        'rust' => /\.rs$/i,
        'csharp' => /\.(cs|csproj)$/i,
        'cpp' => /\.(cpp|cc|cxx|h|hpp)$/i,
        'c' => /\.(c|h)$/i,
        'sql' => /\.(sql|ddl|dml)$/i,
        'yaml' => /\.(yml|yaml)$/i,
        'json' => /\.json$/i,
        'xml' => /\.(xml|xsd|wsdl)$/i,
        'html' => /\.(html|htm)$/i,
        'css' => /\.(css|scss|sass|less)$/i,
        'docker' => /Dockerfile$/i,
        'gradle' => /\.(gradle|gradle\.kts)$/i,
        'maven' => /pom\.xml$/i,
        'npm' => /package\.json$/i,
        'gem' => /Gemfile$/i,
        'requirements' => /requirements\.txt$/i,
        'config' => /\.(conf|config|ini|properties)$/i,
        # Documentation files
        'markdown' => /\.(md|markdown)$/i,
        'text' => /\.(txt|rst|adoc)$/i,
        # Other important files
        'shell' => /\.(sh|bash|zsh)$/i,
        'batch' => /\.(bat|cmd)$/i,
        'makefile' => /(Makefile|makefile)$/i,
        'gitignore' => /\.gitignore$/i,
        'readme' => /README/i
      }
      
      # Start recursive scanning from root directory
      puts "Starting comprehensive scan of repository: #{repo}"
      content_items = scan_repository_recursively(repo, '', file_patterns)
      
      puts "Total files indexed for #{repo}: #{content_items.length}"
      content_items
      
    rescue => e
      puts "Error fetching repository contents from #{repo}: #{e.message}"
      []
    end
  end

  def scan_repository_recursively(repo, path, file_patterns, depth = 0)
    content_items = []
    
    # Prevent infinite recursion (max depth of 10 levels)
    return content_items if depth > 10
    
    begin
      # Get contents of current directory
      dir_content = @github_integration.get_repository_content(repo, path)
      
      if dir_content.is_a?(Hash) && dir_content[:error]
        puts "Error accessing #{path} in #{repo}: #{dir_content[:error]}"
        return content_items
      end
      
      if !dir_content.is_a?(Array) || dir_content.empty?
        puts "No content found in #{path} directory" unless path.empty?
        return content_items
      end
      
      puts "Scanning #{path.empty? ? 'root' : path} directory in #{repo} (found #{dir_content.length} items, depth: #{depth})"
      
      dir_content.each do |item|
        if item['type'] == 'dir'
          # Recursively scan subdirectories
          sub_path = path.empty? ? item['name'] : "#{path}/#{item['name']}"
          sub_items = scan_repository_recursively(repo, sub_path, file_patterns, depth + 1)
          content_items.concat(sub_items)
        else
          # Process file
          file_items = process_file(repo, path, item, file_patterns)
          content_items.concat(file_items)
        end
      end
      
    rescue => e
      puts "Error scanning directory #{path} in #{repo}: #{e.message}"
    end
    
    content_items
  end

  def process_file(repo, path, file, file_patterns)
    content_items = []
    
    # Determine file type and language
    file_type, language = determine_file_type(file['name'], file_patterns)
    
    # Skip files we don't want to index
    return content_items unless file_type
    
    # Get file content
    file_path = path.empty? ? file['name'] : "#{path}/#{file['name']}"
    file_content = @github_integration.get_repository_content(repo, file_path)
    
    if file_content.is_a?(Hash) && !file_content[:error]
      begin
        decoded_content = Base64.decode64(file_content['content'])
        
        # Skip files that are too large (over 2MB for comprehensive scanning)
        if decoded_content.bytesize > 2 * 1024 * 1024
          puts "Skipping large file: #{file_path} (#{decoded_content.bytesize} bytes)"
          return content_items
        end
        
        # Extract analysis based on file type
        analysis = if file_type == 'source_code'
          analyze_source_code(decoded_content, language, file['name'])
        else
          analyze_documentation(decoded_content, language, file['name'])
        end
        
        content_items << {
          id: "#{repo}-#{file_path}",
          title: "#{repo} - #{file_path}",
          content: decoded_content,
          url: "https://github.com/#{repo}/blob/develop/#{file_path}",
          source_type: 'github',
          repository: repo,
          file_type: file_type,
          language: language,
          file_path: file_path,
          code_analysis: analysis,
          last_updated: file_content['updated_at'] || Time.now.iso8601
        }
        puts "Indexed: #{file_path} (#{language}) in #{repo}"
      rescue => e
        puts "Error processing file #{file_path}: #{e.message}"
      end
    end
    
    content_items
  end

  def determine_file_type(filename, file_patterns)
    file_patterns.each do |type, pattern|
      if filename.match?(pattern)
        case type
        when 'java', 'python', 'javascript', 'ruby', 'php', 'go', 'rust', 'csharp', 'cpp', 'c', 'sql'
          return 'source_code', type
        when 'yaml', 'json', 'xml', 'html', 'css', 'docker', 'gradle', 'maven', 'npm', 'gem', 'requirements', 'config'
          return 'configuration', type
        when 'markdown', 'text', 'readme'
          return 'documentation', type
        when 'shell', 'batch', 'makefile', 'gitignore'
          return 'script', type
        else
          return 'other', type
        end
      end
    end
    
    [nil, nil] # Skip this file
  end

  def analyze_documentation(content, language, filename)
    {
      language: language,
      filename: filename,
      lines_of_code: content.lines.count,
      word_count: content.split(/\s+/).length,
      file_size: content.bytesize,
      has_code_blocks: content.include?('```'),
      has_links: content.scan(/\[([^\]]+)\]\(([^)]+)\)/).length,
      has_images: content.scan(/!\[([^\]]*)\]\(([^)]+)\)/).length
    }
  end

  def analyze_source_code(content, language, filename)
    analysis = {
      language: language,
      filename: filename,
      lines_of_code: content.lines.count,
      functions: [],
      classes: [],
      imports: [],
      dependencies: [],
      api_endpoints: [],
      database_queries: [],
      configuration: {}
    }
    
    case language
    when 'java'
      analysis[:classes] = content.scan(/class\s+(\w+)/).flatten
      analysis[:functions] = content.scan(/(?:public|private|protected)?\s*(?:static\s+)?(?:final\s+)?(?:<[^>]+>\s+)?(\w+)\s+(\w+)\s*\([^)]*\)/).map { |match| "#{match[1]} #{match[0]}" }
      analysis[:imports] = content.scan(/import\s+([^;]+);/).flatten
      analysis[:api_endpoints] = content.scan(/@(?:GetMapping|PostMapping|PutMapping|DeleteMapping|RequestMapping)\s*\([^)]*\)/).flatten
    when 'python'
      analysis[:functions] = content.scan(/def\s+(\w+)\s*\([^)]*\)/).flatten
      analysis[:classes] = content.scan(/class\s+(\w+)/).flatten
      analysis[:imports] = content.scan(/from\s+([^\s]+)\s+import|import\s+([^\s]+)/).flatten.compact
      analysis[:api_endpoints] = content.scan(/@(?:app\.route|flask\.route|django\.urls\.path)\s*\([^)]*\)/).flatten
    when 'javascript'
      analysis[:functions] = content.scan(/(?:function\s+)?(\w+)\s*\([^)]*\)\s*\{/).flatten
      analysis[:classes] = content.scan(/class\s+(\w+)/).flatten
      analysis[:imports] = content.scan(/import\s+([^;]+);|require\s*\([^)]+\)/).flatten
      analysis[:api_endpoints] = content.scan(/\.(?:get|post|put|delete)\s*\([^)]*\)/).flatten
    when 'ruby'
      analysis[:functions] = content.scan(/def\s+(\w+)/).flatten
      analysis[:classes] = content.scan(/class\s+(\w+)/).flatten
      analysis[:imports] = content.scan(/require\s+['"]([^'"]+)['"]/).flatten
    when 'sql'
      analysis[:database_queries] = content.scan(/(?:SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\s+[^;]+;/i).flatten
    when 'yaml', 'json'
      # Parse configuration files
      begin
        parsed = language == 'yaml' ? YAML.load(content) : JSON.parse(content)
        analysis[:configuration] = extract_configuration_info(parsed)
      rescue => e
        analysis[:configuration] = { error: "Could not parse #{language} file" }
      end
    end
    
    analysis
  end

  def extract_configuration_info(config)
    info = {}
    
    if config.is_a?(Hash)
      # Extract common configuration patterns
      info[:dependencies] = config['dependencies'] || config['requirements'] || config['packages']
      info[:version] = config['version']
      info[:name] = config['name'] || config['title']
      info[:description] = config['description']
      info[:scripts] = config['scripts'] if config['scripts']
      info[:database] = config['database'] || config['db']
      info[:api] = config['api'] || config['endpoints']
    end
    
    info
  end

  def get_local_documentation(path)
    # This would scan local filesystem for documentation
    # For now, return empty array
    []
  end

  # REMOVED: add_test_content method - No fake or test content should be added to the knowledge base
  # All content must come from authentic sources only

  def save_content_sources_config
    return unless @redis
    @redis.set('content_sources_config', @content_sources.to_json)
  end

  def load_content_sources_config
    return unless @redis
    config = @redis.get('content_sources_config')
    @content_sources = JSON.parse(config) if config
  end
end
