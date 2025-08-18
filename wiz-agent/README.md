# Wiz-Agent: LangChain + Bedrock Microservice

A Python microservice that provides an intelligent agent powered by AWS Bedrock and LangChain.

## Features

- **LangChain Agent**: ZERO_SHOT_REACT_DESCRIPTION agent with tool support
- **AWS Bedrock Integration**: Uses Claude 3 Sonnet model
- **Built-in Tools**:
  - Weather information
  - Mathematical calculations
  - Web search (mock implementation)
- **Session Management**: Conversation memory per session
- **REST API**: Simple HTTP endpoints for integration
- **Production Ready**: Docker support with Gunicorn

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your AWS credentials:

```bash
cp .env.example .env
```

Required environment variables:
- `AWS_REGION`: Your AWS region (default: us-east-1)
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

### 3. Run Locally

```bash
python app.py
```

The service will start on `http://localhost:10001`

### 4. Run with Docker

```bash
# Build image
docker build -t wiz-agent .

# Run container
docker run -p 10001:10001 --env-file .env wiz-agent
```

## API Endpoints

### Health Check
```bash
GET /health
```

### Chat
```bash
POST /chat
Content-Type: application/json

{
  "message": "What's the weather in New York?",
  "session_id": "optional-session-id"
}
```

Response:
```json
{
  "response": "The weather in New York is 72°F, sunny with light clouds",
  "session_id": "uuid-session-id",
  "status": "success"
}
```

### Get Session History
```bash
GET /sessions/{session_id}/history
```

### Delete Session
```bash
DELETE /sessions/{session_id}
```

### List Available Tools
```bash
GET /tools
```

## Usage Examples

### Basic Chat
```bash
curl -X POST http://localhost:10001/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Calculate 15 * 23"}'
```

### With Session
```bash
curl -X POST http://localhost:10001/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, I am John", "session_id": "my-session"}'
```

### Complex Query
```bash
curl -X POST http://localhost:10001/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the weather in Paris and calculate the tip for a $85 bill with 18% tip?"}'
```

## Ruby Integration

Here's how to integrate with your Ruby application:

```ruby
require 'net/http'
require 'json'

class WizAgent
  def initialize(base_url = 'http://localhost:10001')
    @base_url = base_url
  end

  def chat(message, session_id = nil)
    uri = URI("#{@base_url}/chat")
    http = Net::HTTP.new(uri.host, uri.port)
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    body = { message: message }
    body[:session_id] = session_id if session_id
    request.body = body.to_json
    
    response = http.request(request)
    JSON.parse(response.body)
  end

  def get_session_history(session_id)
    uri = URI("#{@base_url}/sessions/#{session_id}/history")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end

  def delete_session(session_id)
    uri = URI("#{@base_url}/sessions/#{session_id}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Delete.new(uri)
    http.request(request)
  end
end

# Usage
agent = WizAgent.new
result = agent.chat("What's 2+2?")
puts result['response']
```

## Adding Custom Tools

To add new tools, modify `tools.py`:

```python
def my_custom_tool(input_param: str) -> str:
    """Description of what this tool does."""
    # Your tool logic here
    return "Tool result"

# Add to create_tools() function:
Tool(
    name="MyTool",
    func=my_custom_tool,
    description="Tool description for the agent"
)
```

## AWS Bedrock Requirements

Ensure you have:
1. AWS account with Bedrock access
2. Claude 3 Sonnet model enabled in your region
3. Appropriate IAM permissions for Bedrock

## Production Deployment

For production:
1. Use environment variables for all configuration
2. Set up proper logging
3. Configure load balancing if needed
4. Monitor AWS Bedrock costs and quotas
5. Implement rate limiting if required

## Troubleshooting

- **Bedrock Access**: Ensure your AWS credentials have Bedrock permissions
- **Model Access**: Verify Claude 3 Sonnet is available in your region
- **Memory Issues**: Sessions are stored in memory; consider Redis for production
- **Timeouts**: Adjust Gunicorn timeout settings for complex queries
