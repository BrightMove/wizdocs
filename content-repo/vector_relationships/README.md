# Vector Relationships System

## Overview
This system maintains vector embeddings for content pieces across three categories to enable efficient impact analysis and relationship mapping.

## Content Categories

### 1. Knowledge Base Content ("What the application says it does")
- **Sources**: LightHub help center, Confluence articles
- **Purpose**: Official documentation, user guides, feature descriptions
- **Vector Type**: `knowledge_base`

### 2. Backlog Content ("What the application should do")
- **Sources**: Jira tickets, Intercom service desk tickets
- **Purpose**: Feature requests, bug reports, enhancement ideas
- **Vector Type**: `backlog`

### 3. Platform Content ("What the application actually does")
- **Sources**: GitHub repositories, infrastructure scans
- **Purpose**: Actual implementation, code, configuration, deployment
- **Vector Type**: `platform`

## Vector Relationship Types

### Direct Relationships
- **Implements**: Backlog → Platform (feature request → implementation)
- **Documents**: Platform → Knowledge Base (implementation → documentation)
- **Requires**: Knowledge Base → Backlog (documentation gap → feature request)

### Impact Analysis
- **Affects**: Changes in one category impact others
- **Depends**: Dependencies between content pieces
- **Conflicts**: Contradictions between categories

## File Structure
```
vector_relationships/
├── README.md                    # This file
├── vector_manager.rb           # Main vector management class
├── content_categorizer.rb      # Content categorization logic
├── relationship_analyzer.rb    # Impact analysis engine
├── embeddings/                 # Stored vector embeddings
│   ├── knowledge_base/
│   ├── backlog/
│   └── platform/
├── relationships/              # Relationship mappings
│   ├── direct_relationships.json
│   ├── impact_analysis.json
│   └── conflict_detection.json
└── config/                     # Configuration files
    ├── sources.yml             # Source system configurations
    └── categories.yml          # Category definitions
```

## Usage

### Adding Content
```ruby
vector_manager = VectorRelationshipManager.new
vector_manager.add_content(
  content: "SSO integration guide",
  source: "confluence",
  category: "knowledge_base",
  metadata: { url: "https://confluence.example.com/SSO" }
)
```

### Analyzing Relationships
```ruby
relationships = vector_manager.analyze_relationships(
  content_id: "sso_guide_001",
  relationship_type: "implements"
)
```

### Impact Analysis
```ruby
impacts = vector_manager.analyze_impact(
  change_description: "Update SSO configuration",
  categories: ["platform", "knowledge_base"]
)
```

## Configuration

### Sources Configuration (sources.yml)
```yaml
knowledge_base:
  lighthub:
    base_url: "https://help.lighthub.com"
    api_token: "${LIGHTHUB_API_TOKEN}"
  confluence:
    base_url: "https://company.atlassian.net/wiki"
    username: "${CONFLUENCE_USERNAME}"
    api_token: "${CONFLUENCE_API_TOKEN}"

backlog:
  jira:
    base_url: "https://company.atlassian.net"
    username: "${JIRA_USERNAME}"
    api_token: "${JIRA_API_TOKEN}"
  intercom:
    base_url: "https://api.intercom.io"
    access_token: "${INTERCOM_ACCESS_TOKEN}"

platform:
  github:
    base_url: "https://api.github.com"
    token: "${GITHUB_TOKEN}"
    org: "brightmove"
  infrastructure:
    scan_paths: ["/etc/", "/opt/", "/var/"]
    config_files: ["docker-compose.yml", "kubernetes/"]
```

### Categories Configuration (categories.yml)
```yaml
categories:
  knowledge_base:
    description: "What the application says it does"
    sources: ["lighthub", "confluence"]
    vector_dimensions: 1536
    update_frequency: "daily"
    
  backlog:
    description: "What the application should do"
    sources: ["jira", "intercom"]
    vector_dimensions: 1536
    update_frequency: "hourly"
    
  platform:
    description: "What the application actually does"
    sources: ["github", "infrastructure"]
    vector_dimensions: 1536
    update_frequency: "daily"

relationships:
  implements:
    from: "backlog"
    to: "platform"
    strength_threshold: 0.8
    
  documents:
    from: "platform"
    to: "knowledge_base"
    strength_threshold: 0.7
    
  requires:
    from: "knowledge_base"
    to: "backlog"
    strength_threshold: 0.6
```

## API Endpoints

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

## Monitoring and Maintenance

### Health Checks
- Vector embedding freshness
- Relationship accuracy
- Source system connectivity
- Performance metrics

### Automated Tasks
- Daily embedding updates
- Weekly relationship validation
- Monthly impact analysis reports
- Quarterly accuracy assessments
