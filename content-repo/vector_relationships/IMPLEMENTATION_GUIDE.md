# Vector Relationship System - Implementation Guide

## 🎯 Overview

The Vector Relationship System maintains vector embeddings for content pieces across three distinct categories to enable efficient impact analysis and relationship mapping. This system helps identify how changes in one area affect other parts of the application ecosystem.

## 📋 Content Categories

### 1. Knowledge Base Content ("What the application says it does")
- **Sources**: LightHub help center, Confluence articles
- **Purpose**: Official documentation, user guides, feature descriptions
- **Examples**: User manuals, API documentation, setup guides

### 2. Backlog Content ("What the application should do")
- **Sources**: Jira tickets, Intercom service desk tickets
- **Purpose**: Feature requests, bug reports, enhancement ideas
- **Examples**: User stories, bug reports, feature requests

### 3. Platform Content ("What the application actually does")
- **Sources**: GitHub repositories, infrastructure scans
- **Purpose**: Actual implementation, code, configuration, deployment
- **Examples**: Source code, configuration files, deployment manifests

## 🔗 Relationship Types

### Direct Relationships
- **Implements**: Backlog → Platform (feature request → implementation)
- **Documents**: Platform → Knowledge Base (implementation → documentation)
- **Requires**: Knowledge Base → Backlog (documentation gap → feature request)

### Impact Analysis
- **Affects**: Changes in one category impact others
- **Depends**: Dependencies between content pieces
- **Conflicts**: Contradictions between categories

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install required gems
gem install aws-sdk-bedrock redis yaml json sinatra

# Set up environment variables
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_REGION="us-east-1"
export REDIS_URL="redis://localhost:6379"  # Optional
```

### 2. Basic Usage

```ruby
require_relative 'vector_manager'

# Initialize the system
vector_manager = VectorRelationshipManager.new

# Add content
content_id = vector_manager.add_content(
  content: "SSO Integration Guide: Learn how to configure Single Sign-On...",
  source: "confluence",
  category: "knowledge_base",
  metadata: {
    title: "SSO Integration Guide",
    url: "https://confluence.example.com/SSO",
    author: "Tech Team"
  }
)

# Search for similar content
results = vector_manager.search_content(
  query: "SSO configuration",
  category: "knowledge_base",
  limit: 5
)

# Analyze relationships
relationships = vector_manager.analyze_relationships(
  content_id: content_id,
  relationship_type: "implements"
)

# Analyze impact of changes
impacts = vector_manager.analyze_impact(
  change_description: "Update SSO configuration",
  categories: ["platform", "knowledge_base"]
)
```

### 3. Integration with WizDocs

```ruby
# In your WizDocs app.rb
require_relative '../content-repo/vector_relationships/integrate_with_wizdocs'

# Initialize integration
vector_integration = WizDocsVectorIntegration.new

# Set up API routes
vector_integration.setup_routes(self)
```

## 📁 File Structure

```
vector_relationships/
├── README.md                    # System overview
├── IMPLEMENTATION_GUIDE.md      # This file
├── vector_manager.rb           # Main management class
├── content_categorizer.rb      # Content categorization logic
├── relationship_analyzer.rb    # Impact analysis engine
├── vector_embeddings.rb        # AWS Bedrock embeddings
├── integrate_with_wizdocs.rb   # WizDocs integration
├── test_vector_system.rb       # Test script
├── config/                     # Configuration files
│   ├── sources.yml            # Source system configurations
│   └── categories.yml         # Category definitions
├── embeddings/                 # Stored vector embeddings
│   ├── knowledge_base/
│   ├── backlog/
│   └── platform/
└── relationships/              # Relationship mappings
    ├── direct_relationships.json
    ├── impact_analysis.json
    └── conflict_detection.json
```

## ⚙️ Configuration

### Sources Configuration (config/sources.yml)

```yaml
knowledge_base:
  lighthub:
    base_url: "https://help.lighthub.com"
    api_token: "${LIGHTHUB_API_TOKEN}"
    content_types: ["articles", "guides", "tutorials"]
    update_frequency: "daily"
    
  confluence:
    base_url: "https://company.atlassian.net/wiki"
    username: "${CONFLUENCE_USERNAME}"
    api_token: "${CONFLUENCE_API_TOKEN}"
    spaces: ["DOCS", "TECH", "USER"]
    content_types: ["pages", "blogposts"]
    update_frequency: "daily"

backlog:
  jira:
    base_url: "https://company.atlassian.net"
    username: "${JIRA_USERNAME}"
    api_token: "${JIRA_API_TOKEN}"
    projects: ["BRIGHT", "ATS", "PLATFORM"]
    issue_types: ["Story", "Bug", "Task", "Epic"]
    statuses: ["To Do", "In Progress", "Done"]
    update_frequency: "hourly"
    
  intercom:
    base_url: "https://api.intercom.io"
    access_token: "${INTERCOM_ACCESS_TOKEN}"
    content_types: ["conversations", "articles", "tickets"]
    tags: ["feature-request", "bug-report", "enhancement"]
    update_frequency: "hourly"

platform:
  github:
    base_url: "https://api.github.com"
    token: "${GITHUB_TOKEN}"
    org: "brightmove"
    repos: ["brightmove-ats", "brightmove-sync", "webapp"]
    content_types: ["code", "readme", "docs", "issues", "pull_requests"]
    file_extensions: [".md", ".yml", ".yaml", ".json", ".rb", ".js", ".ts", ".java"]
    update_frequency: "daily"
    
  infrastructure:
    scan_paths: 
      - "/etc/brightmove/"
      - "/opt/brightmove/"
      - "/var/log/brightmove/"
      - "./docker/"
      - "./kubernetes/"
      - "./terraform/"
    config_files: 
      - "docker-compose.yml"
      - "kubernetes/deployment.yml"
      - "terraform/main.tf"
    content_types: ["config", "logs", "deployment", "infrastructure"]
    update_frequency: "daily"
```

### Categories Configuration (config/categories.yml)

```yaml
categories:
  knowledge_base:
    description: "What the application says it does"
    sources: ["lighthub", "confluence"]
    vector_dimensions: 1536
    update_frequency: "daily"
    content_indicators:
      - "user guide"
      - "documentation"
      - "help article"
      - "tutorial"
      - "how to"
      - "feature description"
    metadata_fields:
      - "title"
      - "content"
      - "url"
      - "last_updated"
      - "author"
      - "version"
      - "tags"
    
  backlog:
    description: "What the application should do"
    sources: ["jira", "intercom"]
    vector_dimensions: 1536
    update_frequency: "hourly"
    content_indicators:
      - "feature request"
      - "bug report"
      - "enhancement"
      - "user story"
      - "epic"
      - "improvement"
    metadata_fields:
      - "title"
      - "description"
      - "priority"
      - "status"
      - "assignee"
      - "created_date"
      - "labels"
      - "story_points"
    
  platform:
    description: "What the application actually does"
    sources: ["github", "infrastructure"]
    vector_dimensions: 1536
    update_frequency: "daily"
    content_indicators:
      - "implementation"
      - "code"
      - "configuration"
      - "deployment"
      - "infrastructure"
      - "actual behavior"
    metadata_fields:
      - "file_path"
      - "content"
      - "commit_hash"
      - "branch"
      - "last_modified"
      - "file_type"
      - "size"

relationships:
  implements:
    description: "Platform content implements backlog requirements"
    from_category: "backlog"
    to_category: "platform"
    strength_threshold: 0.8
    indicators:
      - "implements"
      - "addresses"
      - "solves"
      - "fulfills"
    vector_similarity_required: true
    
  documents:
    description: "Knowledge base content documents platform implementation"
    from_category: "platform"
    to_category: "knowledge_base"
    strength_threshold: 0.7
    indicators:
      - "documents"
      - "describes"
      - "explains"
      - "covers"
    vector_similarity_required: true
    
  requires:
    description: "Knowledge base content requires backlog items for gaps"
    from_category: "knowledge_base"
    to_category: "backlog"
    strength_threshold: 0.6
    indicators:
      - "requires"
      - "needs"
      - "missing"
      - "gap"
    vector_similarity_required: true
```

## 🔌 API Endpoints

### Content Management
- `POST /api/vector/content/add` - Add new content
- `PUT /api/vector/content/update` - Update existing content
- `DELETE /api/vector/content/remove` - Remove content
- `GET /api/vector/content/search` - Search content by category

### Relationship Analysis
- `POST /api/vector/relationships/analyze` - Analyze relationships
- `GET /api/vector/relationships/impact` - Get impact analysis
- `GET /api/vector/relationships/conflicts` - Detect conflicts

### Vector Operations
- `POST /api/vector/embeddings/update` - Update embeddings
- `GET /api/vector/embeddings/similar` - Find similar content
- `POST /api/vector/embeddings/batch` - Batch operations

### Example API Usage

```bash
# Add content
curl -X POST http://localhost:3000/api/vector/content/add \
  -H "Content-Type: application/json" \
  -d '{
    "content": "SSO Integration Guide: Learn how to configure...",
    "source": "confluence",
    "metadata": {
      "title": "SSO Integration Guide",
      "url": "https://confluence.example.com/SSO"
    }
  }'

# Search content
curl "http://localhost:3000/api/vector/content/search?q=SSO&category=knowledge_base&limit=5"

# Analyze impact
curl -X POST http://localhost:3000/api/vector/relationships/impact \
  -H "Content-Type: application/json" \
  -d '{
    "change_description": "Update SSO configuration",
    "categories": ["platform", "knowledge_base"]
  }'
```

## 🧪 Testing

Run the test script to verify the system:

```bash
cd content-repo/vector_relationships
ruby test_vector_system.rb
```

This will:
1. Add sample content from all three categories
2. Test categorization logic
3. Analyze relationships between content
4. Perform impact analysis
5. Detect conflicts
6. Display system statistics

## 📊 Monitoring and Health Checks

### Health Check Endpoint
```bash
curl http://localhost:3000/api/vector/health
```

### Statistics Endpoint
```bash
curl http://localhost:3000/api/vector/statistics
```

### Example Health Response
```json
{
  "storage": {
    "status": "healthy",
    "connected": true
  },
  "embeddings": {
    "status": "healthy",
    "bedrock_connected": true,
    "storage_connected": true,
    "embedding_count": 150,
    "model": "amazon.titan-embed-text-v1"
  },
  "relationships": {
    "status": "healthy",
    "storage_connected": true,
    "relationship_count": 45,
    "categories_loaded": 3,
    "embeddings_available": true
  },
  "content_count": 150,
  "last_updated": "2025-08-17T10:30:00Z"
}
```

## 🔄 Automated Tasks

### Daily Tasks
- Update embeddings for all content
- Sync content from configured sources
- Generate impact analysis reports
- Validate relationship accuracy

### Weekly Tasks
- Relationship validation and cleanup
- Conflict detection and resolution
- Performance optimization
- Backup vector embeddings

### Monthly Tasks
- Accuracy assessment and tuning
- Model performance evaluation
- Configuration review and updates
- System health audit

## 🚨 Troubleshooting

### Common Issues

1. **AWS Bedrock Connection Issues**
   - Verify AWS credentials are set correctly
   - Check AWS region configuration
   - Ensure Bedrock service is enabled in your AWS account

2. **Redis Connection Issues**
   - Verify Redis server is running
   - Check Redis URL configuration
   - System will fall back to in-memory storage if Redis is unavailable

3. **Embedding Generation Failures**
   - Check content length limits
   - Verify text preprocessing
   - Monitor AWS Bedrock API limits

4. **Relationship Analysis Issues**
   - Verify similarity thresholds
   - Check content categorization
   - Review relationship configuration

### Debug Mode

Enable debug logging:

```ruby
@logger.level = Logger::DEBUG
```

### Performance Optimization

1. **Batch Operations**: Use batch endpoints for large datasets
2. **Caching**: Enable Redis caching for better performance
3. **Parallel Processing**: Process embeddings in parallel
4. **Indexing**: Use vector similarity search for faster queries

## 🔮 Future Enhancements

### Planned Features
- Real-time content synchronization
- Advanced conflict resolution
- Machine learning-based relationship prediction
- Integration with CI/CD pipelines
- Advanced visualization tools
- Multi-language support
- Custom relationship types
- Automated impact assessment

### Performance Improvements
- Vector database integration (Pinecone, Weaviate)
- Distributed processing
- Advanced caching strategies
- Optimized embedding models

## 📞 Support

For questions or issues:
1. Check the troubleshooting section
2. Review the test script for examples
3. Examine the configuration files
4. Check system health endpoints
5. Review logs for detailed error messages

## 📄 License

This system is part of the WizDocs platform and follows the same licensing terms.
