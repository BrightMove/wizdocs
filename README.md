# Wizdocs - Veracity Audit System

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Admin UI](#admin-ui)
- [Usage](#usage)
- [Veracity Audits](#veracity-audits)
- [Content Analysis](#content-analysis)
- [Ticket Analysis](#ticket-analysis)
- [Directory Structure](#directory-structure)
- [Setup](#setup)

## Overview

Wizdocs is a comprehensive veracity audit system designed to ensure consistency between source code, documentation, and project management information across the BrightMove technical ecosystem. The system uses AI to analyze and summarize technical documentation while keeping all content in sync with actual source code.

The platform helps ensure that customer support tickets, project management tickets, knowledge base content, and application functionality are synchronized and accurate.

## Architecture

The Wizdocs system consists of several key components:

- **Admin UI**: A Ruby Sinatra web application for managing audits and analyzing content
- **Sync Services**: Integration with Atlassian Jira, Confluence, Intercom, and GitHub
- **Content Analysis**: AI-powered analysis of documentation and ticket consistency
- **Veracity Audits**: Structured audit processes for specific features or areas
- **Local Caching**: File-based caching system for performance and offline access

## Admin UI

The Admin UI is a Ruby Sinatra application located in the `admin-ui/` subdirectory. It provides a comprehensive web interface for:

### Core Features
- **Dashboard**: Overview of all system components and quick statistics
- **Veracity Audits**: Create, manage, and execute audit processes
- **Ticket Analysis**: Analyze JIRA and Intercom tickets for consistency
- **Content Analysis**: Analyze Confluence and documentation for accuracy
- **Comprehensive Ticket View**: View all tickets across all projects with advanced filtering
- **API Management**: Configure and monitor external service connections

### Sync Services
- **JIRA Integration**: Sync tickets, projects, and issue data
- **Confluence Integration**: Sync wiki content and documentation
- **Intercom Integration**: Sync customer support conversations
- **Local Caching**: Store synced data locally for offline analysis

### Analysis Capabilities
- **Duplicate Detection**: Find similar tickets and content
- **Accuracy Analysis**: Identify outdated or inconsistent information
- **Orphaned Content**: Find content without related tickets
- **Resource Allocation**: Analyze ticket distribution and priorities

## Usage

### Starting the Admin UI

```bash
cd admin-ui
PORT=3000 ruby app.rb
```

The application will be available at `http://localhost:3000`

### Configuration

Create a `config.env` file in the `admin-ui/` directory with your API credentials:

```env
JIRA_SITE=https://your-domain.atlassian.net
JIRA_USERNAME=your-email@domain.com
JIRA_API_TOKEN=your-api-token
INTERCOM_ACCESS_TOKEN=your-intercom-token
```

## Veracity Audits

Veracity audits are structured analysis processes that examine specific areas or features within the technical stack. Each audit focuses on confirming consistency between:

- Source code implementation
- Feature documentation
- Project management information
- Customer support interactions

### Audit Structure

Each audit is organized in the `audits/` directory with the following structure:

```
audits/
├── audit-name/
│   ├── input/          # Context documents and instructions
│   └── output/         # Audit results and analysis
```

### Input Directory
- **Context Documents**: PDFs, markdown files, and other relevant materials
- **Instructions**: MD files with specific analysis requirements
- **Reference Materials**: Any additional context needed for the audit

### Output Directory
- **Analysis Reports**: Markdown, HTML, or PDF format
- **Process Documentation**: Methodology and decision rationale
- **Appendix**: Gaps, assumptions, and limitations identified

### Audit Process
1. **Create Audit**: Use the Admin UI to create a new audit
2. **Upload Input**: Add relevant documents to the input directory
3. **Execute Analysis**: Run the audit process through the Admin UI
4. **Review Output**: Examine results and process documentation
5. **Iterate**: Refine analysis based on findings

## Content Analysis

The system analyzes two major content classifications:

### Customer-Facing Content
- **Location**: Intercom Help Center (The LightHub)
- **Purpose**: Official customer documentation
- **Analysis**: Accuracy and consistency with implementation

### Internal Content
- **Location**: Atlassian Confluence
- **Purpose**: Internal documentation and knowledge base
- **Analysis**: Completeness and alignment with project management

## Ticket Analysis

The system analyzes two major ticket classifications:

### Development Tickets
- **Location**: Atlassian JIRA
- **Content**: Epics, features, improvements, and bug fixes
- **Analysis**: Implementation status and documentation alignment

### Customer Support Tickets
- **Location**: Intercom
- **Content**: Customer interactions and support history
- **Analysis**: Issue patterns and documentation gaps

## Directory Structure

```
wizdocs/
├── admin-ui/           # Main web application
│   ├── app.rb         # Sinatra application
│   ├── views/         # ERB templates
│   ├── cache/         # Local data cache
│   └── config.env     # API configuration
├── audits/            # Veracity audit projects
│   ├── audit-name/
│   │   ├── input/     # Audit input materials
│   │   └── output/    # Audit results
│   └── ...
├── apps/              # Application codebases
│   ├── airflow-dags/
│   ├── bright-sync/
│   ├── brightmove-ats/
│   └── ...
└── README.md          # This file
```

## Setup

### Prerequisites
- Ruby 2.6 or higher
- Bundler gem
- Access to JIRA, Confluence, and Intercom APIs

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd wizdocs
   ```

2. **Install Ruby dependencies**:
   ```bash
   cd admin-ui
   bundle install
   ```

3. **Configure API credentials**:
   ```bash
   cp config.env.example config.env
   # Edit config.env with your API credentials
   ```

4. **Start the application**:
   ```bash
   PORT=3000 ruby app.rb
   ```

### API Configuration

The Admin UI requires API tokens for:
- **JIRA**: For ticket and project data
- **Confluence**: For wiki content analysis
- **Intercom**: For customer support data

Configure these in `admin-ui/config.env` following the example format.

### First Run

1. Start the Admin UI application
2. Navigate to `http://localhost:3000`
3. Configure your API credentials in Settings
4. Sync your data using the dashboard options
5. Create your first veracity audit

## Contributing

When contributing to veracity audits:

1. **Create New Audits**: Use the Admin UI to create structured audits
2. **Document Process**: Always include methodology in output
3. **Identify Gaps**: Note assumptions and limitations
4. **Maintain Consistency**: Use standard output formats
5. **Version Control**: Keep audit outputs in the repository

## Support

For issues with the Admin UI or audit processes, check the application logs and ensure all API credentials are properly configured.