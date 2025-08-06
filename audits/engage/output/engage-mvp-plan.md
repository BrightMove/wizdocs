# Engage MVP Project Plan (Live)

## 1. Current State Analysis

### a. Engage App
- **Frontend:** React/TypeScript, modular component structure (Dashboard, JobDetails, Messaging, SubmittalsTable, etc.).
- **AI/Agentic Features:**
  - SubmittalsTable includes AI agent scoring and summary for candidate submittals, with endpoints like `/agent/recruiter/evaluate`.
  - Messaging and conversation management present, with Twilio SDK integration planned/partially implemented.
- **Authentication:** Context-based, with protected routes.
- **Job and Submittal Management:** Core job and candidate workflows are present.
- **UI:** Modern, responsive, with reusable components.

### b. ATS Product
- **Backend:** Java Spring, robust applicant tracking, job management, and integrations.
- **Integration:** Engage is designed to work alongside ATS, leveraging its data and workflows.
- **No direct evidence of agentic endpoints in ATS, but Engage calls `/agent/recruiter/evaluate` (likely a new or planned microservice or ATS extension).**

### c. AI/Agentic Capabilities
- **Implemented:** AI scoring and summary for submittals, automated application screening, and candidate engagement.
- **Planned:** "Wiz" agent to manage communications, optimize timing/content, and provide a consistent AI presence across all communication channels.
- **Twilio:** Messaging infrastructure for omnichannel communication.
- **AI Philosophy:** AI is a force multiplier, not a workforce reducer. Focus on authenticity, bias, and ethical use. Measured rollout with customer feedback.

### d. Customer Advisory Board (CAB) & Feedback
- **CAB Role:** Regularly reviews product direction, provides feedback on pain points, time-wasters, and engagement challenges.
- **Feedback Incorporated:** Automated status updates, transparent process, personalized communication, collaborative evaluation tools, and priority alignment.
- **Quality Metrics:**
  - False Positive Rate (FPR) < 5%
  - False Negative Rate (FNR) < 3%
  - Consistency Rate (CR) > 95%
  - Advanced metrics: decision distribution, bias detection, time-to-decision, human agreement rate, predictive validity
- **Evaluation Criteria:** Job duties, tech skills, soft skills, related activities, professional associations, location.

---

## 2. MVP Scope & Features

### a. Core MVP Features
1. **User Authentication & Authorization**
   - Secure login, session management, and role-based access.
2. **Dashboard**
   - Overview of jobs, submittals, and recent activity.
3. **Job Management**
   - List, view, and manage job requisitions.
4. **Submittal Management**
   - List, view, and manage candidate submittals.
   - AI agent scoring and summary for each submittal, using CAB-defined quality metrics and evaluation criteria.
5. **Messaging & Conversations**
   - Twilio-powered messaging (SMS, email, chat).
   - Conversation threads per job/candidate.
   - UI for viewing and sending messages.
6. **AI/Agentic Capabilities**
   - "Wiz" agent for submittal evaluation and communication management (partially implemented, ongoing improvements).
   - Foundation for future agentic features (e.g., automated candidate outreach, interview scheduling, GenAI for email content).
7. **Notifications**
   - Real-time or near-real-time notifications for key events (new submittal, message, etc.).
8. **Basic Admin/Settings**
   - User profile, notification preferences, and basic configuration.

### b. Non-Functional MVP Requirements
- **Cloud-ready deployment (Docker, CI/CD).**
- **Incremental cost tracking for AI usage (usage-based billing).**
- **Usage analytics and basic reporting.**
- **Accessibility and responsive design.**
- **Ethical AI:** Bias monitoring, transparency, and explainability in AI decisions.

---

## 3. Release & Delivery Plan

### a. Milestones & Timeline
| Milestone                        | Target Date   | Key Deliverables                                      |
|-----------------------------------|---------------|-------------------------------------------------------|
| Project Kickoff & Planning        | 1/15/2025     | Finalized plan, team alignment                        |
| Core Architecture & Auth          | 2/15/2025     | Auth, routing, CI/CD, base UI                         |
| Job & Submittal Management        | 3/15/2025     | Job list/details, submittal list/details              |
| Messaging Infrastructure (Twilio) | 4/15/2025     | Messaging UI, Twilio integration, conversation flows  |
| AI Agentic MVP (Wiz)              | 6/1/2025      | AI scoring, summary, agentic API foundation           |
| Internal MVP Demo                 | 8/1/2025      | End-to-end demo, feedback loop                        |
| Public MVP Release                | 9/1/2025      | MVP live, feedback collection, support plan           |

### b. Release Cadence
- **Bi-weekly sprints** with demos and retros.
- **Monthly minor releases** for new features/AI capabilities.
- **Hotfixes as needed.**

---

## 4. Key Risks & Mitigations
- **AI/Agentic Backend Gaps:** No clear backend for `/agent/recruiter/evaluate`—ensure this is prioritized early.
- **Twilio Integration:** Validate messaging flows and compliance.
- **Data Integration with ATS:** Ensure robust, secure data sync.
- **AI Cost Management:** Implement usage tracking and cost controls from the start.
- **Ethical AI:** Ongoing monitoring for bias, transparency, and explainability.

---

## 5. Keeping the Plan Live: Continuous Feedback & Adaptation
- **CAB Reviews:** Schedule regular (quarterly or more frequent) Customer Advisory Board reviews to assess progress, gather feedback, and reprioritize features.
- **Customer Feedback Loops:** Integrate in-app feedback mechanisms and direct customer interviews to capture real-world usage and pain points.
- **Release Metrics:** Track and publish key metrics (release frequency, AI quality metrics, user engagement, support tickets) to inform planning.
- **Dynamic Roadmap:** Adjust priorities and timelines based on CAB/customer feedback, market changes, and technical discoveries.
- **Transparent Communication:** Share roadmap updates, release notes, and key decisions with all stakeholders.
- **Ethical Oversight:** Regularly review AI outputs for bias, fairness, and compliance with ethical standards.

## 6. Airflow: Data-Driven Feedback & Automation

Airflow is a core part of the BrightMove infrastructure and will be leveraged to keep the Engage MVP plan live, data-driven, and responsive:

- **Job Orchestration:** Airflow schedules and runs ETL and analytics jobs, aggregating Engage and ATS data from Oracle, Snowflake, and other sources for business intelligence and reporting.
- **Data-Driven Feedback Loops:** Airflow automates the extraction and summarization of Engage usage, AI scoring, CAB/customer feedback, and release metrics. This data is used to inform regular reviews and roadmap adjustments.
- **AI Monitoring & Retraining:** Airflow schedules evaluation of AI agent performance (FPR, FNR, CR, bias, etc.) and can trigger retraining or tuning jobs as needed. Automated reporting ensures transparency and ethical oversight.
- **Release & Adoption Metrics:** Airflow orchestrates the collection of release frequency, feature adoption, and user engagement metrics for review by the CAB and stakeholders.
- **Compliance & Audit:** Regular data quality, compliance, and audit jobs are scheduled to ensure ethical AI and regulatory requirements are met.
- **Extensibility:** New workflows (e.g., AI model retraining, feedback analytics, Engage-specific reporting) can be added as the product evolves.

By integrating Airflow into the Engage feedback and analytics loop, the plan remains actionable, measurable, and continuously improved based on real data and stakeholder input.

---

## Appendix: Analysis Process & Gaps

- **Codebase, documentation, and CAB/customer feedback were reviewed for current features, AI/agentic logic, and integration points.**
- **No direct evidence of the backend implementation for agentic endpoints—this is a critical gap.**
- **Twilio and AI agent features are present in the frontend, but backend and operational details need confirmation.**
- **Assumptions:** Engage will continue to leverage ATS for core data, and agentic features will be delivered as microservices or ATS extensions.
- **Plan will be updated after each CAB review and major release.** 