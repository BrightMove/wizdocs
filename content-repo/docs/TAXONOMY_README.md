# Knowledge Base Taxonomy

This document describes the new taxonomy-based organization structure for the Wiseguy knowledge base system.

## Overview

The knowledge base has been reorganized to support multiple organizations with a hierarchical taxonomy structure. Each organization can have multiple content sources with different types, visibility levels, and sync strategies.

## Directory Structure

```
content-repo/
├── organizations/                    # Organization-based content repositories
│   ├── org_0/                       # Organization 0 (BrightMove)
│   │   ├── organization.json        # Organization metadata
│   │   ├── content_sources/         # Content source directories
│   │   │   ├── general/            # General content sources
│   │   │   │   ├── public/         # Public content
│   │   │   │   │   ├── static/     # Static content sources
│   │   │   │   │   └── dynamic/    # Dynamic content sources
│   │   │   │   └── private/        # Private content
│   │   │   │       ├── static/     # Static content sources
│   │   │   │       └── dynamic/    # Dynamic content sources
│   │   │   └── specific/           # Specific content sources with connectors
│   │   │       ├── public/         # Public content
│   │   │       │   └── dynamic/    # Dynamic content sources
│   │   │       │       ├── intercom_tickets/
│   │   │       │       ├── intercom_help_center/
│   │   │       │       ├── confluence/
│   │   │       │       ├── jira/
│   │   │       │       └── github/
│   │   │       └── private/        # Private content
│   │   │           └── dynamic/    # Dynamic content sources
│   │   │               ├── intercom_tickets/
│   │   │               ├── intercom_help_center/
│   │   │               ├── confluence/
│   │   │               ├── jira/
│   │   │               └── github/
│   │   ├── wiseguy_metadata/       # Wiseguy system metadata
│   │   ├── wiseguy_hints/          # Wiseguy hints and guidance
│   │   └── wiseguy_prompts/        # Wiseguy prompt templates
│   └── org_{cro_org_id}/           # Other organizations by CRO ID
├── taxonomy_config.yml             # Taxonomy configuration
├── taxonomy_manager.rb             # Taxonomy management class
├── sync_connector_manager.rb       # Sync connector management
├── wiseguy_content_manager.rb      # Wiseguy content management
├── knowledge_base_manager.rb       # Main knowledge base manager
└── TAXONOMY_README.md              # This file
```

## Organization Structure

### Organization Identification
- **Organization 0**: Primary organization (BrightMove)
- **Other Organizations**: Identified by their CRO organization ID (e.g., `org_12345`)

### Organization Metadata
Each organization has an `organization.json` file containing:
```json
{
  "organization_id": "0",
  "name": "BrightMove",
  "description": "Primary organization for BrightMove content",
  "created_at": "2024-01-01T00:00:00Z",
  "content_sources": [],
  "wiseguy_content": []
}
```

## Content Source Types

### 1. General Content Sources
Content sources without specific connectors:
- **Documents**: Static files and documentation
- **Website Content**: Scraped web content
- **Presentations**: Slide decks and presentations
- **Research**: Research materials and reports

### 2. Specific Content Sources
Content sources with dedicated sync connectors:
- **Intercom Tickets**: Customer support conversations
- **Intercom Help Center**: Help articles and documentation
- **Confluence**: Wiki pages and documentation
- **JIRA**: Project management tickets and issues
- **GitHub**: Repository code and documentation

## Content Source Properties

### Visibility Levels
- **Public**: Content accessible to all organizations
- **Private**: Content accessible only to the owning organization

### Sync Strategies
- **Static**: Content synced once and not updated automatically
- **Dynamic**: Content synced periodically and updated automatically

### Content Source Metadata
Each content source has a `source_metadata.json` file:
```json
{
  "name": "intercom_tickets",
  "type": "specific",
  "visibility": "private",
  "sync_strategy": "dynamic",
  "connector": "intercom_tickets_connector",
  "created_at": "2024-01-01T00:00:00Z",
  "last_sync": "2024-01-01T12:00:00Z",
  "sync_status": "completed",
  "content_count": 150
}
```

## Wiseguy Content Types

### 1. Wiseguy Metadata
System metadata and configuration data:
- **Storage Format**: JSON
- **Update Frequency**: Real-time
- **Examples**: System configuration, sync status, operational data

### 2. Wiseguy Hints
Contextual hints and guidance for AI analysis:
- **Storage Format**: JSON with markdown content
- **Update Frequency**: Real-time
- **Categories**: development, process, quality, etc.
- **Priorities**: high, medium, low

### 3. Wiseguy Prompts
Prompt templates and AI instruction sets:
- **Storage Format**: JSON with template variables
- **Update Frequency**: Real-time
- **Features**: Variable substitution, usage tracking, descriptions

## Sync Connectors

### Connector Configuration
Connectors are configured in `taxonomy_config.yml`:
```yaml
connectors:
  intercom_tickets_connector:
    api_endpoint: "https://api.intercom.io"
    content_type: "conversations"
    metadata_fields: ["id", "created_at", "updated_at", "user_id", "conversation_parts"]
```

### Connector Features
- **Metadata Retention**: Preserves source-specific metadata
- **Error Handling**: Comprehensive error handling and retry logic
- **Rate Limiting**: Respects API rate limits
- **Status Tracking**: Tracks sync status and content counts

## Management Classes

### 1. TaxonomyManager
Manages the organizational structure:
- Create organizations
- Add content sources
- Validate taxonomy structure
- Generate reports

### 2. SyncConnectorManager
Manages content synchronization:
- Sync content from external sources
- Handle different connector types
- Maintain metadata indexes
- Search across content sources

### 3. WiseguyContentManager
Manages Wiseguy-specific content:
- Metadata management
- Hints and guidance
- Prompt templates
- Content search and statistics

### 4. KnowledgeBaseManager
Main coordinator class:
- Initialize knowledge base
- Coordinate between managers
- System-wide operations
- Maintenance tasks

## Usage Examples

### Initialize Knowledge Base
```ruby
require_relative 'knowledge_base_manager'

kb_manager = KnowledgeBaseManager.new
kb_manager.initialize_knowledge_base
```

### Create New Organization
```ruby
kb_manager.create_organization('12345', 'Acme Corp', 'Client organization')
```

### Sync Organization Content
```ruby
kb_manager.sync_organization('0')
```

### Search Content
```ruby
results = kb_manager.search_organization('0', 'API integration')
```

### Add Wiseguy Content
```ruby
# Add metadata
kb_manager.wiseguy_content_manager.add_metadata('0', 'system_config', {
  'ai_model' => 'gpt-4',
  'max_tokens' => 4000
})

# Add hint
kb_manager.wiseguy_content_manager.add_hint('0', 'API Best Practices', 
  'Always include proper error handling in API integrations.',
  'development', 'high')

# Add prompt
kb_manager.wiseguy_content_manager.add_prompt('0', 'Content Analysis',
  'Analyze the following content for accuracy:\n\n{{content}}',
  ['content'], 'Standard content analysis prompt')
```

### Generate Reports
```ruby
# Organization report
org_report = kb_manager.get_organization_report('0')

# System-wide report
system_report = kb_manager.get_system_report

# Validation report
errors = kb_manager.validate_knowledge_base
```

## Migration from Old Structure

The new taxonomy structure replaces the previous flat content organization. To migrate existing content:

1. **Run the initialization script**:
   ```bash
   cd content-repo
   ruby knowledge_base_manager.rb
   ```

2. **Migrate existing content** (if needed):
   - Move existing content to appropriate organization directories
   - Update content source configurations
   - Add Wiseguy content as needed

3. **Validate the migration**:
   ```ruby
   kb_manager = KnowledgeBaseManager.new
   errors = kb_manager.validate_knowledge_base
   ```

## Configuration

### Taxonomy Configuration
Edit `taxonomy_config.yml` to:
- Add new connector types
- Modify sync frequencies
- Update metadata fields
- Configure organization templates

### Environment Variables
Set environment variables for API access:
```bash
export INTERCOM_ACCESS_TOKEN="your_token"
export JIRA_API_TOKEN="your_token"
export GITHUB_TOKEN="your_token"
```

## Maintenance

### Regular Maintenance
Run maintenance tasks to keep the knowledge base healthy:
```ruby
kb_manager.run_maintenance
```

### Validation
Regularly validate the knowledge base structure:
```ruby
errors = kb_manager.validate_knowledge_base
```

### Backup and Export
Export organization data for backup:
```ruby
kb_manager.export_organization('0', 'backup/org_0_export.json')
```

## Best Practices

1. **Organization Naming**: Use consistent naming conventions for organizations
2. **Content Source Management**: Regularly review and update content source configurations
3. **Wiseguy Content**: Keep hints and prompts up-to-date with current processes
4. **Sync Monitoring**: Monitor sync status and address failures promptly
5. **Validation**: Run validation regularly to catch structural issues
6. **Backup**: Export organization data regularly for backup purposes

## Troubleshooting

### Common Issues

1. **Missing Organization Directory**
   - Run `kb_manager.initialize_knowledge_base`
   - Check file permissions

2. **Sync Failures**
   - Verify API credentials
   - Check network connectivity
   - Review connector configurations

3. **Validation Errors**
   - Run `kb_manager.validate_knowledge_base`
   - Fix structural issues
   - Update missing metadata

4. **Content Not Found**
   - Verify content source paths
   - Check sync status
   - Review search parameters

### Debug Mode
Enable debug logging for troubleshooting:
```ruby
ENV['DEBUG'] = 'true'
kb_manager = KnowledgeBaseManager.new
```

## Future Enhancements

1. **Vector Search**: Integrate vector embeddings for semantic search
2. **Content Versioning**: Add version control for content changes
3. **Access Control**: Implement fine-grained access control
4. **Analytics**: Add usage analytics and reporting
5. **API Integration**: Provide REST API for external access
6. **Web Interface**: Develop web-based management interface
