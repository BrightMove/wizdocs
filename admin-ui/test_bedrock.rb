#!/usr/bin/env ruby

require 'dotenv'
require 'aws-sdk-bedrock'
require 'json'

# Load environment variables
Dotenv.load

puts "Testing AWS Bedrock Integration..."
puts "=================================="

# Check if AWS credentials are configured
unless ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']
  puts "❌ AWS credentials not configured"
  puts "Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in config.env"
  puts "You can copy config.env.example to config.env and fill in your credentials"
  exit 1
end

puts "✅ AWS credentials found"

begin
  # Initialize AWS Bedrock client
  bedrock_client = Aws::Bedrock::Client.new(
    region: ENV['AWS_REGION'] || 'us-east-1',
    credentials: Aws::Credentials.new(
      ENV['AWS_ACCESS_KEY_ID'],
      ENV['AWS_SECRET_ACCESS_KEY']
    )
  )
  
  puts "✅ AWS Bedrock client initialized"
  
  # Test Claude LLM
  puts "\nTesting Claude LLM..."
  claude_prompt = {
    messages: [
      {
        role: "user",
        content: "Hello! Can you help me with a simple question? What is 2+2?"
      }
    ],
    max_tokens: 100,
    temperature: 0.3
  }
  
  claude_response = bedrock_client.invoke_model(
    model_id: 'anthropic.claude-3-sonnet-20240229-v1:0',
    body: claude_prompt.to_json,
    content_type: 'application/json'
  )
  
  claude_result = JSON.parse(claude_response.body.string)
  claude_answer = claude_result.dig('content', 0, 'text') || 'No response'
  
  puts "✅ Claude LLM test successful"
  puts "Response: #{claude_answer.strip}"
  
  # Test Titan Embeddings
  puts "\nTesting Titan Embeddings..."
  titan_prompt = {
    inputText: "This is a test sentence for embeddings."
  }
  
  titan_response = bedrock_client.invoke_model(
    model_id: 'amazon.titan-embed-text-v1',
    body: titan_prompt.to_json,
    content_type: 'application/json'
  )
  
  titan_result = JSON.parse(titan_response.body.string)
  embedding_length = titan_result['embedding']&.length || 0
  
  puts "✅ Titan Embeddings test successful"
  puts "Embedding vector length: #{embedding_length}"
  
  puts "\n🎉 All AWS Bedrock tests passed!"
  puts "Your knowledge base is ready to use with AWS Bedrock and Anthropic Claude!"
  
rescue => e
  puts "❌ AWS Bedrock test failed: #{e.message}"
  puts "\nTroubleshooting tips:"
  puts "1. Make sure your AWS credentials are correct"
  puts "2. Ensure you have access to AWS Bedrock in your region"
  puts "3. Check that the models are available in your AWS account"
  puts "4. Verify your AWS IAM permissions include Bedrock access"
end
