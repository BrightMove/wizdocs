# Redis Content Inspection Guide

## Quick Redis Commands

### 1. **List All Keys**
```bash
# Show all keys in Redis
redis-cli keys "*"

# Show keys with specific patterns
redis-cli keys "content:*"          # All content items
redis-cli keys "relationships:*"    # All relationships
redis-cli keys "*:metadata"         # All metadata
redis-cli keys "scheduled_audits"   # Scheduled audits
```

### 2. **View Specific Content**

#### Knowledge Base Content
```bash
# View a specific content item
redis-cli get "content:content_id_here"

# View content metadata
redis-cli get "jira:metadata"
redis-cli get "intercom:metadata"
redis-cli get "github:metadata"
redis-cli get "confluence:metadata"
```

#### Relationships
```bash
# View relationships from a specific content
redis-cli lrange "relationships:from:content_id_here" 0 -1

# View relationships to a specific content
redis-cli lrange "relationships:to:content_id_here" 0 -1
```

#### Scheduled Audits
```bash
# View all scheduled audits
redis-cli hgetall "scheduled_audits"

# View specific audit type
redis-cli hget "scheduled_audits" "comprehensive"
```

### 3. **Search and Filter**

#### Find Keys by Pattern
```bash
# Find all JIRA content
redis-cli keys "*jira*"

# Find all content with "SSO" in the key
redis-cli keys "*SSO*"

# Find all metadata
redis-cli keys "*metadata*"
```

#### View Key Types
```bash
# Check what type of data a key contains
redis-cli type "key_name_here"

# Types: string, list, hash, set, zset
```

### 4. **Pretty Print JSON Content**

Since most content is stored as JSON, you can format it nicely:

```bash
# Pretty print JSON content
redis-cli get "content:some_id" | python3 -m json.tool

# Or with jq if installed
redis-cli get "content:some_id" | jq '.'
```

### 5. **Monitor Redis in Real-Time**

```bash
# Watch all Redis commands in real-time
redis-cli monitor

# Watch specific patterns
redis-cli monitor | grep "content:"
```

### 6. **Database Information**

```bash
# Get database info
redis-cli info

# Get memory usage
redis-cli info memory

# Get database size
redis-cli dbsize
```

## WizDocs-Specific Content Structure

### Content Keys
- `content:content_id` - Individual content items
- `source:metadata` - Metadata for each source (jira, intercom, etc.)
- `relationships:from:content_id` - Outgoing relationships
- `relationships:to:content_id` - Incoming relationships
- `scheduled_audits` - Hash of scheduled audit configurations

### Vector Embeddings
- `embedding:content_id` - Vector embeddings for content
- `vector:similarity:content_id` - Similarity scores

## Example Workflow

1. **See what's in Redis:**
   ```bash
   redis-cli keys "*"
   ```

2. **Find content by source:**
   ```bash
   redis-cli keys "*jira*"
   ```

3. **View specific content:**
   ```bash
   redis-cli get "content:content_123" | python3 -m json.tool
   ```

4. **Check relationships:**
   ```bash
   redis-cli lrange "relationships:from:content_123" 0 -1
   ```

5. **Monitor as you use the app:**
   ```bash
   redis-cli monitor
   ```

## Useful Aliases

Add these to your shell profile for quick access:

```bash
# Quick Redis inspection
alias redis-keys='redis-cli keys "*"'
alias redis-content='redis-cli keys "content:*"'
alias redis-relationships='redis-cli keys "relationships:*"'
alias redis-pretty='redis-cli get "$1" | python3 -m json.tool'
```

## Troubleshooting

### If Redis is Empty
- Content hasn't been synced from real sources yet
- Run content sync operations to populate Redis
- Check if the knowledge base manager is properly configured

### If Keys Don't Show Up
- Check if you're connected to the right Redis database
- Verify Redis is running: `redis-cli ping`
- Check for key expiration (TTL): `redis-cli ttl "key_name"`
