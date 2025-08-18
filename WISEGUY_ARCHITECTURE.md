# Wiseguy - Technical Architecture Overview

## 🏗️ System Architecture Diagram

```mermaid
graph TB
    %% User Interface Layer
    subgraph "User Interface"
        UI[Web Browser]
        UI --> |HTTP/HTTPS| AdminUI
    end

    %% Main Application Layer
    subgraph "Wiseguy Core Services"
        AdminUI[Admin UI<br/>Ruby Sinatra<br/>Port 3000]
        WizAgent[Wiz-Agent<br/>Python Flask<br/>Port 10001]
        SalesTools[Sales Tools<br/>RFP/SOW/Proposal<br/>Generation]
    end

    %% Data Storage Layer
    subgraph "Data Storage"
        Redis[(Redis<br/>Cache & Vector Store<br/>Port 6379)]
        FileSystem[(File System<br/>JSON Storage<br/>CRM Data)]
        VectorDB[(Vector Database<br/>Embeddings & Search)]
    end

    %% External AI Services
    subgraph "AI & ML Services"
        Bedrock[AWS Bedrock<br/>Claude 3 Sonnet<br/>Titan Embeddings]
        LangChain[LangChain<br/>Agent Framework]
    end

    %% External Integrations
    subgraph "External Integrations"
        GitHub[GitHub API<br/>Source Code<br/>Repositories]
        Jira[Jira API<br/>Project Management<br/>Tickets]
        Confluence[Confluence API<br/>Documentation<br/>Knowledge Base]
        Intercom[Intercom API<br/>Customer Support<br/>Articles]
    end

    %% Content Management
    subgraph "Content Management"
        ContentRepo[Content Repository<br/>Structured Data<br/>Templates]
        VectorRelations[Vector Relationships<br/>Content Analysis<br/>Impact Tracking]
    end

    %% Audit & Analysis
    subgraph "Audit & Analysis"
        Audits[Audit Engine<br/>Veracity Checks<br/>Consistency Analysis]
        KnowledgeBase[Knowledge Base<br/>Search & Index<br/>Content Sync]
    end

    %% Connections
    AdminUI --> Redis
    AdminUI --> FileSystem
    AdminUI --> |HTTP| WizAgent
    AdminUI --> GitHub
    AdminUI --> Jira
    AdminUI --> Confluence
    AdminUI --> Intercom
    AdminUI --> ContentRepo
    AdminUI --> VectorRelations
    AdminUI --> Audits
    AdminUI --> KnowledgeBase

    WizAgent --> Bedrock
    WizAgent --> LangChain
    WizAgent --> Redis

    SalesTools --> FileSystem
    SalesTools --> |HTTP| WizAgent

    KnowledgeBase --> VectorDB
    KnowledgeBase --> Redis
    KnowledgeBase --> Bedrock

    VectorRelations --> VectorDB
    VectorRelations --> Bedrock
    VectorRelations --> Redis

    Audits --> GitHub
    Audits --> Jira
    Audits --> Confluence
    Audits --> Intercom
    Audits --> KnowledgeBase

    ContentRepo --> FileSystem
    ContentRepo --> VectorRelations

    %% Styling
    classDef coreService fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef storage fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef aiService fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef integration fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef content fill:#fce4ec,stroke:#880e4f,stroke-width:2px

    class AdminUI,WizAgent,SalesTools coreService
    class Redis,FileSystem,VectorDB storage
    class Bedrock,LangChain aiService
    class GitHub,Jira,Confluence,Intercom integration
    class ContentRepo,VectorRelations,Audits,KnowledgeBase content
```

## 🔧 Core Components

### 1. **Admin UI (Ruby Sinatra)**
- **Port**: 3000
- **Purpose**: Main web interface for Wiseguy
- **Features**:
  - Dashboard with system overview
  - CRM management (organizations, contacts, pipeline)
  - Sales tools project management
  - Knowledge base administration
  - Audit execution and monitoring
  - Settings and configuration

### 2. **Wiz-Agent (Python Flask)**
- **Port**: 10001
- **Purpose**: AI microservice for intelligent interactions
- **Features**:
  - LangChain agent framework
  - AWS Bedrock integration (Claude 3 Sonnet)
  - Conversation memory and session management
  - Tool integration for various operations
  - Health monitoring and status reporting

### 3. **Sales Tools**
- **Purpose**: AI-powered sales document generation
- **Features**:
  - RFP (Request for Proposal) generation
  - SOW (Statement of Work) creation
  - Proposal development
  - Template management
  - CRM integration for customer tracking

## 🗄️ Data Storage

### 1. **Redis**
- **Port**: 6379
- **Purpose**: Caching and vector storage
- **Usage**:
  - Session management
  - Content caching
  - Vector embeddings storage
  - Real-time data access
  - Performance optimization

### 2. **File System (JSON Storage)**
- **Purpose**: Persistent data storage
- **Stores**:
  - CRM data (organizations, contacts, activities)
  - Sales tools projects
  - Configuration files
  - Audit results
  - Content metadata

### 3. **Vector Database**
- **Purpose**: Semantic search and similarity matching
- **Features**:
  - Document embeddings storage
  - Content similarity search
  - Knowledge base indexing
  - Relationship mapping

## 🤖 AI & Machine Learning

### 1. **AWS Bedrock**
- **Models**:
  - Claude 3 Sonnet (2024-02-29-v1:0) for text generation
  - Titan embeddings for vector generation
- **Features**:
  - High-performance LLM access
  - Scalable AI processing
  - Enterprise-grade security
  - Cost-effective AI operations

### 2. **LangChain**
- **Purpose**: Agent framework and tool orchestration
- **Features**:
  - Tool integration and management
  - Conversation memory
  - Agent reasoning and decision making
  - Prompt engineering and optimization

## 🔗 External Integrations

### 1. **GitHub Integration**
- **Purpose**: Source code analysis and impact assessment
- **Features**:
  - Repository monitoring
  - Pull request analysis
  - Code change impact tracking
  - Documentation consistency checks

### 2. **Jira Integration**
- **Purpose**: Project management and ticket tracking
- **Features**:
  - Ticket synchronization
  - Project status monitoring
  - Issue tracking and analysis
  - Workflow automation

### 3. **Confluence Integration**
- **Purpose**: Documentation management and consistency
- **Features**:
  - Page synchronization
  - Content veracity checks
  - Documentation updates
  - Knowledge base integration

### 4. **Intercom Integration**
- **Purpose**: Customer support and knowledge management
- **Features**:
  - Article synchronization
  - Support ticket analysis
  - Customer feedback integration
  - Knowledge base updates

## 📊 Content Management

### 1. **Content Repository**
- **Purpose**: Structured content storage and management
- **Features**:
  - Template management
  - Content categorization
  - Version control
  - Metadata management

### 2. **Vector Relationships**
- **Purpose**: Content analysis and relationship mapping
- **Features**:
  - Semantic similarity analysis
  - Content impact assessment
  - Relationship visualization
  - Cross-reference management

## 🔍 Audit & Analysis

### 1. **Audit Engine**
- **Purpose**: Veracity and consistency checking
- **Features**:
  - Cross-platform consistency verification
  - Content accuracy validation
  - Impact analysis
  - Automated reporting

### 2. **Knowledge Base**
- **Purpose**: Centralized knowledge management
- **Features**:
  - Content indexing and search
  - Multi-source integration
  - Semantic search capabilities
  - Knowledge graph construction

## 🌐 Network Architecture

### Port Configuration
- **3000**: Admin UI (HTTP)
- **10001**: Wiz-Agent (HTTP)
- **6379**: Redis (TCP)
- **443**: External APIs (HTTPS)

### Security
- Environment-based configuration
- API key management
- Secure external integrations
- Data encryption in transit

## 📈 Scalability & Performance

### Horizontal Scaling
- Stateless service design
- Redis-based session management
- Load balancing ready
- Microservice architecture

### Performance Optimization
- Redis caching layer
- Vector database for fast search
- Async processing capabilities
- Content pre-indexing

## 🔄 Data Flow

1. **User Request** → Admin UI
2. **AI Processing** → Wiz-Agent (via HTTP)
3. **External Data** → GitHub/Jira/Confluence/Intercom APIs
4. **Storage** → Redis (cache) + File System (persistent)
5. **AI Analysis** → AWS Bedrock + LangChain
6. **Results** → Admin UI → User

## 🛠️ Development & Deployment

### Technology Stack
- **Backend**: Ruby (Sinatra), Python (Flask)
- **Frontend**: HTML, CSS, JavaScript
- **Database**: Redis, JSON files
- **AI**: AWS Bedrock, LangChain
- **Integrations**: REST APIs

### Deployment
- Container-ready architecture
- Environment-based configuration
- Health check endpoints
- Monitoring and logging

This architecture provides a robust, scalable foundation for Wiseguy's AI-powered platform, enabling comprehensive content management, intelligent analysis, and seamless integration with external systems.
