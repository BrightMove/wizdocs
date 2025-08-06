# Engage Agentic AI Design: Next 4 Steps Implementation Plan

## Executive Summary

This document outlines the specific design and implementation tasks for the next 4 critical steps to enhance BrightMove's existing agentic AI foundation. Based on the current state analysis, we have a solid foundation with AWS Bedrock integration, basic AI evaluation endpoints, and frontend integration. The next steps focus on adding LangChain orchestration, implementing the "Wiz" agent persona, expanding agentic capabilities, and integrating Twilio for messaging.

## Current State Assessment

### ✅ Already Implemented
- AWS Bedrock integration in `AiAgenticService`
- Basic AI evaluation endpoints (`/agent/recruiter/evaluate`)
- Generative AI endpoints (`/ai/job-description`, `/ai/email`)
- Frontend integration in Engage app
- MongoDB audit logging
- Server-Sent Events (SSE) for streaming responses

### 🔄 Next 4 Steps to Implement

## Step 1: LangChain Integration & Orchestration Layer

### Architecture Overview
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Engage App    │    │  LangChain       │    │   AWS Bedrock   │
│   (Frontend)    │◄──►│  Orchestration   │◄──►│   (LLM)         │
└─────────────────┘    │   Layer          │    └─────────────────┘
                       └──────────────────┘
                                │
                       ┌──────────────────┐
                       │  Tool Registry   │
                       │  - ATS APIs      │
                       │  - External APIs │
                       │  - Custom Tools  │
                       └──────────────────┘
```

### Implementation Tasks

#### 1.1 Create LangChain Service Layer
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/ai/LangChainOrchestrationService.java`

```java
@Service
@Slf4j
public class LangChainOrchestrationService {
    
    private final BedrockRuntimeClient bedrockClient;
    private final ToolRegistry toolRegistry;
    private final AgentMemoryService memoryService;
    
    public AgentResponse executeAgentWorkflow(
        UserModel user, 
        AgentWorkflowRequest request,
        List<AgentTool> tools
    ) {
        // 1. Initialize LangChain agent with tools
        // 2. Set up conversation memory
        // 3. Execute workflow with Bedrock
        // 4. Return structured response
    }
    
    public StreamingAgentResponse executeStreamingWorkflow(
        UserModel user,
        AgentWorkflowRequest request,
        SseEmitter emitter
    ) {
        // Streaming version for real-time responses
    }
}
```

#### 1.2 Create Tool Registry
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/ai/tools/AgentToolRegistry.java`

```java
@Component
public class AgentToolRegistry {
    
    private final Map<String, AgentTool> tools = new ConcurrentHashMap<>();
    
    @PostConstruct
    public void registerDefaultTools() {
        registerTool(new ATSDataTool());
        registerTool(new EmailCompositionTool());
        registerTool(new CandidateSearchTool());
        registerTool(new JobDescriptionTool());
        registerTool(new CalendarSchedulingTool());
    }
    
    public List<AgentTool> getToolsForWorkflow(String workflowType) {
        // Return appropriate tools based on workflow
    }
}
```

#### 1.3 Create Agent Tool Interface
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/ai/tools/AgentTool.java`

```java
public interface AgentTool {
    String getName();
    String getDescription();
    List<ToolParameter> getParameters();
    ToolResult execute(Map<String, Object> parameters, UserModel user);
}
```

### LangChain-Specific Instructions

1. **Install LangChain4j Dependencies**
   ```xml
   <!-- Add to build.gradle -->
   implementation 'dev.langchain4j:langchain4j:0.27.1'
   implementation 'dev.langchain4j:langchain4j-bedrock:0.27.1'
   implementation 'dev.langchain4j:langchain4j-memory:0.27.1'
   ```

2. **Configure LangChain4j with Bedrock**
   ```java
   @Configuration
   public class LangChainConfig {
       
       @Bean
       public BedrockChatModel bedrockChatModel(BedrockRuntimeClient client) {
           return BedrockChatModel.builder()
               .client(client)
               .model("anthropic.claude-3-sonnet-20240229-v1:0")
               .build();
       }
       
       @Bean
       public AgentMemoryService memoryService() {
           return new InMemoryAgentMemoryService();
       }
   }
   ```

## Step 2: Wiz Agent Persona Implementation

### Architecture Overview
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Wiz Agent     │    │  Communication   │    │   Personality   │
│   Controller    │◄──►│  Manager         │◄──►│   Engine        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                       ┌──────────────────┐
                       │  Channel Router  │
                       │  - Email         │
                       │  - SMS           │
                       │  - In-App        │
                       └──────────────────┘
```

### Implementation Tasks

#### 2.1 Create Wiz Agent Service
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/ai/wiz/WizAgentService.java`

```java
@Service
@Slf4j
public class WizAgentService {
    
    private final LangChainOrchestrationService orchestrationService;
    private final CommunicationManager communicationManager;
    private final PersonalityEngine personalityEngine;
    private final ChannelRouter channelRouter;
    
    public WizResponse handleCommunication(
        UserModel user,
        CommunicationRequest request
    ) {
        // 1. Analyze communication context
        // 2. Apply Wiz personality
        // 3. Route to appropriate channel
        // 4. Execute communication workflow
    }
    
    public WizResponse manageConversation(
        UserModel user,
        ConversationRequest request
    ) {
        // Handle ongoing conversation management
    }
}
```

#### 2.2 Create Communication Manager
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/ai/wiz/CommunicationManager.java`

```java
@Component
public class CommunicationManager {
    
    private final TimingOptimizer timingOptimizer;
    private final ContentOptimizer contentOptimizer;
    private final ConsistencyEngine consistencyEngine;
    
    public CommunicationPlan optimizeCommunication(
        CommunicationContext context,
        UserModel user
    ) {
        // 1. Analyze timing patterns
        // 2. Optimize content for channel
        // 3. Ensure consistency across channels
        // 4. Return optimized plan
    }
}
```

#### 2.3 Create Personality Engine
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/ai/wiz/PersonalityEngine.java`

```java
@Component
public class PersonalityEngine {
    
    private final WizPersonalityConfig personalityConfig;
    private final ToneAnalyzer toneAnalyzer;
    private final AuthenticityChecker authenticityChecker;
    
    public String applyWizPersonality(
        String baseContent,
        CommunicationContext context,
        UserModel user
    ) {
        // 1. Load Wiz personality traits
        // 2. Analyze context and tone
        // 3. Apply personality transformations
        // 4. Ensure authenticity
    }
}
```

### LangChain-Specific Instructions for Wiz Agent

1. **Create Wiz Agent Chain**
   ```java
   @Component
   public class WizAgentChain {
       
       private final ChatLanguageModel model;
       private final List<AgentTool> wizTools;
       
       public WizAgentChain(BedrockChatModel model, AgentToolRegistry toolRegistry) {
           this.model = model;
           this.wizTools = toolRegistry.getToolsForWorkflow("wiz_communication");
       }
       
       public String executeWizWorkflow(String input, UserModel user) {
           // Create LangChain4j agent with Wiz-specific tools
           Agent agent = Agent.builder()
               .chatLanguageModel(model)
               .tools(wizTools)
               .memory(new InMemoryChatMemory())
               .build();
           
           return agent.execute(input);
       }
   }
   ```

2. **Define Wiz Personality Prompt**
   ```java
   public class WizPersonalityPrompt {
       private static final String WIZ_SYSTEM_PROMPT = """
           You are Wiz, an AI assistant for BrightMove Engage. Your personality traits:
           - Professional yet approachable
           - Proactive in communication
           - Consistent across all channels
           - Authentic and trustworthy
           - Optimized for hiring context
           
           Always maintain these traits in your responses.
           """;
   }
   ```

## Step 3: Twilio Integration for Messaging

### Architecture Overview
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Twilio SDK    │    │  Message Router  │    │   Channel       │
│   Integration   │◄──►│  & Handler       │◄──►│   Manager       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                       ┌──────────────────┐
                       │  Conversation    │
                       │  Store           │
                       │  (MongoDB)       │
                       └──────────────────┘
```

### Implementation Tasks

#### 3.1 Create Twilio Service
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/messaging/TwilioService.java`

```java
@Service
@Slf4j
public class TwilioService {
    
    private final TwilioClient twilioClient;
    private final ConversationStore conversationStore;
    private final MessageRouter messageRouter;
    
    public MessageResponse sendMessage(
        UserModel user,
        MessageRequest request
    ) {
        // 1. Validate message request
        // 2. Route to appropriate Twilio service
        // 3. Store conversation state
        // 4. Return response
    }
    
    public void handleIncomingMessage(
        TwilioWebhookRequest webhook
    ) {
        // Handle incoming SMS/WhatsApp messages
    }
}
```

#### 3.2 Create Message Router
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/messaging/MessageRouter.java`

```java
@Component
public class MessageRouter {
    
    private final WizAgentService wizAgentService;
    private final ChannelManager channelManager;
    
    public void routeMessage(
        Message message,
        UserModel user
    ) {
        // 1. Determine message type and channel
        // 2. Apply Wiz agent processing
        // 3. Route to appropriate handler
        // 4. Update conversation state
    }
}
```

#### 3.3 Create Conversation Store
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/messaging/ConversationStore.java`

```java
@Component
public class ConversationStore {
    
    private final MongoTemplate mongoTemplate;
    
    public Conversation saveConversation(Conversation conversation) {
        // Store conversation in MongoDB
    }
    
    public List<Message> getConversationHistory(String conversationId) {
        // Retrieve conversation history
    }
}
```

### LangChain-Specific Instructions for Twilio Integration

1. **Create Twilio Tool for LangChain**
   ```java
   @Component
   public class TwilioMessagingTool implements AgentTool {
       
       private final TwilioService twilioService;
       
       @Override
       public String getName() {
           return "twilio_messaging";
       }
       
       @Override
       public ToolResult execute(Map<String, Object> parameters, UserModel user) {
           String phoneNumber = (String) parameters.get("phone_number");
           String message = (String) parameters.get("message");
           
           MessageRequest request = MessageRequest.builder()
               .to(phoneNumber)
               .body(message)
               .build();
           
           MessageResponse response = twilioService.sendMessage(user, request);
           return ToolResult.success(response);
       }
   }
   ```

2. **Integrate with Wiz Agent**
   ```java
   // In WizAgentService
   public WizResponse handleSMSCommunication(
       UserModel user,
       SMSCommunicationRequest request
   ) {
       // Use LangChain to process SMS communication
       String wizResponse = wizAgentChain.executeWizWorkflow(
           request.getMessage(), 
           user
       );
       
       // Send via Twilio
       return twilioService.sendMessage(user, 
           MessageRequest.builder()
               .to(request.getPhoneNumber())
               .body(wizResponse)
               .build()
       );
   }
   ```

## Step 4: Advanced Agentic Capabilities Expansion

### Architecture Overview
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Agent         │    │  Workflow        │    │   Capability    │
│   Orchestrator  │◄──►│  Engine          │◄──►│   Registry      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                       ┌──────────────────┐
                       │  Specialized     │
                       │  Agents          │
                       │  - Screening     │
                       │  - Engagement    │
                       │  - Feedback      │
                       └──────────────────┘
```

### Implementation Tasks

#### 4.1 Create Agent Orchestrator
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/ai/orchestration/AgentOrchestrator.java`

```java
@Service
@Slf4j
public class AgentOrchestrator {
    
    private final Map<String, SpecializedAgent> agents;
    private final WorkflowEngine workflowEngine;
    private final CapabilityRegistry capabilityRegistry;
    
    public AgentResponse orchestrateWorkflow(
        UserModel user,
        WorkflowRequest request
    ) {
        // 1. Analyze workflow requirements
        // 2. Select appropriate agents
        // 3. Execute workflow with LangChain
        // 4. Return coordinated response
    }
}
```

#### 4.2 Create Specialized Agents
**File:** `apps/brightmove-ats/brightmove-common/src/main/java/com/bm/ats/ai/agents/SpecializedAgent.java`

```java
public abstract class SpecializedAgent {
    
    protected final LangChainOrchestrationService orchestrationService;
    protected final List<AgentTool> specializedTools;
    
    public abstract String getAgentType();
    public abstract AgentResponse execute(AgentRequest request, UserModel user);
    
    protected String executeWithLangChain(String prompt, UserModel user) {
        return orchestrationService.executeAgentWorkflow(
            user,
            AgentWorkflowRequest.builder()
                .prompt(prompt)
                .tools(specializedTools)
                .build()
        ).getResponse();
    }
}
```

#### 4.3 Implement Specific Agents

**Screening Agent:**
```java
@Component
public class ScreeningAgent extends SpecializedAgent {
    
    @Override
    public String getAgentType() {
        return "screening";
    }
    
    @Override
    public AgentResponse execute(AgentRequest request, UserModel user) {
        String prompt = buildScreeningPrompt(request);
        String response = executeWithLangChain(prompt, user);
        return AgentResponse.builder()
            .agentType("screening")
            .response(response)
            .confidence(calculateConfidence(response))
            .build();
    }
}
```

**Engagement Agent:**
```java
@Component
public class EngagementAgent extends SpecializedAgent {
    
    @Override
    public String getAgentType() {
        return "engagement";
    }
    
    @Override
    public AgentResponse execute(AgentRequest request, UserModel user) {
        String prompt = buildEngagementPrompt(request);
        String response = executeWithLangChain(prompt, user);
        return AgentResponse.builder()
            .agentType("engagement")
            .response(response)
            .nextActions(determineNextActions(response))
            .build();
    }
}
```

### LangChain-Specific Instructions for Advanced Capabilities

1. **Create Multi-Agent LangChain Setup**
   ```java
   @Component
   public class MultiAgentOrchestrator {
       
       private final Map<String, Agent> agents;
       private final BedrockChatModel model;
       
       public MultiAgentOrchestrator(BedrockChatModel model, 
                                   List<SpecializedAgent> specializedAgents) {
           this.model = model;
           this.agents = createAgents(specializedAgents);
       }
       
       private Map<String, Agent> createAgents(List<SpecializedAgent> specializedAgents) {
           Map<String, Agent> agentMap = new HashMap<>();
           
           for (SpecializedAgent specializedAgent : specializedAgents) {
               Agent agent = Agent.builder()
                   .chatLanguageModel(model)
                   .tools(specializedAgent.getSpecializedTools())
                   .memory(new InMemoryChatMemory())
                   .build();
               
               agentMap.put(specializedAgent.getAgentType(), agent);
           }
           
           return agentMap;
       }
       
       public String executeMultiAgentWorkflow(String input, 
                                             List<String> agentTypes, 
                                             UserModel user) {
           // Execute workflow across multiple agents
           String result = input;
           for (String agentType : agentTypes) {
               Agent agent = agents.get(agentType);
               result = agent.execute(result);
           }
           return result;
       }
   }
   ```

2. **Create Workflow Templates**
   ```java
   @Component
   public class WorkflowTemplateRegistry {
       
       private final Map<String, WorkflowTemplate> templates;
       
       public WorkflowTemplateRegistry() {
           this.templates = new HashMap<>();
           initializeTemplates();
       }
       
       private void initializeTemplates() {
           // Screening workflow
           templates.put("screening", WorkflowTemplate.builder()
               .name("screening")
               .agents(Arrays.asList("screening", "feedback"))
               .tools(Arrays.asList("ats_data", "candidate_search"))
               .build());
           
           // Engagement workflow
           templates.put("engagement", WorkflowTemplate.builder()
               .name("engagement")
               .agents(Arrays.asList("engagement", "wiz"))
               .tools(Arrays.asList("twilio_messaging", "email_composition"))
               .build());
       }
   }
   ```

## Deployment Instructions

### 1. Database Schema Updates
```sql
-- Create new tables for agentic features
CREATE TABLE agent_conversations (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    conversation_sid VARCHAR(255),
    channel_type VARCHAR(50),
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE agent_workflows (
    id VARCHAR(36) PRIMARY KEY,
    workflow_type VARCHAR(100) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    status VARCHAR(50),
    result JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 2. Configuration Updates
**File:** `apps/brightmove-ats/brightmove-web/src/main/resources/application.yml`

```yaml
langchain:
  bedrock:
    model: anthropic.claude-3-sonnet-20240229-v1:0
    max-tokens: 4096
    temperature: 0.7
  
twilio:
  account-sid: ${TWILIO_ACCOUNT_SID}
  auth-token: ${TWILIO_AUTH_TOKEN}
  phone-number: ${TWILIO_PHONE_NUMBER}
  
agent:
  wiz:
    personality-config: classpath:config/wiz-personality.json
    memory-retention-days: 30
  
workflow:
  max-concurrent: 10
  timeout-seconds: 300
```

### 3. New REST Endpoints
**File:** `apps/brightmove-ats/brightmove-web/src/main/java/com/bm/ats/controller/agent/AdvancedAgentController.java`

```java
@RestController
@RequestMapping("/agent/v2")
@Slf4j
public class AdvancedAgentController {
    
    private final AgentOrchestrator agentOrchestrator;
    private final WizAgentService wizAgentService;
    private final TwilioService twilioService;
    
    @PostMapping("/workflow")
    public AgentResponse executeWorkflow(
        @RequestHeader(value = ApiHeaders.USER_API_KEY) String userApiKey,
        @RequestBody WorkflowRequest request
    ) {
        UserModel user = userService.getUserByApiKey(userApiKey);
        return agentOrchestrator.orchestrateWorkflow(user, request);
    }
    
    @PostMapping("/wiz/communicate")
    public WizResponse communicate(
        @RequestHeader(value = ApiHeaders.USER_API_KEY) String userApiKey,
        @RequestBody CommunicationRequest request
    ) {
        UserModel user = userService.getUserByApiKey(userApiKey);
        return wizAgentService.handleCommunication(user, request);
    }
    
    @PostMapping("/twilio/webhook")
    public void handleTwilioWebhook(@RequestBody TwilioWebhookRequest webhook) {
        twilioService.handleIncomingMessage(webhook);
    }
}
```

### 4. Frontend Integration Updates
**File:** `apps/engage-app/src/components/WizAgent.tsx`

```typescript
interface WizAgentProps {
  conversationId?: string;
  channelType: 'email' | 'sms' | 'in-app';
}

export const WizAgent: React.FC<WizAgentProps> = ({ conversationId, channelType }) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isTyping, setIsTyping] = useState(false);
  
  const sendMessage = async (content: string) => {
    setIsTyping(true);
    try {
      const response = await api.post('/agent/v2/wiz/communicate', {
        content,
        channelType,
        conversationId
      });
      
      setMessages(prev => [...prev, response.data]);
    } catch (error) {
      console.error('Error sending message:', error);
    } finally {
      setIsTyping(false);
    }
  };
  
  return (
    <div className="wiz-agent-container">
      <MessageList messages={messages} />
      <MessageInput onSend={sendMessage} isTyping={isTyping} />
    </div>
  );
};
```

## Testing Strategy

### 1. Unit Tests
- Test each specialized agent independently
- Mock LangChain responses
- Test tool execution

### 2. Integration Tests
- Test agent orchestration
- Test Twilio integration
- Test conversation flow

### 3. End-to-End Tests
- Test complete workflow from frontend to backend
- Test multi-agent scenarios
- Test error handling and recovery

## Monitoring & Observability

### 1. Metrics to Track
- Agent response times
- Workflow success rates
- Twilio message delivery rates
- User engagement metrics

### 2. Logging Strategy
- Structured logging for all agent interactions
- Audit trail for AI decisions
- Performance monitoring

### 3. Alerting
- Agent failure alerts
- High latency alerts
- Twilio delivery failure alerts

## Risk Mitigation

### 1. Technical Risks
- **LangChain Version Compatibility**: Pin specific versions and test thoroughly
- **Bedrock Rate Limits**: Implement retry logic and circuit breakers
- **Twilio Costs**: Monitor usage and implement rate limiting

### 2. Business Risks
- **AI Response Quality**: Implement human-in-the-loop for critical decisions
- **Data Privacy**: Ensure all AI interactions are logged and auditable
- **User Adoption**: Provide clear value proposition and training

## Success Metrics

### 1. Technical Metrics
- Agent response time < 2 seconds
- Workflow success rate > 95%
- System uptime > 99.9%

### 2. Business Metrics
- User engagement increase > 20%
- Communication efficiency improvement > 30%
- Customer satisfaction score > 4.5/5

## Timeline

### Week 1-2: LangChain Integration
- Set up LangChain4j dependencies
- Create orchestration service
- Implement tool registry

### Week 3-4: Wiz Agent Implementation
- Create Wiz agent service
- Implement personality engine
- Add communication manager

### Week 5-6: Twilio Integration
- Set up Twilio SDK
- Create message router
- Implement conversation store

### Week 7-8: Advanced Capabilities
- Create agent orchestrator
- Implement specialized agents
- Add workflow templates

### Week 9-10: Testing & Deployment
- Comprehensive testing
- Performance optimization
- Production deployment

## Appendix: Analysis Process

### Documents Analyzed
- Current ATS source code structure
- Existing AI service implementations
- Engage app frontend architecture
- BrightMove technical stack documentation

### Key Decisions Made
1. **LangChain4j over Python LangChain**: Better integration with existing Java Spring stack
2. **Modular Agent Architecture**: Allows for independent development and testing
3. **Twilio as Primary Messaging Platform**: Leverages existing Twilio SDK integration
4. **MongoDB for Conversation Storage**: Consistent with existing audit logging approach

### Assumptions
1. AWS Bedrock will remain the primary LLM provider
2. Existing ATS data models will be sufficient for agentic features
3. Twilio pricing model will remain cost-effective for the use case
4. LangChain4j will provide the necessary orchestration capabilities

### Gaps Identified
1. Need for comprehensive testing framework for AI agents
2. Requirement for human-in-the-loop validation system
3. Need for advanced monitoring and observability tools
4. Requirement for AI bias detection and mitigation tools 