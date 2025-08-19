require 'aws-sdk-bedrock'
require 'json'
require 'redis'
require 'logger'

class VectorEmbeddings
  attr_reader :config, :logger, :storage

  def initialize(config)
    @config = config
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    
    initialize_bedrock_client
    initialize_storage
  end

  def generate_embedding(text)
    return nil if text.nil? || text.empty?
    
    begin
      # Prepare text for embedding
      processed_text = preprocess_text(text)
      
      # Use mock embeddings if Bedrock is not available
      unless @bedrock_client
        return generate_mock_embedding(processed_text)
      end
      
      # Generate embedding using AWS Bedrock
      response = @bedrock_client.invoke_model(
        model_id: @config[:embeddings][:model],
        body: {
          inputText: processed_text
        }.to_json,
        content_type: 'application/json',
        accept: 'application/json'
      )
      
      # Parse response
      response_body = JSON.parse(response.body.read)
      embedding = response_body['embedding'] || []
      
      @logger.debug "Generated embedding for text of length #{text.length}"
      embedding
      
    rescue => e
      @logger.error "Failed to generate embedding: #{e.message}"
      generate_mock_embedding(text)
    end
  end

  def generate_mock_embedding(text)
    # Generate a deterministic mock embedding based on text content
    # This is for demonstration purposes when AWS Bedrock is not available
    dimensions = @config[:global][:vector_dimensions] || 1536
    seed = text.hash.abs
    
    embedding = []
    dimensions.times do |i|
      # Use a simple hash-based approach to generate consistent embeddings
      value = Math.sin(seed + i) * 0.5 + 0.5
      embedding << value
    end
    
    @logger.debug "Generated mock embedding for text of length #{text.length}"
    embedding
  end

  def store_embedding(content_id, embedding)
    return false unless embedding && !embedding.empty?
    
    begin
      key = "embedding:#{content_id}"
      if @storage.is_a?(Redis)
        @storage.set(key, embedding.to_json)
      else
        @storage[key] = embedding.to_json
      end
      @logger.debug "Stored embedding for content: #{content_id}"
      true
    rescue => e
      @logger.error "Failed to store embedding: #{e.message}"
      false
    end
  end

  def get_embedding(content_id)
    begin
      key = "embedding:#{content_id}"
      if @storage.is_a?(Redis)
        data = @storage.get(key)
      else
        data = @storage[key]
      end
      data ? JSON.parse(data) : nil
    rescue => e
      @logger.error "Failed to get embedding: #{e.message}"
      nil
    end
  end

  def delete_embedding(content_id)
    begin
      key = "embedding:#{content_id}"
      if @storage.is_a?(Redis)
        @storage.del(key)
      else
        @storage.delete(key)
      end
      @logger.debug "Deleted embedding for content: #{content_id}"
      true
    rescue => e
      @logger.error "Failed to delete embedding: #{e.message}"
      false
    end
  end

  def find_similar(query_embedding, limit: 10)
    return [] unless query_embedding && !query_embedding.empty?
    
    similarities = []
    
    # Get all stored embeddings
    keys = if @storage.is_a?(Redis)
      @storage.keys("embedding:*")
    else
      @storage.keys.select { |k| k.start_with?("embedding:") }
    end
    
    return [] if keys.empty?
    
    keys.each do |key|
      content_id = key.split(':').last
      stored_embedding = get_embedding(content_id)
      next unless stored_embedding
      
      # Calculate similarity
      similarity = calculate_cosine_similarity(query_embedding, stored_embedding)
      
      threshold = @config[:vector_similarity]&.dig(:cosine_threshold) || 0.7
      if similarity > threshold
        similarities << {
          content_id: content_id,
          similarity: similarity
        }
      end
    end
    
    # Sort by similarity and return top results
    similarities.sort_by { |item| -item[:similarity] }
                .first(limit)
                .map { |item| item[:content_id] }
  end

  def find_similar_by_id(content_id, limit: 10)
    embedding = get_embedding(content_id)
    return [] unless embedding
    
    find_similar(embedding, limit: limit)
  end

  def calculate_similarity(query_embedding, content_id)
    stored_embedding = get_embedding(content_id)
    return 0.0 unless stored_embedding
    
    calculate_cosine_similarity(query_embedding, stored_embedding)
  end

  def calculate_similarity_between(content_id1, content_id2)
    embedding1 = get_embedding(content_id1)
    embedding2 = get_embedding(content_id2)
    return 0.0 unless embedding1 && embedding2
    
    calculate_cosine_similarity(embedding1, embedding2)
  end

  def batch_generate_embeddings(texts)
    results = []
    
    texts.each_slice(@config[:embeddings][:batch_size]) do |batch|
      batch_results = batch.map do |text|
        begin
          generate_embedding(text)
        rescue => e
          @logger.error "Failed to generate embedding for batch item: #{e.message}"
          nil
        end
      end
      
      results.concat(batch_results.compact)
    end
    
    results
  end

  def batch_store_embeddings(embeddings_map)
    results = []
    
    embeddings_map.each do |content_id, embedding|
      begin
        success = store_embedding(content_id, embedding)
        results << { content_id: content_id, success: success }
      rescue => e
        @logger.error "Failed to store embedding for #{content_id}: #{e.message}"
        results << { content_id: content_id, success: false, error: e.message }
      end
    end
    
    results
  end

  def get_embedding_count
    if @storage.is_a?(Redis)
      @storage.keys("embedding:*").length
    else
      @storage.keys.count { |k| k.start_with?("embedding:") }
    end
  end

  def health_check
    if @bedrock_client
      begin
        # Test Bedrock connection
        test_response = @bedrock_client.invoke_model(
          model_id: @config[:embeddings][:model],
          body: { inputText: "test" }.to_json,
          content_type: 'application/json',
          accept: 'application/json'
        )
        
        {
          status: 'healthy',
          bedrock_connected: true,
          storage_connected: check_storage_health,
          embedding_count: get_embedding_count,
          model: @config[:embeddings][:model]
        }
      rescue => e
        {
          status: 'unhealthy',
          bedrock_connected: false,
          storage_connected: check_storage_health,
          error: e.message
        }
      end
    else
      {
        status: 'healthy',
        bedrock_connected: false,
        storage_connected: check_storage_health,
        embedding_count: get_embedding_count,
        model: 'mock_embeddings',
        note: 'Using mock embeddings for demonstration'
      }
    end
  end

  def get_statistics
    {
      total_embeddings: get_embedding_count,
      model: @config[:embeddings][:model],
      dimensions: @config[:global][:vector_dimensions],
      similarity_threshold: @config[:vector_similarity][:cosine_threshold],
      last_updated: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    }
  end

  private

  def initialize_bedrock_client
    # Check if AWS credentials are available
    unless ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']
      @logger.warn "AWS credentials not found. Using mock embeddings for demonstration."
      @bedrock_client = nil
      return
    end
    
    @bedrock_client = Aws::Bedrock::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1',
      credentials: Aws::Credentials.new(
        ENV['AWS_ACCESS_KEY_ID'],
        ENV['AWS_SECRET_ACCESS_KEY']
      )
    )
    
    @logger.info "Initialized AWS Bedrock client for embeddings"
  rescue => e
    @logger.warn "Failed to initialize Bedrock client: #{e.message}. Using mock embeddings."
    @bedrock_client = nil
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

  def preprocess_text(text)
    # Basic text preprocessing
    processed = text.strip
    
    # Truncate if too long
    max_tokens = @config[:embeddings][:max_tokens]
    if processed.length > max_tokens * 4  # Rough estimate: 4 chars per token
      processed = processed[0, max_tokens * 4]
    end
    
    processed
  end

  def calculate_cosine_similarity(vector1, vector2)
    return 0.0 if vector1.nil? || vector2.nil?
    return 0.0 if vector1.empty? || vector2.empty?
    return 0.0 if vector1.length != vector2.length
    
    # Calculate dot product
    dot_product = 0.0
    vector1.each_with_index do |val1, i|
      dot_product += val1 * vector2[i]
    end
    
    # Calculate magnitudes
    magnitude1 = Math.sqrt(vector1.map { |x| x * x }.sum)
    magnitude2 = Math.sqrt(vector2.map { |x| x * x }.sum)
    
    # Avoid division by zero
    return 0.0 if magnitude1 == 0 || magnitude2 == 0
    
    # Calculate cosine similarity
    similarity = dot_product / (magnitude1 * magnitude2)
    
    # Ensure result is between -1 and 1
    [[similarity, 1.0].min, -1.0].max
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
