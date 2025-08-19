# GitHub Integration - Pull Request Impact Analysis

This feature automatically monitors GitHub pull requests and analyzes their impact on the knowledge base and documentation. When a pull request is merged, the system automatically assesses what documentation needs to be updated and can create JIRA tickets for the required updates.

## Features

### 🔄 Automatic Webhook Processing
- **Real-time monitoring**: Automatically processes GitHub webhooks when pull requests are opened, updated, or merged
- **Impact assessment**: Analyzes code changes to determine their impact on documentation
- **Smart categorization**: Identifies API changes, database changes, security implications, and configuration changes

### 📊 Impact Analysis
- **File-level analysis**: Examines each changed file to determine its impact type
- **Knowledge base correlation**: Identifies which documentation pages might be affected
- **Priority scoring**: Assigns impact levels (low, medium, high, critical) based on change types
- **Recommendation generation**: Provides specific actions needed to update documentation

### 🔍 Conflict Detection
- **Code-to-documentation analysis**: Detects when code changes conflict with existing documentation
- **API endpoint tracking**: Identifies removed/added endpoints that are still/not documented
- **Database schema conflicts**: Detects schema changes that affect documented data models
- **Configuration conflicts**: Finds configuration changes that impact documented settings
- **Severity classification**: Categorizes conflicts as critical, high, medium, or low priority

### 🔔 Automated Notifications
- **High-impact alerts**: Sends notifications for high-impact changes via Slack and email
- **JIRA ticket creation**: Automatically creates JIRA tickets for required documentation updates
- **Detailed reporting**: Provides comprehensive impact reports with actionable recommendations

## Setup Instructions

### 1. GitHub Configuration

#### Create a GitHub Personal Access Token
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate a new token with the following permissions:
   - `repo` (Full control of private repositories)
   - `read:org` (Read organization data)
   - `read:user` (Read user data)

#### Configure Environment Variables
Add the following to your `config.env` file:

```bash
# GitHub Configuration
GITHUB_TOKEN=your-github-personal-access-token
GITHUB_WEBHOOK_SECRET=your-github-webhook-secret
```

### 2. GitHub Webhook Setup

#### Create Webhook in GitHub Repository
1. Go to your GitHub repository
2. Navigate to Settings → Webhooks
3. Click "Add webhook"
4. Configure the webhook:
   - **Payload URL**: `https://your-domain.com/webhook/github`
   - **Content type**: `application/json`
   - **Secret**: Generate a secure secret and add it to `GITHUB_WEBHOOK_SECRET`
   - **Events**: Select "Pull requests" (or "Let me select individual events" and choose "Pull requests")
   - **Active**: Checked

#### For Organization-wide Monitoring
1. Go to your GitHub organization
2. Navigate to Settings → Webhooks
3. Follow the same configuration as above
4. This will monitor all repositories in the organization

### 3. Notification Configuration

#### Slack Integration
1. Create a Slack app in your workspace
2. Add an Incoming Webhook integration
3. Copy the webhook URL and add it to `config.env`:

```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

#### Email Notifications
Add email addresses to receive notifications:

```bash
NOTIFICATION_EMAILS=admin@company.com,tech-lead@company.com
```

## How It Works

### 1. Pull Request Lifecycle

#### When a PR is Opened
- System performs preliminary analysis
- Assesses potential impact based on changed files
- Stores analysis for future reference

#### When a PR is Updated
- Re-runs preliminary analysis
- Updates stored analysis with latest changes

#### When a PR is Merged
- Performs comprehensive impact analysis
- Identifies affected documentation
- Generates detailed recommendations
- Creates JIRA tickets if needed
- Sends notifications for high-impact changes

### 2. Impact Analysis Process

#### File Type Detection
The system categorizes changes based on file patterns:

- **API Changes**: Controller files, API endpoints, service layers
- **Database Changes**: SQL files, migration files, schema changes
- **Security Changes**: Authentication, authorization, security-related files
- **Configuration Changes**: YAML, JSON, properties files
- **Documentation Changes**: Markdown, README files

#### Impact Scoring
Impact levels are determined by:

- **Critical (10+ points)**: Breaking changes, security implications
- **High (8-9 points)**: API changes, database schema changes
- **Medium (4-7 points)**: Configuration changes, significant code changes
- **Low (1-3 points)**: Documentation updates, minor changes

### 3. Knowledge Base Correlation

The system analyzes existing documentation to identify:

- **Confluence pages** that might be affected by code changes
- **Intercom articles** that need updates
- **JIRA tickets** related to the changes
- **Missing documentation** that should be created

## API Endpoints

### Webhook Endpoint
```
POST /webhook/github
```
Processes GitHub webhooks for pull request events.

### Manual Analysis
```
GET /api/github/pr/:repo/:pr_number/impact
```
Manually analyze a specific pull request for knowledge base impact.

```
GET /api/github/pr/:repo/:pr_number/conflicts
```
Detect knowledge base conflicts for a specific pull request.

```
GET /api/github/pr/:repo/:pr_number/preliminary
```
Get preliminary analysis for an open pull request.

### Report Management
```
GET /api/github/impact-reports
```
List all stored impact reports.

```
GET /api/github/preliminary-analyses
```
List all preliminary analyses.

## Web Interface

### GitHub Impact Dashboard
Access the web interface at `/github-impact` to:

- View all impact reports
- See preliminary analyses
- Manually analyze specific PRs
- Download detailed reports
- Monitor impact statistics

### Dashboard Features
- **Impact Reports**: Complete analysis of merged PRs
- **Conflict Detection**: Detailed analysis of code-to-documentation conflicts
- **Preliminary Analyses**: Early assessments of open PRs
- **Manual Analysis**: Analyze any PR by repository and number
- **Statistics**: Overview of impact levels and recent activity

## JIRA Integration

### Automatic Ticket Creation
When high-impact changes are detected, the system automatically creates JIRA tickets with:

- **Summary**: "Update documentation after PR #X merge"
- **Description**: Detailed impact analysis and recommendations
- **Priority**: Based on impact level
- **Labels**: `documentation`, `pr-impact`, `pr-{number}`
- **Components**: Documentation team

### Ticket Content
Each ticket includes:

- PR details (repository, number, title, author)
- Impact analysis summary
- Specific recommendations
- List of affected documentation
- Action items for documentation updates

## Best Practices

### 1. Repository Organization
- Use consistent file naming conventions
- Organize code by feature/domain
- Keep documentation close to code
- Use meaningful commit messages

### 2. Documentation Strategy
- Update documentation as part of PR process
- Include documentation changes in PR descriptions
- Tag documentation team for high-impact changes
- Maintain documentation templates

### 3. Monitoring and Maintenance
- Regularly review impact reports
- Update webhook configurations as needed
- Monitor notification delivery
- Adjust impact scoring based on team feedback

## Troubleshooting

### Common Issues

#### Webhook Not Receiving Events
- Verify webhook URL is accessible
- Check webhook secret configuration
- Ensure repository has webhook permissions
- Review GitHub webhook delivery logs

#### Analysis Not Working
- Verify GitHub token has correct permissions
- Check environment variable configuration
- Review application logs for errors
- Ensure repository is accessible

#### Notifications Not Sending
- Verify Slack webhook URL is correct
- Check email configuration
- Review notification service logs
- Test webhook endpoints manually

### Debug Mode
Enable debug logging by setting:
```bash
ENVIRONMENT=development
```

### Manual Testing
Test the webhook manually using curl:
```bash
curl -X POST http://localhost:3000/webhook/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: pull_request" \
  -d @test-webhook-payload.json
```

## Security Considerations

### Webhook Security
- Always use webhook secrets
- Verify webhook signatures
- Use HTTPS for webhook URLs
- Regularly rotate secrets

### Token Security
- Use minimal required permissions
- Store tokens securely
- Rotate tokens regularly
- Monitor token usage

### Access Control
- Restrict webhook access to trusted sources
- Implement rate limiting
- Monitor for suspicious activity
- Log all webhook events

## Future Enhancements

### Planned Features
- **AI-powered analysis**: Use machine learning to improve impact assessment
- **Documentation templates**: Auto-generate documentation updates
- **Integration with more tools**: Support for GitLab, Bitbucket, etc.
- **Advanced reporting**: Custom dashboards and analytics
- **Workflow automation**: Automated documentation updates

### Customization Options
- **Custom impact rules**: Define organization-specific impact criteria
- **Flexible notifications**: Custom notification templates and channels
- **Integration APIs**: REST APIs for custom integrations
- **Plugin system**: Extensible architecture for custom analyzers

