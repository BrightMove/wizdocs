# AWS Bedrock Integration Setup Guide

This guide explains how to configure WizDocs to use AWS Bedrock with Anthropic's Claude for LLM-powered knowledge base search and analysis.

## Overview

WizDocs now supports AWS Bedrock for:
- **LLM-powered search enhancement** using Anthropic Claude
- **Vector embeddings** using Amazon Titan
- **RAG (Retrieval-Augmented Generation)** for improved search results

## Prerequisites

1. **AWS Account** with Bedrock access
2. **AWS IAM User** with Bedrock permissions
3. **Ruby environment** with the required gems

## Step 1: AWS Setup

### 1.1 Enable Bedrock Access
1. Go to AWS Console → Amazon Bedrock
2. Request access to the following models:
   - `anthropic.claude-3-sonnet-20240229-v1:0` (LLM)
   - `anthropic.claude-3-haiku-20240307-v1:0` (LLM - faster alternative)
   - `amazon.titan-embed-text-v1` (Embeddings)

### 1.2 Create IAM User
Create an IAM user with the following policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": [
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
                "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
                "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
            ]
        }
    ]
}
```

### 1.3 Generate Access Keys
1. Go to IAM → Users → Your User → Security credentials
2. Create Access Key ID and Secret Access Key
3. Save these credentials securely

## Step 2: Configure WizDocs

### 2.1 Environment Variables
Copy `config.env.example` to `config.env` and add your AWS credentials:

```bash
# AWS Bedrock Configuration
AWS_ACCESS_KEY_ID=your-aws-access-key-id
AWS_SECRET_ACCESS_KEY=your-aws-secret-access-key
AWS_REGION=us-east-1
```

### 2.2 Install Dependencies
```bash
bundle install
```

## Step 3: Test the Integration

### 3.1 Run the Test Script
```bash
ruby test_bedrock.rb
```

This will test:
- AWS credentials
- Claude LLM access
- Titan embeddings access

### 3.2 Expected Output
```
Testing AWS Bedrock Integration...
==================================
✅ AWS credentials found
✅ AWS Bedrock client initialized

Testing Claude LLM...
✅ Claude LLM test successful
Response: 2+2 equals 4.

Testing Titan Embeddings...
✅ Titan Embeddings test successful
Embedding vector length: 1536

🎉 All AWS Bedrock tests passed!
```

## Step 4: Use the Knowledge Base

### 4.1 Start the Application
```bash
ruby app.rb
```

### 4.2 Access the Knowledge Base
1. Go to http://localhost:3000/knowledge-base
2. Enter search queries
3. Get LLM-enhanced results powered by Claude

## Features

### LLM-Enhanced Search
- **Semantic understanding** of queries
- **Context-aware responses** based on knowledge base content
- **Improved relevance scoring** using Claude's analysis

### Vector Search (with Redis)
- **Semantic similarity** using Titan embeddings
- **Fast retrieval** of relevant content
- **Scalable vector storage** in Redis

### RAG Implementation
- **Retrieval-Augmented Generation** for accurate responses
- **Source citation** in search results
- **Context preservation** across multiple sources

## Troubleshooting

### Common Issues

1. **"AWS credentials not configured"**
   - Check that `config.env` exists and contains AWS credentials
   - Verify the credentials are correct

2. **"Access denied" errors**
   - Ensure your IAM user has Bedrock permissions
   - Check that models are enabled in your AWS account

3. **"Model not found" errors**
   - Request access to the required models in AWS Bedrock console
   - Verify the model IDs are correct

4. **"Region not available" errors**
   - Check that Bedrock is available in your selected region
   - Use `us-east-1` as the default region

### Performance Tips

1. **Use Claude Haiku** for faster responses:
   - Change model ID to `anthropic.claude-3-haiku-20240307-v1:0`
   - Good for simple queries and faster processing

2. **Use Claude Sonnet** for complex analysis:
   - Default model: `anthropic.claude-3-sonnet-20240229-v1:0`
   - Better for complex reasoning and detailed responses

3. **Optimize Redis usage**:
   - Set up Redis for persistent vector storage
   - Configure appropriate TTL for cached embeddings

## Cost Considerations

### AWS Bedrock Pricing (as of 2024)
- **Claude Sonnet**: $0.003 per 1K input tokens, $0.015 per 1K output tokens
- **Claude Haiku**: $0.00025 per 1K input tokens, $0.00125 per 1K output tokens
- **Titan Embeddings**: $0.0001 per 1K tokens

### Cost Optimization
1. **Use Haiku for simple queries** to reduce costs
2. **Cache embeddings** in Redis to avoid repeated API calls
3. **Limit response lengths** by setting appropriate `max_tokens`
4. **Monitor usage** through AWS CloudWatch

## Security

### Best Practices
1. **Use IAM roles** instead of access keys in production
2. **Rotate credentials** regularly
3. **Limit permissions** to only required Bedrock actions
4. **Monitor API usage** for unusual patterns
5. **Use VPC endpoints** for enhanced security

### Data Privacy
- **No data retention**: AWS Bedrock doesn't store your prompts or responses
- **Encryption**: All data is encrypted in transit and at rest
- **Compliance**: Bedrock supports various compliance frameworks

## Support

For issues with:
- **AWS Bedrock**: Check AWS documentation and support
- **WizDocs integration**: Review this guide and check logs
- **Performance**: Monitor CloudWatch metrics and adjust settings

## Next Steps

Once AWS Bedrock is configured:
1. **Sync content sources** (Confluence, Intercom, JIRA, GitHub)
2. **Test search functionality** with real queries
3. **Configure scheduled audits** for automated analysis
4. **Monitor performance** and optimize settings
