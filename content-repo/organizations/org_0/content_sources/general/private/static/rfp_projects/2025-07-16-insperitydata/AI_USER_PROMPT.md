For this project, I want to create a solution design and statement of work.  These two documents will be created sequentially.

The solution design should provide an overall problem statement, a high level design, an outline of fuctional and non-functional requirements and allude to a fortcoming statement of work, which will outline costs and timelines, contingent upon the acceptance of the solution design.

# Stake Holders

Insperity Team
- Hadley Hunter, Integration Product Manager
- Robert Bentz, Onboarding Product Manager
- Meynard Patacsil, Solution Architect
- Karen Millard, ITC Product Manager
- Martha Vera, ITC Product Owner
BrightMove Team
- Jimmy Hurff, Head of Customer Success
- David Webb, CEO & Head of Product

# System Components

Insperity Systems
- **ITC** - branded as Insperity Talent Connect, white-label BrightMove ATS platform
- **Workato** - Insperity-managed iPaaS integration platform
- **Workday** - Insperity-managed ERP platform
- **Premier** - Insperity-managed customer facing portal

BrightMove Systems
- **ATS** - Application Tracking System which is multi-tenant and hosts Insperity's customers within the AWS cloud
- **Wisdom Data Platform** - Fivetran, Snowflake enterprise data warehouse, DBT platform for enterprise reporting

# Current Challenges

- The current integration solution is based on a XML file transfer that results in about 2 hours of latency between when a record is created in the ATS and when its available within the onboarding platform
- The XML file extract has all reporting data in use by Insperity, not just onboarding data
- Insperity would like to receive the onboarding data with less latency

# Solution Path

- Use of webhooks to fire events to Insperity-hosted endpoints in real time
- Use API Keys for security between webhooks and webhook endpoint platform, no oauth 2.0
- Insperity to define schema and required data attributes needed for selective data transfer
- In requirements, don't make any committments to exponential backoff or performance improvements.  For queue retries, there will be a hard limit for automated retry.  If messages go to DLQ a manual shovel will be used to retry after reaching the maximum.

# Scope, Time & Cost Notes

- This project should be completed in 3 months of less
- This project should cost $15,000 or less
