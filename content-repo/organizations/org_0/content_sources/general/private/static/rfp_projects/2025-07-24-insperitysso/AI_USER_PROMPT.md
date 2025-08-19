For this project, I want to create a solution design and statement of work.  These two documents will be created sequentially.

Use the input folder and the PDF file with the email thread to compose a solution based on discussions to date.

The solution design should provide an overall problem statement, a high level design, an outline of fuctional and non-functional requirements and allude to a fortcoming statement of work, which will outline costs and timelines, contingent upon the acceptance of the solution design.  

# Stake Holders

Insperity Team
- Karen Millard, ITC Product Manager
- Martha Vera, ITC Product Owner
- Kaysie McCormick, Insperity Enterprise Project Manager
- Eugene Chang, Workday Solution Architect
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

# Current Challenges

- The current SSO solution connects Insperity Premier using SAML.  This was implemented in 2011
- The new Workday platform needs to be integrated with ATS.
- Insperity wishes to have both systems integrated with ATS via SSO.  They will need to coexist and run concurrently

# Solution Path

- Use of SAML for SSO
- Ensure there is no adverse impact to the current SSO integration between Insperity and BrightMove
- Insperity & Workday has agreed on a plan to map the Workday EMPLOYEE ID to the BrightMove ATS userGK
- The AIMS ID and Company GK will not be present in the Workday SSO assertion, only the userGK.  Premier send these values, so ATS will need to effectively deal with this difference.
- The userGk assertion will not be encrypted.  Workday does not support PGP encryption of assertions, so ATS will need to effectively deal with this difference.
- The work on the BrightMove side will be performed by a single BrightMove developer

# Scope, Time & Cost Notes

- This time to create and test the software changes to ATS is 1 month or less
- This project cost is estimated at $2,000
- Testing support from Workday and Insperity will be needed to validate this new functionality
