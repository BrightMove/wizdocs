# Insperity Onboarding Data Integration Improvements
## Solution Design Document

**Project:** Insperity Onboarding Data Integration Improvements  
**Date:** July 16, 2025  
**Version:** 4.0  
**Prepared by:** BrightMove Solutions Team  

---

## Executive Summary

This solution design outlines a focused approach for improving the data integration between BrightMove's Applicant Tracking System (ATS) and Insperity's onboarding platform using webhook-based real-time integration. The solution addresses the current 2-hour latency issue by implementing direct event-driven communication using API key authentication and Insperity-defined data schemas, while staying within the allocated 3-month timeline and $15,000 budget.

## 1. Project Stakeholders

### Insperity Team
- **Hadley Hunter** - Integration Product Manager
- **Robert Bentz** - Onboarding Product Manager
- **Meynard Patacsil** - Solution Architect
- **Karen Millard** - ITC Product Manager
- **Martha Vera** - ITC Product Owner

### BrightMove Team
- **Jimmy Hurff** - Head of Customer Success
- **David Webb** - CEO & Head of Product

## 2. System Components Architecture

### Insperity Systems
- **ITC (Insperity Talent Connect)** - White-label BrightMove ATS platform branded for Insperity customers
- **Workato** - Insperity-managed iPaaS (Integration Platform as a Service) for system integrations
- **Workday** - Insperity-managed ERP platform for human resources and financial management
- **Premier** - Insperity-managed customer-facing portal for client services

### BrightMove Systems
- **ATS (Applicant Tracking System)** - Multi-tenant cloud-based platform hosted on AWS serving Insperity customers
- **Wisdom Data Platform** - Comprehensive data infrastructure including Fivetran, Snowflake enterprise data warehouse, and DBT platform for enterprise reporting

## 3. Problem Statement

### Current State Challenge

The existing integration between BrightMove's ATS and Insperity's onboarding platform presents a critical performance bottleneck:

**Primary Issue**: The current integration relies on XML file transfers that result in approximately **2 hours of latency** between when a candidate record is created in the ATS and when it becomes available in the onboarding platform.

**Secondary Issues**:
- The XML file extract contains all reporting data used by Insperity, not just onboarding-specific data
- This comprehensive data export creates unnecessary payload size and processing overhead
- The batch-based approach prevents real-time onboarding workflow initiation
- Delayed data availability impacts candidate experience and HR operational efficiency

### Business Impact

- **Delayed Onboarding Initiation**: 2-hour delay in starting onboarding processes affects candidate experience
- **Operational Inefficiency**: HR teams unable to begin onboarding activities immediately after offer acceptance
- **Data Overload**: Processing unnecessary data increases system load and costs
- **Competitive Disadvantage**: Slower time-to-productivity compared to real-time integration solutions

## 4. Solution Architecture

### Webhook-Based Real-Time Integration

**Architecture Overview**: Direct real-time event-driven integration using webhooks to fire events to Insperity-hosted endpoints with API key authentication.

### Integration Flow Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   BrightMove    │    │                 │    │    Insperity    │
│      ATS        │    │   Webhook       │    │   Onboarding    │
│                 │    │  Integration    │    │   Endpoints     │
│  Multi-tenant   │────┼─► Event Firing  ├────┼─► Workato       │
│  AWS Cloud      │    │   API Keys      │    │   Workday       │
│                 │    │   Real-time     │    │   Premier       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Core Components

1. **BrightMove Event Triggers**
   - Candidate offer acceptance events
   - Background check completion events
   - Document signing completion events
   - Onboarding workflow initiation events

2. **Webhook Delivery System**
   - Secure HTTPS endpoint communication with API key authentication
   - Event filtering based on Insperity-defined schema requirements
   - Limited retry logic with hard retry limits
   - Dead Letter Queue (DLQ) with manual recovery process

3. **Insperity Endpoint Infrastructure**
   - Secure webhook receivers with API key validation
   - Schema-based data validation and processing
   - Data routing to appropriate systems
   - Error handling and logging

## 5. Implementation Approach

### Technical Implementation

**BrightMove ATS Modifications**:
- Configure event triggers for onboarding-relevant candidate status changes
- Implement webhook firing mechanism with API key authentication
- Add event filtering based on Insperity-defined schema and data attributes
- Create limited retry logic with hard retry limits and DLQ processing

**Insperity Endpoint Development**:
- Set up secure HTTPS webhook endpoints within Insperity infrastructure
- Implement API key-based authentication (no OAuth 2.0)
- Define schema and required data attributes for selective data transfer
- Create data routing logic to direct events to appropriate systems (Workato, Workday, Premier)
- Add logging and monitoring for webhook receipt and processing

**Data Schema and Payload Design**:
- **Insperity to define** comprehensive schema for onboarding data requirements
- **Insperity to specify** required data attributes for selective data transfer
- Implement field mapping between BrightMove and Insperity-defined data structures
- Create validation rules based on Insperity-provided specifications
- Document webhook event schemas as defined by Insperity

## 6. Functional Requirements

### FR-001: Real-Time Event Processing
- **Requirement**: Process candidate onboarding events in real-time using webhooks
- **Implementation**: Webhook-based event streaming from BrightMove to Insperity
- **Acceptance Criteria**: Events transmitted immediately upon trigger occurrence

### FR-002: Schema-Based Data Transfer
- **Requirement**: Transfer only onboarding-relevant data based on Insperity-defined schema
- **Implementation**: Event filtering and payload optimization per Insperity specifications
- **Acceptance Criteria**: Data payload matches Insperity-defined schema and includes only specified attributes

### FR-003: API Key Authentication
- **Requirement**: Secure webhook communication using API key authentication
- **Implementation**: HTTPS with API key authentication (no OAuth 2.0)
- **Acceptance Criteria**: All webhook communications authenticated via API keys

### FR-004: Limited Retry and Recovery
- **Requirement**: Handle delivery failures with hard retry limits and manual DLQ recovery
- **Implementation**: Limited automated retry attempts with Dead Letter Queue for failed messages
- **Acceptance Criteria**: Failed messages routed to DLQ after maximum retry attempts; manual recovery process available

### FR-005: Multi-System Integration
- **Requirement**: Route webhook events to appropriate Insperity systems
- **Implementation**: Endpoint routing to Workato, Workday, and Premier based on event type
- **Acceptance Criteria**: All target systems receive relevant webhook events according to routing rules

## 7. Non-Functional Requirements

### NFR-001: Security
- **Authentication**: API key-based authentication for webhook endpoints
- **Data encryption**: HTTPS/TLS 1.2+ for all webhook communications
- **Audit logging**: Log all webhook events, responses, and authentication attempts

### NFR-002: Reliability
- **Delivery mechanism**: Best-effort delivery with limited retry attempts
- **Retry handling**: Hard limit on automated retry attempts
- **DLQ processing**: Manual recovery process for messages exceeding retry limits
- **Error handling**: Comprehensive error logging and notification

### NFR-003: Data Integrity
- **Schema validation**: Validate all payloads against Insperity-defined schema
- **Data consistency**: Ensure data accuracy according to defined field mappings
- **Error detection**: Identify and log data validation failures

### NFR-004: Monitoring and Observability
- **Event tracking**: Monitor webhook delivery attempts and outcomes
- **Performance monitoring**: Track system availability and response times
- **Error monitoring**: Alert on delivery failures and authentication issues
- **DLQ monitoring**: Track messages requiring manual recovery

## 8. Project Timeline and Milestones

### 3-Month Implementation Schedule

**Month 1: Foundation and Development (Weeks 1-4)**
- Week 1: Requirements validation, schema definition by Insperity, and technical design
- Week 2: Development environment setup and API key authentication framework
- Week 3: BrightMove webhook trigger development
- Week 4: Initial webhook endpoint development on Insperity side

**Month 2: Integration and Testing (Weeks 5-8)**
- Week 5: Schema-based payload design and data mapping implementation
- Week 6: Limited retry logic and DLQ implementation
- Week 7: Multi-system routing (Workato, Workday, Premier) development
- Week 8: Integration testing and security validation

**Month 3: Deployment and Optimization (Weeks 9-12)**
- Week 9: System testing and validation
- Week 10: User acceptance testing with stakeholders
- Week 11: Production deployment and monitoring setup
- Week 12: Go-live support and documentation completion

### Key Milestones

- **Week 1**: Insperity schema definition completed and technical architecture approved
- **Week 4**: Core webhook infrastructure and API key authentication complete
- **Week 6**: Schema-based data processing and retry logic complete
- **Week 8**: Integration testing passed
- **Week 10**: User acceptance testing complete
- **Week 12**: Production deployment and project completion

## 9. Resource Requirements

### Technical Resources

**BrightMove Team**:
- 1 Senior Developer (0.5 FTE for 3 months)
- 1 DevOps Engineer (0.25 FTE for 3 months)

**Insperity Team**:
- 1 Integration Developer (0.5 FTE for 3 months)
- 1 Solution Architect (0.25 FTE for 3 months)

**Shared Resources**:
- 1 Project Manager (0.25 FTE for 3 months)
- Testing and QA support (ad-hoc)

### Infrastructure Requirements

**BrightMove Infrastructure**:
- Webhook delivery service (existing AWS infrastructure)
- Monitoring and logging tools
- Development and testing environments

**Insperity Infrastructure**:
- Webhook endpoint hosting
- API key management system
- Integration testing environment

## 10. Cost Estimation

### Development Cost Breakdown

**Personnel Costs (3 months)**:
- BrightMove Senior Developer (0.5 FTE): $9,000
- BrightMove DevOps Engineer (0.25 FTE): $3,000
- Project Management (0.25 FTE): $3,000
- **Total Personnel**: $15,000

**Infrastructure Costs**:
- Development/Testing environments: Covered by existing infrastructure
- API key management and security tools: Covered by existing infrastructure
- Monitoring and logging: Covered by existing infrastructure
- **Total Infrastructure**: $0

**Total Project Cost**: $15,000

### Cost Efficiency

The webhook-based approach achieves significant cost efficiency by:
- Leveraging existing infrastructure on both sides
- Focusing on a single, proven integration pattern
- Eliminating need for complex middleware or additional platforms
- Utilizing internal development resources rather than external consultants

## 11. Risk Assessment and Mitigation

### Technical Risks

**Risk 1: Schema Definition Delays**
- *Probability*: Medium
- *Impact*: High
- *Mitigation*: Early engagement with Insperity team for schema definition, clear requirements documentation

**Risk 2: API Key Management and Security**
- *Probability*: Low
- *Impact*: Medium
- *Mitigation*: Implement secure API key generation, rotation, and storage practices

**Risk 3: DLQ Manual Recovery Process**
- *Probability*: Medium
- *Impact*: Medium
- *Mitigation*: Develop clear procedures for manual DLQ processing and staff training

### Business Risks

**Risk 4: Stakeholder Coordination**
- *Probability*: Medium
- *Impact*: Medium
- *Mitigation*: Regular stakeholder meetings, clear communication channels

**Risk 5: Timeline Compression**
- *Probability*: Medium
- *Impact*: Medium
- *Mitigation*: Focused scope, agile development, early testing

## 12. Success Metrics and KPIs

### Primary Success Metrics

**Latency Reduction**
- **Target**: Reduce integration latency from 2 hours to real-time delivery
- **Measurement**: Time from ATS event trigger to webhook delivery
- **Success Criteria**: Events delivered immediately upon trigger

**Data Accuracy**
- **Target**: Accurate data transfer based on Insperity-defined schema
- **Measurement**: Data validation success rate against defined schema
- **Success Criteria**: 100% compliance with Insperity-defined data requirements

**System Reliability**
- **Target**: Reliable webhook delivery with appropriate error handling
- **Measurement**: Successful webhook delivery rate and DLQ utilization
- **Success Criteria**: Minimal message loss with effective DLQ recovery process

### Secondary Success Metrics

**Implementation Success**
- **Target**: Complete project within 3 months and $15,000 budget
- **Measurement**: Project timeline and cost tracking
- **Success Criteria**: On-time, on-budget delivery

**User Experience**
- **Target**: Improved onboarding initiation time
- **Measurement**: Time from offer acceptance to onboarding start
- **Success Criteria**: Significant improvement in onboarding initiation speed

## 13. Monitoring and Maintenance

### Operational Monitoring

**Real-time Metrics**:
- Webhook delivery success rate
- Event processing status
- API key authentication success rate
- DLQ message count and processing status

**Alerting**:
- Failed webhook deliveries
- API key authentication failures
- DLQ threshold alerts
- System downtime notifications

### Maintenance Requirements

**Ongoing Support**:
- Monitor webhook health and delivery status
- Manage API key rotation and security updates
- Handle DLQ manual recovery processes
- Maintain documentation and operational procedures

**Estimated Monthly Maintenance**: 4-8 hours
**Estimated Annual Maintenance Cost**: $2,000-4,000

## 14. Next Steps and Statement of Work

### Immediate Actions Required

1. **Stakeholder Approval**: Obtain formal approval from designated stakeholders
2. **Schema Definition**: Insperity to define comprehensive schema and required data attributes
3. **API Key Infrastructure**: Establish API key management and security protocols
4. **Resource Commitment**: Secure development resources from both teams
5. **Project Kickoff**: Schedule project initiation meeting

### Statement of Work Development

Upon approval of this solution design, a detailed Statement of Work (SOW) will be prepared containing:

**Project Deliverables**:
- Webhook event triggering system in BrightMove ATS
- API key-based authentication infrastructure
- Schema-based data filtering and validation
- Limited retry mechanism with DLQ processing
- Multi-system routing to Insperity endpoints
- Documentation and operational procedures

**Timeline and Milestones**:
- Detailed 12-week project schedule
- Weekly milestone checkpoints
- Schema definition and validation gates
- Testing and validation procedures
- Go-live and support protocols

**Service Level Agreements**:
- Delivery mechanisms and expectations
- Error handling and recovery procedures
- Support and maintenance commitments
- Performance and availability targets

### Approval Process

This solution design requires formal approval from:
- **Insperity**: Hadley Hunter (Integration PM) and Meynard Patacsil (Solution Architect)
- **BrightMove**: Jimmy Hurff (Head of Customer Success) and David Webb (CEO)

## 15. Conclusion

The Insperity Onboarding Data Integration Improvements project provides a focused, cost-effective solution to the current 2-hour latency challenge. By implementing webhook-based real-time integration with API key authentication and Insperity-defined schemas, the solution will:

- **Eliminate current latency**: From 2 hours to real-time delivery
- **Improve data accuracy**: Schema-based validation ensures precise data transfer
- **Enhance security**: API key authentication provides secure communication
- **Deliver within constraints**: 3-month timeline and $15,000 budget

The webhook-based approach with Insperity-defined schemas and API key authentication leverages existing infrastructure while providing a reliable, secure integration pattern. This solution addresses immediate needs while establishing a foundation for future integration enhancements.

---

**Document Control**
- **Version**: 4.0
- **Last Updated**: July 16, 2025
- **Next Review**: Upon stakeholder approval
- **Distribution**: All project stakeholders

**Approval Status**: Pending formal approval from designated stakeholders before proceeding to Statement of Work development. 