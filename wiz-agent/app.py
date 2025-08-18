from flask import Flask, request, jsonify
from langchain_aws import ChatBedrock
from langchain.agents import initialize_agent, AgentType
from langchain.memory import ConversationBufferWindowMemory
from langchain.schema import BaseMessage
import os
from dotenv import load_dotenv
import logging
import uuid
from tools import create_tools

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class WizAgent:
    def __init__(self):
        self.llm = None
        self.agent = None
        self.sessions = {}  # Store conversation sessions
        self.initialize_bedrock()
        self.initialize_agent()
    
    def initialize_bedrock(self):
        """Initialize Bedrock LLM."""
        try:
            self.llm = ChatBedrock(
                model_id="anthropic.claude-3-sonnet-20240229-v1:0",
                region_name=os.getenv('AWS_REGION', 'us-east-1'),
                model_kwargs={
                    "max_tokens": 2000,
                    "temperature": 0.1,
                    "top_p": 0.9
                }
            )
            logger.info("Bedrock LLM initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Bedrock: {str(e)}")
            raise
    
    def initialize_agent(self):
        """Initialize LangChain agent with tools."""
        try:
            tools = create_tools()
            
            # Create agent without memory (we'll handle sessions separately)
            self.agent = initialize_agent(
                tools=tools,
                llm=self.llm,
                agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
                verbose=True,
                handle_parsing_errors=True,
                max_iterations=3,
                early_stopping_method="generate"
            )
            logger.info("Agent initialized successfully with tools")
        except Exception as e:
            logger.error(f"Failed to initialize agent: {str(e)}")
            raise
    
    def get_or_create_session(self, session_id: str = None):
        """Get or create a conversation session."""
        if not session_id:
            session_id = str(uuid.uuid4())
        
        if session_id not in self.sessions:
            self.sessions[session_id] = {
                'memory': ConversationBufferWindowMemory(
                    memory_key="chat_history",
                    return_messages=True,
                    k=10  # Keep last 10 exchanges
                ),
                'created_at': None
            }
        
        return session_id, self.sessions[session_id]
    
    def chat(self, message: str, session_id: str = None):
        """Process a chat message and return response."""
        try:
            session_id, session = self.get_or_create_session(session_id)
            
            # Create agent with session memory
            agent_with_memory = initialize_agent(
                tools=create_tools(),
                llm=self.llm,
                agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
                memory=session['memory'],
                verbose=True,
                handle_parsing_errors=True,
                max_iterations=3,
                early_stopping_method="generate"
            )
            
            response = agent_with_memory.run(input=message)
            
            return {
                'response': response,
                'session_id': session_id,
                'status': 'success'
            }
        
        except Exception as e:
            logger.error(f"Error processing message: {str(e)}")
            return {
                'response': f"I encountered an error: {str(e)}",
                'session_id': session_id,
                'status': 'error'
            }

# Initialize the agent
wiz_agent = WizAgent()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'service': 'wiz-agent'})

@app.route('/chat', methods=['POST'])
def chat():
    """Main chat endpoint."""
    try:
        data = request.get_json()
        
        if not data or 'message' not in data:
            return jsonify({'error': 'Message is required'}), 400
        
        message = data['message']
        session_id = data.get('session_id')
        
        result = wiz_agent.chat(message, session_id)
        
        return jsonify(result)
    
    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/sessions/<session_id>/history', methods=['GET'])
def get_session_history(session_id):
    """Get conversation history for a session."""
    try:
        if session_id in wiz_agent.sessions:
            memory = wiz_agent.sessions[session_id]['memory']
            messages = memory.chat_memory.messages
            
            history = []
            for msg in messages:
                history.append({
                    'type': msg.__class__.__name__,
                    'content': msg.content
                })
            
            return jsonify({
                'session_id': session_id,
                'history': history
            })
        else:
            return jsonify({'error': 'Session not found'}), 404
    
    except Exception as e:
        logger.error(f"Error getting session history: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/sessions/<session_id>', methods=['DELETE'])
def delete_session(session_id):
    """Delete a conversation session."""
    try:
        if session_id in wiz_agent.sessions:
            del wiz_agent.sessions[session_id]
            return jsonify({'message': 'Session deleted successfully'})
        else:
            return jsonify({'error': 'Session not found'}), 404
    
    except Exception as e:
        logger.error(f"Error deleting session: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/tools', methods=['GET'])
def list_tools():
    """List available tools."""
    tools = create_tools()
    tool_info = []
    
    for tool in tools:
        tool_info.append({
            'name': tool.name,
            'description': tool.description
        })
    
    return jsonify({'tools': tool_info})

if __name__ == '__main__':
    port = int(os.getenv('PORT', 10001))
    app.run(host='0.0.0.0', port=port, debug=os.getenv('FLASK_ENV') == 'development')
