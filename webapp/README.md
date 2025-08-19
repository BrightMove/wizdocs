# Wiseguy - Agentic AI Platform for BrightMove

A modern web application built with Ruby/Sinatra that provides comprehensive audit tools and sales automation for BrightMove product management.

## Overview

Wiseguy is an agentic AI platform designed to support BrightMove product management through two main areas:

### 📊 Audits & Analysis
- **Development Tickets**: Analyze JIRA development tickets and Intercom customer support tickets for consistency and accuracy
- **Content Analysis**: Analyze Intercom Help Center (LightHub) and Confluence content for consistency and accuracy
- **Veracity Audits**: Manage veracity audits, upload input files, and track analysis results
- **GitHub Impact**: Monitor pull request impact on knowledge base and automatically detect conflicts between code changes and documentation

### 💼 Sales Tools
- **RFP Machine**: Automated RFP response generation with AI-powered requirement analysis and gap identification
- **SOW Machine**: Generate comprehensive Statements of Work with automated scope definition and deliverable tracking

The platform provides sync services to connect to Atlassian Jira, Atlassian Confluence, Intercom, and Github to support comprehensive analysis and automation.

## Features

### 📊 Audits & Analysis
- **Development Tickets**: Analyze JIRA development tickets and Intercom customer support tickets for consistency and accuracy
- **Comprehensive Ticket View**: View all tickets across all JIRA projects with advanced search and filtering capabilities
- **Content Analysis**: Analyze Intercom Help Center (LightHub) and Confluence content for consistency and accuracy
- **Veracity Audits**: Manage veracity audits, upload input files, and track analysis results
- **GitHub Impact**: Monitor pull request impact on knowledge base and automatically detect conflicts between code changes and documentation

### 💼 Sales Tools
- **RFP Machine**: Automated RFP response generation with AI-powered requirement analysis and gap identification
- **SOW Machine**: Generate comprehensive Statements of Work with automated scope definition and deliverable tracking
- **Project Management**: Create, organize, and manage RFP and SOW projects
- **Script Execution**: Run AI-powered analysis scripts directly from the web interface

### 🔄 Sync Services
- **JIRA Integration**: Comprehensive ticket and project synchronization
- **Confluence Integration**: Wiki content and space management
- **Intercom Integration**: Conversation and customer data analysis
- **Github Integration**: Repository and code analysis with webhook support
- **Local Caching**: File-based caching for performance and offline analysis

### ⚙️ API Connections
- JIRA Cloud integration with API token authentication
- Confluence integration for wiki content analysis
- Intercom integration for conversation analysis
- Real-time connection status monitoring
- Secure credential management

## Setup Instructions

### 1. Install Dependencies

First, install the required Ruby gems:

```bash
cd webapp
bundle install
```

If you don't have Bundler installed:
```bash
gem install bundler
bundle install
```

### 2. Configure API Credentials

Copy the example configuration file:
```bash
cp config.env.example config.env
```

Edit `config.env` with your API credentials:

```bash
# JIRA Configuration (used for both JIRA and Confluence)
JIRA_SITE=https://your-domain.atlassian.net
JIRA_USERNAME=your-email@domain.com
JIRA_API_TOKEN=your-jira-api-token

# Intercom Configuration
INTERCOM_ACCESS_TOKEN=your-intercom-access-token
INTERCOM_CLIENT_ID=your-intercom-client-id
INTERCOM_CLIENT_SECRET=your-intercom-client-secret

# Application Configuration
PORT=3000
ENVIRONMENT=development
```

### 3. Get API Credentials

#### JIRA & Confluence Setup
1. Go to your Atlassian account settings: https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Give it a name (e.g., "Wiseguy Admin UI")
4. Copy the generated token
5. Use your JIRA email address as the username
6. The same credentials work for both JIRA and Confluence APIs

#### Intercom Setup
1. Go to your Intercom developer settings: https://developers.intercom.com/
2. Create a new app or use existing one
3. Generate an access token
4. Copy the token to your config file

### 4. Start the Application

```bash
ruby app.rb
```

The application will start at `http://localhost:3000`

## Usage

### Dashboard
- View quick statistics about your tickets and content
- Navigate between different sections
- Monitor API connection status
- Access comprehensive ticket and content analysis tools

### Comprehensive Ticket Management
- **All Tickets**: View all tickets across all JIRA projects
- **Advanced Search**: Search and filter capabilities
- **Cross-Project Statistics**: Analytics across all projects
- **Local Caching**: Performance-optimized with local storage

### Content Analysis
- **Confluence Sync**: Sync all wiki content from all spaces
- **Duplication Analysis**: Find similar content across platforms
- **Accuracy Issues**: Identify outdated or broken references
- **Orphaned Content**: Find content with no related tickets

### Veracity Audits
The Admin UI supports the Wiseguy veracity audit process:
- **Input Directory**: Contains contextually relevant documents for audit analysis
- **Output Directory**: Where audit output documents are written
- **Cross-Platform Analysis**: Comprehensive analysis across JIRA, Confluence, and Intercom
- **AI-Powered Insights**: Smart recommendations for content management

### Settings
- Configure JIRA, Confluence, and Intercom API credentials
- Test API connections
- Set application preferences
- Monitor connection status

## API Endpoints

### Ticket Management
- `GET /api/tickets/sync` - Sync all tickets from all projects
- `GET /api/tickets/all` - Get all cached tickets
- `GET /api/tickets/search` - Search tickets
- `GET /api/tickets/statistics` - Get ticket statistics
- `GET /api/tickets/sync-status` - Check sync status

### Confluence Integration
- `GET /api/confluence/sync` - Sync all Confluence content
- `GET /api/confluence/content` - Get cached Confluence content
- `GET /api/confluence/spaces` - Get all Confluence spaces
- `GET /api/confluence/search` - Search Confluence content

### Content Analysis
- `GET /api/content/analyze` - Run comprehensive content analysis
- `GET /api/content/analysis` - Get analysis results
- `GET /api/content/duplications` - Get duplication analysis
- `GET /api/content/accuracy-issues` - Get accuracy issues
- `GET /api/content/orphaned` - Get orphaned content

### Project Management
- `GET /api/projects` - Get all JIRA projects
- `POST /api/projects/create` - Create new project
- `POST /api/projects/delete` - Delete project

## Analysis Logic

### Cross-Platform Duplication Detection
- Analyzes content similarity between JIRA tickets and Confluence pages
- Uses keyword-based similarity calculation
- Identifies potential duplications across platforms
- Prioritized as "High" priority for cleanup

### Content Accuracy Analysis
- Checks for outdated content and broken JIRA references
- Identifies content that references non-existent tickets
- Analyzes content age and update patterns
- Prioritized as "Medium" priority

### Orphaned Content Detection
- Finds Confluence content with no related JIRA tickets
- Identifies standalone documentation
- Helps identify content that needs ticket creation
- Prioritized as "Low" priority

### JIRA Ticket Analysis
- Finds tickets that haven't been updated in 6+ months
- Excludes tickets with status "Closed" or "Done"
- Identifies potential duplicates within JIRA
- Provides comprehensive cross-project analysis

## Directory Structure

The Admin UI works with the Wizdocs audit structure:

```
wizdocs/
├── webapp/           # This application
├── audits/            # Veracity audit directories
│   ├── engage/        # Example audit
│   │   ├── input/     # Contextually relevant documents
│   │   └── output/    # Audit output documents
│   └── [other-audits]/
├── apps/              # Application codebases
└── venv/              # Shared Python virtual environment
```

## Troubleshooting

### Common Issues

1. **JIRA/Confluence Connection Failed**
   - Verify your JIRA site URL is correct
   - Check that your API token is valid
   - Ensure your email address matches your Atlassian account

2. **Intercom Connection Failed**
   - Verify your access token is correct
   - Check that your app has the necessary permissions
   - Ensure the token hasn't expired

3. **Gems Not Found**
   - Run `bundle install` to install dependencies
   - Make sure you're using the correct Ruby version

4. **Port Already in Use**
   - Change the PORT in config.env
   - Or kill the process using the current port

5. **Cache Issues**
   - Clear the cache directory: `rm -rf cache/*`
   - Restart the application
   - Re-sync your data

### Debug Mode

To run in debug mode with more detailed logging:

```bash
ENVIRONMENT=development ruby app.rb
```

## Security Notes

- Never commit your `config.env` file to version control
- Use environment variables for production deployments
- Regularly rotate your API tokens
- Monitor API usage to stay within rate limits
- Cache files contain sensitive data - secure appropriately

## Development

### Adding New Features

1. **New API Integration**: Add a new service class following the pattern of `JiraService` or `ConfluenceService`
2. **New Analysis Logic**: Extend the `ContentAnalysisService` class
3. **New UI Pages**: Create new ERB templates and add routes to `AdminUI`
4. **New Sync Services**: Extend the `TicketCacheService` for new platforms

### Testing

The application includes basic error handling and connection testing. For production use, consider adding:

- Unit tests for service classes
- Integration tests for API endpoints
- UI automation tests
- Cache validation tests

## License

This project is part of the Wizdocs workspace and follows the same licensing terms.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify your API credentials are correct
3. Check the application logs for error messages
4. Ensure all dependencies are properly installed
5. Review the cache directory for data integrity 