# Company Details

BrightMove is a software company headquartered in Florida.  Our #1 goal is to build software that our customers love to use.  Our employees work all over the country and our customers are primarily US-based companies.

BrightMove has a core product called ATS.  This is a robost applicant tracking system for staffing agencies, HR departments, RPOs and PEOs.  ATS is written in Java Spring.  The source code is located in the apps/brightmove-ats subdirectory.

BrightMove has a critical product called JobGorilla.  JobGorilla is incorporated into the ATS service as part of the subscription fee for subscribers.  JobGorilla is an application that is used to manage the distribution of jobs to remote job boards, like Indeed, LinkedIn and others.  The source code is located in the apps/jobgorilla subdirectory.

BrightMove has a modern data platform called Wisdom.  This is data stack that includes a cloud-based enterprise data warehouse hosted in Snowflake.  BrightMove uses Fivetran to replicate data from AWS-hosted SQL database into Snowflake.  Airflow is responsible for job orchestration which runs DBT jobs to create an analytics databases called RECRUITING.PUBLIC within the Snowflake environment.  Some enterprise users have single-tenant enterprise data warehouse instances hosted in Snowflake and exclusively serving their company's data.  In these cases, their warehouse databases are also populated using DBT.  BrightMove uses Sigma to create interactive dashboards and visualizations against the Snowflake-hosted data for analytics.  The source code for the DBT projects is located in the apps/etl directory

BrightMove uses Airflow for job scheduling and monitoring.  This is a key part of our infrastructure and where many business rules related scheduling are recorded.  The source code is located in app/airflow-dags.

BrightMove has an add-on product called BrightSync.  This application allows a subscribed customer to connect their ATS account to Microsoft Office 365 for integrated messaging and calendar support.  The source code is located in the apps/bright-sync subdirectory.

BrightMove has an emerging product called Engage. Engage is solution that is based on an AI Agentic strategy to streamline the hiring process has an agent named Wiz that monitors and manages all communication channels optimizes communication timing and content using natural language provides a consistent, authentic AI presence across the entire graph has an incremental cost based on usage, like ChatGPT and others.  We intend to use Twilio SDK for all messaging and conversation management.  The source code is located in the apps/engage-app subdirectory.
