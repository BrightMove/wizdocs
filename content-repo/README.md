# Content Repository

This directory contains the Wiseguy knowledge base taxonomy system implementation.

## Quick Start

```bash
# Initialize the taxonomy system
ruby init_taxonomy.rb

# Use the knowledge base manager
ruby knowledge_base_manager.rb
```

## Documentation

📚 **Complete documentation is available in the [docs/](./docs/) directory:**

- [📋 Implementation Summary](./docs/TAXONOMY_IMPLEMENTATION_SUMMARY.md)
- [📖 Technical Guide](./docs/TAXONOMY_README.md)
- [📚 Documentation Index](./docs/README.md)

## Directory Structure

```
content-repo/
├── docs/                           # 📚 Documentation
├── organizations/                  # Organization-based content repositories
│   └── org_0/                     # Organization 0 (BrightMove)
├── taxonomy_config.yml            # Taxonomy configuration
├── taxonomy_manager.rb            # Taxonomy management class
├── sync_connector_manager.rb      # Sync connector management
├── wiseguy_content_manager.rb     # Wiseguy content management
├── knowledge_base_manager.rb      # Main knowledge base manager
└── init_taxonomy.rb               # Initialization script
```

## Key Files

- **`init_taxonomy.rb`**: Initialize the taxonomy system
- **`knowledge_base_manager.rb`**: Main coordinator class
- **`taxonomy_config.yml`**: Configuration and connector definitions
- **`organizations/`**: Organization-based content repositories

## Usage

```ruby
require_relative 'knowledge_base_manager'

# Initialize
kb_manager = KnowledgeBaseManager.new

# Create organization
kb_manager.create_organization('12345', 'Acme Corp', 'Client organization')

# Sync content
kb_manager.sync_organization('0')

# Search content
results = kb_manager.search_organization('0', 'API integration')
```

For detailed documentation, examples, and technical information, see the [docs/](./docs/) directory.
