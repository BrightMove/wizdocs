require 'yaml'
require 'json'
require 'logger'
require 'uri'

class ContentCategorizer
  attr_reader :config, :categories, :logger

  def initialize(config, categories)
    @config = config
    @categories = categories
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end

  def categorize_content(content:, source:, metadata: {})
    # Determine category based on source and content analysis
    category = determine_category_by_source(source)
    
    # Validate category
    unless @categories[:categories].key?(category.to_sym)
      @logger.warn "Unknown category for source #{source}, using default"
      category = 'knowledge_base' # Default fallback
    end
    
    # Enhance metadata with categorization info
    enhanced_metadata = enhance_metadata(metadata, category, source)
    
    {
      category: category,
      metadata: enhanced_metadata,
      confidence: calculate_categorization_confidence(content, source, category)
    }
  end

  def auto_categorize_batch(content_items)
    results = []
    
    content_items.each do |item|
      begin
        categorization = categorize_content(
          content: item[:content],
          source: item[:source],
          metadata: item[:metadata] || {}
        )
        
        results << item.merge(categorization)
      rescue => e
        @logger.error "Failed to categorize content: #{e.message}"
        results << item.merge(
          category: 'knowledge_base',
          metadata: item[:metadata] || {},
          confidence: 0.0
        )
      end
    end
    
    results
  end

  def validate_categorization(content:, category:, source:)
    errors = []
    
    # Check if category exists
    unless @categories[:categories].key?(category.to_sym)
      errors << "Invalid category: #{category}"
    end
    
    # Check if source is valid for category
    valid_sources = @categories[:categories][category.to_sym][:sources]
    unless valid_sources.include?(source)
      errors << "Source '#{source}' is not valid for category '#{category}'"
    end
    
    # Check content indicators
    indicators = @categories[:categories][category.to_sym][:content_indicators]
    if indicators && !has_category_indicators?(content, indicators)
      errors << "Content does not match expected indicators for category '#{category}'"
    end
    
    # Check required metadata fields
    required_fields = @categories[:categories][category.to_sym][:metadata_fields]
    missing_fields = required_fields.select { |field| !metadata.key?(field.to_sym) }
    if missing_fields.any?
      errors << "Missing required metadata fields: #{missing_fields.join(', ')}"
    end
    
    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def suggest_category(content:, source:)
    # Analyze content to suggest the most appropriate category
    suggestions = []
    
    @categories[:categories].each do |category, config|
      score = calculate_category_score(content, source, category)
      suggestions << {
        category: category,
        score: score,
        confidence: score / 100.0
      }
    end
    
    # Sort by score and return top suggestions
    suggestions.sort_by { |s| -s[:score] }
  end

  def extract_metadata_from_content(content:, source:, category:)
    metadata = {}
    
    # Extract basic metadata
    metadata[:title] = extract_title(content)
    metadata[:content_length] = content.length
    metadata[:word_count] = content.split(/\s+/).length
    metadata[:language] = detect_language(content)
    
    # Extract category-specific metadata
    case category
    when 'knowledge_base'
      metadata.merge!(extract_knowledge_base_metadata(content, source))
    when 'backlog'
      metadata.merge!(extract_backlog_metadata(content, source))
    when 'platform'
      metadata.merge!(extract_platform_metadata(content, source))
    end
    
    metadata
  end

  def get_categorization_statistics
    stats = {
      categories: {},
      sources: {},
      indicators: {},
      last_updated: Time.now.iso8601
    }
    
    # Category statistics
    @categories[:categories].each do |category, config|
      stats[:categories][category] = {
        description: config[:description],
        sources: config[:sources],
        indicators: config[:content_indicators],
        metadata_fields: config[:metadata_fields]
      }
    end
    
    # Source statistics
    @config.each do |category, sources|
      sources.each do |source, config|
        stats[:sources][source] = {
          category: category,
          base_url: config[:base_url],
          content_types: config[:content_types],
          update_frequency: config[:update_frequency]
        }
      end
    end
    
    stats
  end

  private

  def determine_category_by_source(source)
    # Map source to category based on configuration
    @categories[:categories].each do |category, config|
      if config[:sources].include?(source)
        return category
      end
    end
    
    # Fallback to knowledge_base if source not found
    'knowledge_base'
  end

  def enhance_metadata(metadata, category, source)
    enhanced = metadata.dup
    
    # Add categorization metadata
    enhanced[:categorized_at] = Time.now.iso8601
    enhanced[:category] = category
    enhanced[:source] = source
    
    # Add category-specific metadata
    category_config = @categories[:categories][category.to_sym]
    if category_config
      enhanced[:category_description] = category_config[:description]
      enhanced[:valid_sources] = category_config[:sources]
    end
    
    enhanced
  end

  def calculate_categorization_confidence(content, source, category)
    confidence = 0.0
    
    # Base confidence from source mapping
    confidence += 0.4 if @config[category.to_sym]&.key?(source)
    
    # Content indicator confidence
    indicators = @categories[:categories][category.to_sym][:content_indicators]
    if indicators && has_category_indicators?(content, indicators)
      confidence += 0.3
    end
    
    # Content length confidence
    if content.length > 100
      confidence += 0.2
    end
    
    # URL/format confidence
    if has_valid_format?(content, source, category)
      confidence += 0.1
    end
    
    [confidence, 1.0].min
  end

  def has_category_indicators?(content, indicators)
    return false unless indicators
    
    content_lower = content.downcase
    indicators.any? { |indicator| content_lower.include?(indicator.downcase) }
  end

  def calculate_category_score(content, source, category)
    score = 0
    
    # Source mapping score
    if @config[category.to_sym]&.key?(source)
      score += 40
    end
    
    # Content indicator score
    indicators = @categories[:categories][category.to_sym][:content_indicators]
    if indicators
      indicator_matches = indicators.count { |indicator| content.downcase.include?(indicator.downcase) }
      score += (indicator_matches.to_f / indicators.length) * 30
    end
    
    # Content quality score
    if content.length > 200
      score += 20
    elsif content.length > 50
      score += 10
    end
    
    # Format validation score
    if has_valid_format?(content, source, category)
      score += 10
    end
    
    score
  end

  def has_valid_format?(content, source, category)
    case category
    when 'knowledge_base'
      # Check for documentation-like content
      content.include?('guide') || content.include?('documentation') || content.include?('help')
    when 'backlog'
      # Check for request-like content
      content.include?('request') || content.include?('bug') || content.include?('feature')
    when 'platform'
      # Check for implementation-like content
      content.include?('implementation') || content.include?('code') || content.include?('config')
    else
      true
    end
  end

  def extract_title(content)
    # Simple title extraction from first line or first sentence
    lines = content.lines.map(&:strip).reject(&:empty?)
    return lines.first if lines.any?
    
    # Fallback to first sentence
    sentences = content.split(/[.!?]/)
    sentences.first&.strip || 'Untitled'
  end

  def detect_language(content)
    # Simple language detection based on common words
    english_words = %w[the and or but in on at to for of with by]
    spanish_words = %w[el la los las y o pero en a para de con por]
    french_words = %w[le la les et ou mais dans à pour de avec par]
    
    content_lower = content.downcase
    words = content_lower.split(/\W+/)
    
    english_count = words.count { |word| english_words.include?(word) }
    spanish_count = words.count { |word| spanish_words.include?(word) }
    french_count = words.count { |word| french_words.include?(word) }
    
    if english_count > spanish_count && english_count > french_count
      'en'
    elsif spanish_count > french_count
      'es'
    elsif french_count > 0
      'fr'
    else
      'en' # Default to English
    end
  end

  def extract_knowledge_base_metadata(content, source)
    metadata = {}
    
    # Extract version information
    if content.match(/version\s*[:=]\s*([\d.]+)/i)
      metadata[:version] = $1
    end
    
    # Extract author information
    if content.match(/author\s*[:=]\s*(.+)/i)
      metadata[:author] = $1.strip
    end
    
    # Extract tags
    tags = content.scan(/#(\w+)/).flatten
    metadata[:tags] = tags if tags.any?
    
    # Extract URL if present
    urls = content.scan(/https?:\/\/[^\s]+/)
    metadata[:url] = urls.first if urls.any?
    
    metadata
  end

  def extract_backlog_metadata(content, source)
    metadata = {}
    
    # Extract priority
    if content.match(/priority\s*[:=]\s*(high|medium|low)/i)
      metadata[:priority] = $1.downcase
    end
    
    # Extract status
    if content.match(/status\s*[:=]\s*(to\s*do|in\s*progress|done|blocked)/i)
      metadata[:status] = $1.downcase
    end
    
    # Extract assignee
    if content.match(/assignee\s*[:=]\s*(.+)/i)
      metadata[:assignee] = $1.strip
    end
    
    # Extract story points
    if content.match(/story\s*points?\s*[:=]\s*(\d+)/i)
      metadata[:story_points] = $1.to_i
    end
    
    # Extract labels
    labels = content.scan(/label\s*[:=]\s*([^,\n]+)/i).flatten.map(&:strip)
    metadata[:labels] = labels if labels.any?
    
    metadata
  end

  def extract_platform_metadata(content, source)
    metadata = {}
    
    # Extract file path
    if content.match(/file\s*[:=]\s*(.+)/i)
      metadata[:file_path] = $1.strip
    end
    
    # Extract commit hash
    if content.match(/commit\s*[:=]\s*([a-f0-9]{7,})/i)
      metadata[:commit_hash] = $1
    end
    
    # Extract branch
    if content.match(/branch\s*[:=]\s*(\w+)/i)
      metadata[:branch] = $1
    end
    
    # Extract file type
    if content.match(/\.(\w+)$/)
      metadata[:file_type] = $1
    end
    
    # Extract size
    metadata[:size] = content.length
    
    metadata
  end
end
