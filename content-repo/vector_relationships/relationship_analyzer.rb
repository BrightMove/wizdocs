require 'json'
require 'redis'
require 'logger'

class RelationshipAnalyzer
  attr_reader :categories, :embeddings, :logger, :storage

  def initialize(categories, embeddings)
    @categories = categories
    @embeddings = embeddings
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    
    initialize_storage
  end

  def analyze_content_relationships(content_data)
    content_id = content_data[:id]
    category = content_data[:category]
    
    # Find relationships for each relationship type
    relationships = []
    
    @categories[:relationships].each do |relationship_type, config|
      if should_analyze_relationship?(content_data, relationship_type)
        found_relationships = find_relationships(content_data, relationship_type)
        relationships.concat(found_relationships)
      end
    end
    
    # Store relationships
    store_relationships(content_id, relationships)
    
    @logger.info "Analyzed #{relationships.length} relationships for content: #{content_id}"
    relationships
  end

  def find_relationships(content, relationship_type)
    config = @categories[:relationships][relationship_type]
    return [] unless config
    
    relationships = []
    content_id = content[:id]
    category = content[:category]
    
    # Get target category based on relationship direction
    target_category = get_target_category(category, relationship_type)
    return [] unless target_category
    
    # Find similar content in target category
    similar_content = find_similar_content_in_category(content_id, target_category)
    
    similar_content.each do |similar_item|
      similarity = similar_item[:similarity]
      
      # Check if similarity meets threshold
      if similarity >= config[:strength_threshold]
        # Check for relationship indicators if required
        if config[:vector_similarity_required] || has_relationship_indicators?(content, similar_item[:content], relationship_type)
          relationship = create_relationship(
            from_content: content,
            to_content: similar_item[:content],
            relationship_type: relationship_type,
            strength: similarity
          )
          
          relationships << relationship
        end
      end
    end
    
    relationships
  end

  def remove_content_relationships(content_id)
    # Remove relationships where this content is the source
    key_from = "relationships:from:#{content_id}"
    key_to = "relationships:to:#{content_id}"
    
    if @storage.is_a?(Redis)
      @storage.del(key_from)
      @storage.del(key_to)
    else
      @storage.delete(key_from)
      @storage.delete(key_to)
    end
    
    @logger.info "Removed relationships for content: #{content_id}"
  end

  def get_relationships_for_content(content_id, direction: :both)
    relationships = []
    
    if direction == :both || direction == :from
      from_relationships = get_relationships_from(content_id)
      relationships.concat(from_relationships)
    end
    
    if direction == :both || direction == :to
      to_relationships = get_relationships_to(content_id)
      relationships.concat(to_relationships)
    end
    
    relationships
  end

  def get_relationship_count
    if @storage.is_a?(Redis)
      from_count = @storage.keys("relationships:from:*").length
      to_count = @storage.keys("relationships:to:*").length
    else
      from_count = @storage.keys.count { |k| k.start_with?("relationships:from:") }
      to_count = @storage.keys.count { |k| k.start_with?("relationships:to:") }
    end
    from_count + to_count
  end

  def analyze_impact_chain(content_id, max_depth: 3)
    impact_chain = []
    visited = Set.new
    
    analyze_impact_recursive(content_id, impact_chain, visited, 0, max_depth)
    
    impact_chain
  end

  def detect_relationship_conflicts
    conflicts = []
    
    # Get all relationships
    all_relationships = get_all_relationships
    
    # Group by relationship type
    relationships_by_type = all_relationships.group_by { |rel| rel[:type] }
    
    relationships_by_type.each do |relationship_type, relationships|
      # Check for bidirectional conflicts
      conflicts.concat(detect_bidirectional_conflicts(relationships))
      
      # Check for circular dependencies
      conflicts.concat(detect_circular_dependencies(relationships))
    end
    
    conflicts
  end

  def get_relationship_statistics
    stats = {
      total_relationships: get_relationship_count,
      by_type: {},
      by_category: {},
      conflicts: detect_relationship_conflicts.length,
      last_updated: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    }
    
    # Count by relationship type
    @categories[:relationships].keys.each do |type|
      stats[:by_type][type] = count_relationships_by_type(type)
    end
    
    # Count by category
    @categories[:categories].keys.each do |category|
      stats[:by_category][category] = count_relationships_by_category(category)
    end
    
    stats
  end

  def health_check
    {
      status: 'healthy',
      storage_connected: check_storage_health,
      relationship_count: get_relationship_count,
      categories_loaded: @categories[:relationships].keys.length,
      embeddings_available: @embeddings.respond_to?(:health_check)
    }
  end

  private

  def initialize_storage
    if @embeddings.storage.is_a?(Redis)
      @storage = @embeddings.storage
    else
      # In-memory storage for development
      @storage = @embeddings.storage || {}
    end
  end

  def should_analyze_relationship?(content, relationship_type)
    config = @categories[:relationships][relationship_type]
    return false unless config
    
    # Check if content category matches relationship source
    if config[:from_category] && content[:category] != config[:from_category]
      return false
    end
    
    # Check if content category matches relationship target (for bidirectional)
    if config[:bidirectional] && config[:to_category] && content[:category] != config[:to_category]
      return false
    end
    
    true
  end

  def get_target_category(source_category, relationship_type)
    config = @categories[:relationships][relationship_type]
    return nil unless config
    
    if config[:bidirectional]
      # For bidirectional relationships, target is the opposite category
      config[:from_category] == source_category ? config[:to_category] : config[:from_category]
    else
      config[:to_category]
    end
  end

  def find_similar_content_in_category(content_id, target_category)
    # Get embedding for source content
    source_embedding = @embeddings.get_embedding(content_id)
    return [] unless source_embedding
    
    # Find similar content
    similar_ids = @embeddings.find_similar(source_embedding, limit: 20)
    return [] if similar_ids.empty?
    
    # Filter by target category and get content details
    similar_content = []
    
    similar_ids.each do |similar_id|
      # Get content data (this would need to be available from the main manager)
      # For now, we'll use a simplified approach
      similar_embedding = @embeddings.get_embedding(similar_id)
      next unless similar_embedding
      
      similarity = @embeddings.calculate_similarity(source_embedding, similar_embedding)
      
      similar_content << {
        content_id: similar_id,
        content: { id: similar_id, category: target_category }, # Simplified
        similarity: similarity
      }
    end
    
    similar_content
  end

  def has_relationship_indicators?(content1, content2, relationship_type)
    config = @categories[:relationships][relationship_type]
    return true unless config[:indicators] # If no indicators specified, assume true
    
    indicators = config[:indicators]
    combined_text = "#{content1[:content]} #{content2[:content]}".downcase
    
    indicators.any? { |indicator| combined_text.include?(indicator.downcase) }
  end

  def create_relationship(from_content:, to_content:, relationship_type:, strength:)
    {
      id: generate_relationship_id,
      from_content_id: from_content[:id],
      to_content_id: to_content[:id],
      from_category: from_content[:category],
      to_category: to_content[:category],
      type: relationship_type,
      strength: strength,
      created_at: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ"),
      metadata: {
        relationship_type: relationship_type,
        strength_threshold: @categories[:relationships][relationship_type][:strength_threshold]
      }
    }
  end

  def store_relationships(content_id, relationships)
    # Store relationships where this content is the source
    from_relationships = relationships.select { |rel| rel[:from_content_id] == content_id }
    if from_relationships.any?
      key = "relationships:from:#{content_id}"
      if @storage.is_a?(Redis)
        @storage.set(key, from_relationships.to_json)
      else
        @storage[key] = from_relationships.to_json
      end
    end
    
    # Store relationships where this content is the target
    to_relationships = relationships.select { |rel| rel[:to_content_id] == content_id }
    if to_relationships.any?
      key = "relationships:to:#{content_id}"
      if @storage.is_a?(Redis)
        @storage.set(key, to_relationships.to_json)
      else
        @storage[key] = to_relationships.to_json
      end
    end
  end

  def get_relationships_from(content_id)
    key = "relationships:from:#{content_id}"
    if @storage.is_a?(Redis)
      data = @storage.get(key)
    else
      data = @storage[key]
    end
    data ? JSON.parse(data, symbolize_names: true) : []
  end

  def get_relationships_to(content_id)
    key = "relationships:to:#{content_id}"
    if @storage.is_a?(Redis)
      data = @storage.get(key)
    else
      data = @storage[key]
    end
    data ? JSON.parse(data, symbolize_names: true) : []
  end

  def get_all_relationships
    relationships = []
    
    keys = if @storage.is_a?(Redis)
      @storage.keys("relationships:from:*")
    else
      @storage.keys.select { |k| k.start_with?("relationships:from:") }
    end
    
    keys.each do |key|
      if @storage.is_a?(Redis)
        data = @storage.get(key)
      else
        data = @storage[key]
      end
      next unless data
      
      from_relationships = JSON.parse(data, symbolize_names: true)
      relationships.concat(from_relationships)
    end
    
    relationships
  end

  def analyze_impact_recursive(content_id, impact_chain, visited, depth, max_depth)
    return if depth >= max_depth
    return if visited.include?(content_id)
    
    visited.add(content_id)
    
    # Get relationships from this content
    relationships = get_relationships_for_content(content_id, direction: :from)
    
    relationships.each do |relationship|
      impact_chain << {
        depth: depth,
        from_content_id: content_id,
        to_content_id: relationship[:to_content_id],
        relationship_type: relationship[:type],
        strength: relationship[:strength]
      }
      
      # Recursively analyze impact
      analyze_impact_recursive(
        relationship[:to_content_id],
        impact_chain,
        visited,
        depth + 1,
        max_depth
      )
    end
  end

  def detect_bidirectional_conflicts(relationships)
    conflicts = []
    
    relationships.each do |rel1|
      relationships.each do |rel2|
        next if rel1 == rel2
        
        # Check if these relationships form a bidirectional conflict
        if rel1[:from_content_id] == rel2[:to_content_id] &&
           rel1[:to_content_id] == rel2[:from_content_id] &&
           rel1[:type] != rel2[:type]
          
          conflicts << {
            type: 'bidirectional_conflict',
            relationship1: rel1,
            relationship2: rel2,
            description: "Conflicting relationship types between same content"
          }
        end
      end
    end
    
    conflicts
  end

  def detect_circular_dependencies(relationships)
    conflicts = []
    
    # Build dependency graph
    graph = build_dependency_graph(relationships)
    
    # Detect cycles
    cycles = detect_cycles(graph)
    
    cycles.each do |cycle|
      conflicts << {
        type: 'circular_dependency',
        cycle: cycle,
        description: "Circular dependency detected"
      }
    end
    
    conflicts
  end

  def build_dependency_graph(relationships)
    graph = {}
    
    relationships.each do |rel|
      from_id = rel[:from_content_id]
      to_id = rel[:to_content_id]
      
      graph[from_id] ||= []
      graph[from_id] << to_id
    end
    
    graph
  end

  def detect_cycles(graph)
    cycles = []
    visited = Set.new
    rec_stack = Set.new
    
    graph.keys.each do |node|
      unless visited.include?(node)
        detect_cycles_dfs(node, graph, visited, rec_stack, [], cycles)
      end
    end
    
    cycles
  end

  def detect_cycles_dfs(node, graph, visited, rec_stack, path, cycles)
    visited.add(node)
    rec_stack.add(node)
    path << node
    
    graph[node]&.each do |neighbor|
      if !visited.include?(neighbor)
        detect_cycles_dfs(neighbor, graph, visited, rec_stack, path, cycles)
      elsif rec_stack.include?(neighbor)
        # Found a cycle
        cycle_start = path.index(neighbor)
        cycle = path[cycle_start..-1] + [neighbor]
        cycles << cycle
      end
    end
    
    rec_stack.delete(node)
    path.pop
  end

  def generate_relationship_id
    "rel_#{SecureRandom.uuid}"
  end

  def count_relationships_by_type(relationship_type)
    all_relationships = get_all_relationships
    all_relationships.count { |rel| rel[:type] == relationship_type }
  end

  def count_relationships_by_category(category)
    all_relationships = get_all_relationships
    all_relationships.count { |rel| rel[:from_category] == category || rel[:to_category] == category }
  end

  def check_storage_health
    if @storage.is_a?(Redis)
      begin
        @storage.ping
        true
      rescue => e
        @logger.error "Storage health check failed: #{e.message}"
        false
      end
    else
      true
    end
  end
end
