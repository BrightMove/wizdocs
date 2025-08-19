require 'yaml'
require 'json'
require 'redis'
require 'aws-sdk-bedrock'
require 'langchainrb'
require 'securerandom'
require 'logger'
require_relative 'vector_embeddings'
require_relative 'relationship_analyzer'
require_relative 'content_categorizer'

class VectorRelationshipManager
  attr_reader :config, :categories, :embeddings, :relationships, :logger

  def initialize(config_path = nil)
    @config_path = config_path || File.join(__dir__, 'config')
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    
    load_configurations
    initialize_storage
    initialize_embeddings
    initialize_relationships
  end

  # Content Management Methods
  def add_content(content:, source:, category:, metadata: {})
    content_id = generate_content_id
    timestamp = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    
    content_data = {
      id: content_id,
      content: content,
      source: source,
      category: category,
      metadata: metadata.merge(
        created_at: timestamp,
        updated_at: timestamp,
        vector_updated_at: nil
      )
    }
    
    # Validate content
    unless validate_content(content_data)
      raise ArgumentError, "Invalid content data"
    end
    
    # Store content
    store_content(content_data)
    
    # Generate vector embedding
    generate_embedding(content_data)
    
    # Analyze relationships (only if there are other content items)
    begin
      analyze_content_relationships(content_data)
    rescue => e
      @logger.warn "Skipping relationship analysis for first content item: #{e.message}"
    end
    
    @logger.info "Added content: #{content_id} (#{category})"
    content_id
  end

  def update_content(content_id:, content: nil, metadata: nil)
    existing = get_content(content_id)
    return nil unless existing
    
    # Update fields
    existing[:content] = content if content
    existing[:metadata] = existing[:metadata].merge(metadata) if metadata
    existing[:metadata][:updated_at] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    existing[:metadata][:vector_updated_at] = nil
    
    # Store updated content
    store_content(existing)
    
    # Regenerate embedding if content changed
    generate_embedding(existing) if content
    
    # Re-analyze relationships
    analyze_content_relationships(existing)
    
    @logger.info "Updated content: #{content_id}"
    existing
  end

  def remove_content(content_id)
    # Remove from storage
    key = "content:#{content_id}"
    if @storage.is_a?(Redis)
      @storage.del(key)
    else
      @storage.delete(key)
    end
    
    # Remove embeddings
    @embeddings.delete_embedding(content_id)
    
    # Remove relationships
    remove_content_relationships(content_id)
    
    @logger.info "Removed content: #{content_id}"
    true
  end

  def get_content(content_id)
    key = "content:#{content_id}"
    if @storage.is_a?(Redis)
      data = @storage.get(key)
    else
      data = @storage[key]
    end
    data ? JSON.parse(data, symbolize_names: true) : nil
  end

  def search_content(query:, category: nil, limit: 10)
    # Generate query embedding
    query_embedding = @embeddings.generate_embedding(query)
    
    # Search embeddings
    similar_ids = @embeddings.find_similar(query_embedding, limit: limit)
    
    # Filter by category if specified
    if category
      similar_ids = similar_ids.select { |id| get_content(id)&.dig(:category) == category }
    end
    
    # Return content with similarity scores
    similar_ids.map do |id|
      content = get_content(id)
      next unless content
      
      similarity = @embeddings.calculate_similarity(query_embedding, id)
      content.merge(similarity_score: similarity)
    end.compact
  end

  # Relationship Analysis Methods
  def analyze_relationships(content_id:, relationship_type: nil)
    content = get_content(content_id)
    return [] unless content
    
    relationships = []
    
    if relationship_type
      relationships = find_relationships(content, relationship_type)
    else
      # Analyze all relationship types
      @categories[:relationships].keys.each do |type|
        relationships.concat(find_relationships(content, type))
      end
    end
    
    relationships
  end

  def analyze_impact(change_description:, categories: nil, depth: 3)
    # Generate embedding for change description
    change_embedding = @embeddings.generate_embedding(change_description)
    
    # Find potentially affected content
    affected_content = []
    
          keys = if @storage.is_a?(Redis)
        @storage.keys("content:*")
      else
        @storage.keys.select { |k| k.start_with?("content:") }
      end
      
      keys.each do |key|
        content_id = key.split(':').last
        content = get_content(content_id)
        next unless content
        
        # Filter by categories if specified
        if categories && !categories.include?(content[:category])
          next
        end
        
        # Calculate impact score
        impact_score = @embeddings.calculate_similarity(change_embedding, content_id)
        
        if impact_score > @categories[:impact_analysis][:impact_threshold]
          affected_content << {
            content_id: content_id,
            content: content,
            impact_score: impact_score,
            relationships: analyze_relationships(content_id: content_id)
          }
        end
      end
    
    # Sort by impact score
    affected_content.sort_by { |item| -item[:impact_score] }
  end

  def detect_conflicts(category: nil)
    conflicts = []
    
    # Get all content
    all_content = get_all_content(category)
    
    # Compare content within and across categories
    all_content.each_with_index do |content1, i|
      all_content[i+1..-1].each do |content2|
        # Skip if same category and not checking for internal conflicts
        next if content1[:category] == content2[:category] && category
        
        # Calculate similarity
        similarity = @embeddings.calculate_similarity_between(
          content1[:id], content2[:id]
        )
        
        # Check for conflicts based on similarity and category differences
        if similarity > @categories[:relationships][:conflicts][:strength_threshold]
          conflict_score = calculate_conflict_score(content1, content2, similarity)
          
          if conflict_score > 0.5
            conflicts << {
              content1: content1,
              content2: content2,
              similarity: similarity,
              conflict_score: conflict_score,
              conflict_type: determine_conflict_type(content1, content2)
            }
          end
        end
      end
    end
    
    conflicts
  end

  # Vector Operations
  def update_embeddings(content_ids: nil)
    if content_ids
      # Update specific content embeddings
      content_ids.each do |id|
        content = get_content(id)
        next unless content
        generate_embedding(content)
      end
    else
      # Update all embeddings
      keys = if @storage.is_a?(Redis)
        @storage.keys("content:*")
      else
        @storage.keys.select { |k| k.start_with?("content:") }
      end
      
      keys.each do |key|
        content_id = key.split(':').last
        content = get_content(content_id)
        next unless content
        generate_embedding(content)
      end
    end
    
    @logger.info "Updated embeddings for #{content_ids ? content_ids.length : 'all'} content items"
  end

  def find_similar_content(content_id:, limit: 10, category: nil)
    content = get_content(content_id)
    return [] unless content
    
    similar_ids = @embeddings.find_similar_by_id(content_id, limit: limit)
    
    # Filter by category if specified
    if category
      similar_ids = similar_ids.select { |id| get_content(id)&.dig(:category) == category }
    end
    
    similar_ids.map do |id|
      content = get_content(id)
      next unless content
      
      similarity = @embeddings.calculate_similarity_between(content_id, id)
      content.merge(similarity_score: similarity)
    end.compact
  end

  # Batch Operations
  def batch_add_content(content_items)
    results = []
    
    content_items.each_slice(@config[:global][:batch_size]) do |batch|
      batch_results = batch.map do |item|
        begin
          add_content(**item)
        rescue => e
          @logger.error "Failed to add content: #{e.message}"
          nil
        end
      end
      
      results.concat(batch_results.compact)
    end
    
    @logger.info "Batch added #{results.length} content items"
    results
  end

  def batch_update_embeddings
    update_embeddings
  end

  # Health and Monitoring
  def health_check
    {
      storage: check_storage_health,
      embeddings: check_embeddings_health,
      relationships: check_relationships_health,
      content_count: get_content_count,
      last_updated: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    }
  end

  def get_statistics
    stats = {
      total_content: get_content_count,
      by_category: {},
      by_source: {},
      relationships: get_relationship_count,
      embeddings: get_embedding_count,
      last_updated: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    }
    
    # Count by category
    @categories[:categories].keys.each do |category|
      stats[:by_category][category] = count_content_by_category(category)
    end
    
    # Count by source
    get_all_sources.each do |source|
      stats[:by_source][source] = count_content_by_source(source)
    end
    
    stats
  end

  private

  def load_configurations
    @config = YAML.load_file(File.join(@config_path, 'sources.yml'))
    @categories = YAML.load_file(File.join(@config_path, 'categories.yml'))
    
    # Substitute environment variables in configuration
    @config = substitute_env_vars(@config)
    @categories = substitute_env_vars(@categories)
    
    # Convert string keys to symbols for easier access
    @config = symbolize_keys(@config)
    @categories = symbolize_keys(@categories)
  end

  def substitute_env_vars(obj)
    case obj
    when String
      # Replace ${VAR_NAME} with environment variable values
      obj.gsub(/\$\{([^}]+)\}/) { |match| ENV[$1] || match }
    when Hash
      obj.each_with_object({}) do |(key, value), result|
        result[key] = substitute_env_vars(value)
      end
    when Array
      obj.map { |item| substitute_env_vars(item) }
    else
      obj
    end
  end

  def symbolize_keys(obj)
    case obj
    when Hash
      obj.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = symbolize_keys(value)
      end
    when Array
      obj.map { |item| symbolize_keys(item) }
    else
      obj
    end
  end

  def initialize_storage
    if @config[:storage] && @config[:storage][:type] == 'redis'
      begin
        @storage = Redis.new(url: @config[:storage][:redis_url])
        @storage.ping # Test connection
      rescue => e
        @logger.warn "Redis connection failed, using in-memory storage: #{e.message}"
        @storage = {}
      end
    else
      # In-memory storage for development
      @storage = {}
    end
  end

  def initialize_embeddings
    @embeddings = VectorEmbeddings.new(@config)
  end

  def initialize_relationships
    @relationships = RelationshipAnalyzer.new(@categories, @embeddings)
  end

  def generate_content_id
    "content_#{SecureRandom.uuid}"
  end

  def validate_content(content_data)
    # Check category validity first
    unless @categories[:categories].key?(content_data[:category].to_sym)
      return false
    end
    
    # Check content length
    if content_data[:content].length > @config[:global][:max_content_length]
      return false
    end
    
    # Add default values for missing metadata fields
    add_default_metadata(content_data)
    
    true
  end

  def add_default_metadata(content_data)
    category = content_data[:category].to_sym
    metadata_fields = @categories[:categories][category][:metadata_fields]
    
    metadata_fields.each do |field|
      field_sym = field.to_sym
      if content_data[:metadata][field_sym].nil?
        content_data[:metadata][field_sym] = get_default_value(field, content_data)
      end
    end
  end

  def get_default_value(field, content_data)
    case field.to_s
    when 'title'
      content_data[:content].lines.first&.strip || 'Untitled'
    when 'content'
      content_data[:content]
    when 'url'
      "https://example.com/#{content_data[:id]}"
    when 'last_updated', 'created_date', 'last_modified'
      Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    when 'author'
      'System'
    when 'version'
      '1.0'
    when 'tags'
      []
    when 'priority'
      'medium'
    when 'status'
      'active'
    when 'assignee'
      'Unassigned'
    when 'labels'
      []
    when 'story_points'
      1
    when 'file_path'
      "path/to/#{content_data[:id]}"
    when 'commit_hash'
      '0000000'
    when 'branch'
      'main'
    when 'file_type'
      'txt'
    when 'size'
      content_data[:content].length
    else
      'N/A'
    end
  end

  def store_content(content_data)
    key = "content:#{content_data[:id]}"
    if @storage.is_a?(Redis)
      @storage.set(key, content_data.to_json)
    else
      @storage[key] = content_data.to_json
    end
  end

  def generate_embedding(content_data)
    embedding = @embeddings.generate_embedding(content_data[:content])
    @embeddings.store_embedding(content_data[:id], embedding)
    
    # Update metadata
    content_data[:metadata][:vector_updated_at] = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    store_content(content_data)
  end

  def analyze_content_relationships(content_data)
    @relationships.analyze_content_relationships(content_data)
  end

  def remove_content_relationships(content_id)
    @relationships.remove_content_relationships(content_id)
  end

  def find_relationships(content, relationship_type)
    @relationships.find_relationships(content, relationship_type)
  end

  def calculate_conflict_score(content1, content2, similarity)
    # Simple conflict scoring based on similarity and category differences
    base_score = similarity
    
    # Increase score for different categories
    if content1[:category] != content2[:category]
      base_score *= 1.2
    end
    
    # Increase score for contradictory indicators
    if has_contradictory_indicators?(content1, content2)
      base_score *= 1.5
    end
    
    base_score
  end

  def determine_conflict_type(content1, content2)
    if content1[:category] != content2[:category]
      "cross_category"
    else
      "internal"
    end
  end

  def has_contradictory_indicators?(content1, content2)
    # Check for contradictory keywords or indicators
    indicators1 = extract_indicators(content1[:content])
    indicators2 = extract_indicators(content2[:content])
    
    # Look for contradictory pairs
    contradictory_pairs = [
      ['implements', 'not implemented'],
      ['working', 'broken'],
      ['available', 'unavailable'],
      ['supported', 'unsupported']
    ]
    
    contradictory_pairs.any? do |pair|
      (indicators1.include?(pair[0]) && indicators2.include?(pair[1])) ||
      (indicators1.include?(pair[1]) && indicators2.include?(pair[0]))
    end
  end

  def extract_indicators(content)
    # Simple keyword extraction
    content.downcase.split(/\W+/).select { |word| word.length > 3 }
  end

  def get_all_content(category = nil)
    content = []
    if @storage.is_a?(Redis)
      keys = @storage.keys("content:*")
    else
      keys = @storage.keys.select { |k| k.start_with?("content:") }
    end
    
    keys.each do |key|
      item = get_content(key.split(':').last)
      next unless item
      next if category && item[:category] != category
      content << item
    end
    content
  end

  def get_all_sources
    sources = Set.new
    get_all_content.each { |content| sources.add(content[:source]) }
    sources.to_a
  end

  def count_content_by_category(category)
    get_all_content.count { |content| content[:category] == category }
  end

  def count_content_by_source(source)
    get_all_content.count { |content| content[:source] == source }
  end

  def get_content_count
    if @storage.is_a?(Redis)
      @storage.keys("content:*").length
    else
      @storage.keys.count { |k| k.start_with?("content:") }
    end
  end

  def get_relationship_count
    @relationships.get_relationship_count
  end

  def get_embedding_count
    @embeddings.get_embedding_count
  end

  def check_storage_health
    if @storage.is_a?(Redis)
      begin
        @storage.ping
        { status: 'healthy', connected: true }
      rescue => e
        { status: 'unhealthy', connected: false, error: e.message }
      end
    else
      { status: 'healthy', connected: true, type: 'in-memory' }
    end
  end

  def check_embeddings_health
    @embeddings.health_check
  end

  def check_relationships_health
    @relationships.health_check
  end
end
