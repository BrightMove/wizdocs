# Content Repository Documentation

This directory contains comprehensive documentation for the Wiseguy knowledge base taxonomy system.

## Documentation Index

### 📋 [Taxonomy Implementation Summary](./TAXONOMY_IMPLEMENTATION_SUMMARY.md)
Complete overview of the taxonomy implementation, including:
- What was implemented
- Directory structure
- Management classes
- Content source types
- Implementation status
- Usage examples
- Configuration details
- Next steps

### 📖 [Taxonomy README](./TAXONOMY_README.md)
Detailed technical documentation covering:
- Overview and architecture
- Directory structure
- Organization structure
- Content source types and properties
- Wiseguy content types
- Sync connectors
- Management classes
- Usage examples
- Configuration
- Maintenance
- Troubleshooting
- Future enhancements

### 📚 [Documentation Organization](./DOCUMENTATION_ORGANIZATION.md)
Guide to how documentation is organized in this project:
- Documentation structure and principles
- File organization and purpose
- Documentation update guidelines
- Benefits of this organization

## Quick Reference

### Directory Structure
```
content-repo/
├── docs/                           # Documentation (this directory)
│   ├── README.md                   # This file
│   ├── TAXONOMY_README.md         # Comprehensive technical guide
│   └── TAXONOMY_IMPLEMENTATION_SUMMARY.md # Implementation overview
├── organizations/                  # Organization-based content repositories
│   └── org_0/                     # Organization 0 (BrightMove)
├── taxonomy_config.yml            # Taxonomy configuration
├── taxonomy_manager.rb            # Taxonomy management class
├── sync_connector_manager.rb      # Sync connector management
├── wiseguy_content_manager.rb     # Wiseguy content management
├── knowledge_base_manager.rb      # Main knowledge base manager
└── init_taxonomy.rb               # Initialization script
```

### Key Components

#### Management Classes
- **TaxonomyManager**: Organizational structure and content sources
- **SyncConnectorManager**: Content synchronization with metadata retention
- **WiseguyContentManager**: Wiseguy-specific content management
- **KnowledgeBaseManager**: Main coordinator for system-wide operations

#### Content Source Types
- **General**: Documents, website content, presentations, research
- **Specific**: Intercom, Confluence, JIRA, GitHub (with connectors)

#### Wiseguy Content Types
- **Metadata**: System configuration and operational data
- **Hints**: Contextual guidance with categories and priorities
- **Prompts**: Template-based AI instructions with variables

### Quick Start

1. **Initialize the taxonomy**:
   ```bash
   cd content-repo
   ruby init_taxonomy.rb
   ```

2. **Use the knowledge base manager**:
   ```ruby
   require_relative 'knowledge_base_manager'
   kb_manager = KnowledgeBaseManager.new
   ```

3. **Create a new organization**:
   ```ruby
   kb_manager.create_organization('12345', 'Acme Corp', 'Client organization')
   ```

4. **Sync organization content**:
   ```ruby
   kb_manager.sync_organization('0')
   ```

## Documentation Updates

When making changes to the taxonomy system:
1. Update the relevant documentation files
2. Update this README if new documentation is added
3. Ensure examples and usage patterns are current
4. Update configuration examples if needed

## Support

For questions about the taxonomy system:
1. Check the [Taxonomy README](./TAXONOMY_README.md) for detailed technical information
2. Review the [Implementation Summary](./TAXONOMY_IMPLEMENTATION_SUMMARY.md) for overview
3. Examine the code examples in the management classes
4. Run the initialization script to see the system in action
