
# BRIGHTMOVE COLORADO UNIVERSITY RFP - FINAL GAPS ANALYSIS
## For Review with Mike Brandt (Based on Exact COMPANY-DETAILS.md)

### CRITICAL GAPS IDENTIFIED

#### 1. AI-Powered Interview Scheduling (F.125)
**Status:** Does Not Meet
**Impact:** High - This is a specific requirement for AI-powered interview scheduling automation
**Current State:** BrightMove handles interview scheduling through standard calendar integration and manual coordination via BrightSync Office 365 integration
**Potential Solution:** This could potentially be addressed through future Engage platform enhancements with AI agent Wiz
**Action Required:** 
- Confirm if AI-powered interview scheduling exists in Engage platform roadmap
- If not, determine if this is a deal-breaker for CU
- Consider if this can be addressed through integration partners

### DOCUMENTED CAPABILITIES (EXACT FROM COMPANY-DETAILS.MD)

#### Core ATS Product
- **Technology:** Java Spring-based robust applicant tracking system
- **Target Markets:** Staffing agencies, HR departments, RPOs, and PEOs
- **Source Code:** Located in apps/brightmove-ats subdirectory
- **Functionality:** Complete applicant tracking with activity recording, notes, files, and details about applicants, jobs, hiring managers, submittals, offers, placements, and communications

#### JobGorilla (Critical Product)
- **Inclusion:** Incorporated into ATS service as part of subscription fee
- **Function:** Manages distribution of jobs to remote job boards (Indeed, LinkedIn, and others)
- **Source Code:** Located in apps/jobgorilla subdirectory
- **Note:** This is the primary job distribution tool, not built-in sourcing

#### Wisdom Data Platform
- **Architecture:** Cloud-based enterprise data warehouse hosted in Snowflake
- **Data Replication:** Fivetran for AWS-hosted SQL database to Snowflake replication
- **Job Orchestration:** Airflow responsible for job orchestration running DBT jobs
- **Analytics Database:** RECRUITING.PUBLIC within Snowflake environment
- **Enterprise Options:** Single-tenant enterprise data warehouse instances for exclusive company data
- **Business Intelligence:** Sigma for interactive dashboards and visualizations
- **Embedding:** Standard and custom Sigma dashboards embedded into ATS using secure embedding
- **Data Access:** Available to ATS users with permission to access dashboards
- **Data Source:** Curated and aggregated data from RECRUITING.PUBLIC database and schema
- **Insight Types:** Operational, marketing, and financial (time to hire, time to fill, candidate source attribution, job board effectiveness)
- **Data Marts:** Dozens providing complete views of applicants, resumes, recruiters, hiring managers, jobs, departments, locations, submittals, offers, placements, and communications

#### Airflow Infrastructure
- **Purpose:** Job scheduling and monitoring
- **Role:** Key part of infrastructure where business rules related to scheduling are recorded
- **Source Code:** Located in app/airflow-dags

#### BrightSync Add-on Product
- **Function:** Connect ATS account to Microsoft Office 365 for integrated messaging and calendar support
- **Source Code:** Located in apps/bright-sync subdirectory
- **Note:** This is an add-on product, not included in base subscription

#### Engage Emerging Product
- **Strategy:** AI Agentic strategy to streamline hiring process
- **AI Agent:** Named Wiz that monitors and manages all communication channels
- **Capabilities:** Optimizes communication timing and content using natural language
- **Presence:** Provides consistent, authentic AI presence across entire graph
- **Pricing:** Incremental cost based on usage (like ChatGPT and others)
- **Technology:** Intends to use Twilio SDK for all messaging and conversation management
- **Source Code:** Located in apps/engage-app subdirectory
- **Status:** Emerging product (not fully mature)

### QUESTIONS FOR MIKE

#### 1. Engage Platform Maturity
- What is the current development status of the Engage platform?
- What specific AI capabilities does Wiz currently have vs. planned features?
- What are the usage-based pricing details for Engage?
- Is AI-powered interview scheduling in the Engage platform roadmap?

#### 2. Wisdom Analytics for Higher Education
- What specific analytics capabilities does Wisdom provide for higher education institutions?
- What are the differences between standard Wisdom and single-tenant enterprise instances?
- What reporting templates are available for EEO/OFCCP compliance?
- What are the data refresh rates and latency for real-time reporting?

#### 3. Integration Capabilities
- What HRIS/ERP systems does BrightMove currently integrate with?
- What background check providers are supported beyond HireRight?
- What video interviewing platforms are supported?
- What are the costs for BrightSync add-on product?

#### 4. Implementation and Support
- What is the typical implementation timeline for a university with Wisdom?
- What training and support services are included for Engage platform?
- What customization capabilities exist for the ATS product?
- What are the limits of white-labeling for university branding?

### RECOMMENDATIONS

#### 1. Immediate Actions
- Schedule call with Mike to review this final gaps analysis
- Get clarification on Engage platform maturity and roadmap
- Determine Wisdom analytics requirements for CU
- Identify BrightSync integration needs and costs

#### 2. Response Strategy
- Emphasize the robust Java Spring-based ATS as the core solution
- Highlight Wisdom analytics platform as a major differentiator
- Be transparent about Engage platform as an emerging product
- Propose realistic timeline for AI-powered features

#### 3. Risk Mitigation
- Don't over-promise on Engage platform capabilities
- Focus on proven ATS and Wisdom strengths
- Be transparent about add-on product costs
- Propose realistic solutions for gaps

### NEXT STEPS

1. **Review with Mike:** Go through this final gaps analysis together
2. **Clarify Capabilities:** Get definitive answers on all product capabilities
3. **Assess Impact:** Determine which gaps are critical for CU
4. **Develop Strategy:** Create plan to address or work around gaps
5. **Update Response:** Revise RFP response based on clarified capabilities

### CONTACT INFORMATION
- **Mike Brandt:** Head of Alliances, Inovium
- **Email:** michael.brandt@inovium.com
- **Phone:** [Need to confirm]
- **Meeting Request:** Schedule 1-hour call to review final gaps analysis

---
*This analysis is based on exact content from COMPANY-DETAILS.md and should be verified with Mike before finalizing the RFP response.*
