# Statement of Work (SOW): Insperity BrightMove-WorkDay SSO Integration

## 1. Project Title

**Insperity BrightMove-WorkDay SSO Integration**

## 2. Purpose

To implement SAML 2.0-based Single Sign-On (SSO) integration between Insperity's WorkDay environment and the BrightMove ATS platform, enabling secure, seamless user authentication and access. This project will extend the existing SSO solution, which currently supports Insperity SSO, to also support WorkDay as an additional SAML Identity Provider (IdP), ensuring both systems can coexist and serve their respective user bases. The Insperity Employee Service Center (ESC) portal is the primary service provider through which end users will launch into BrightMove via SSO.

## 3. Scope of Work

### 3.1. Requirements

- Integrate WorkDay as a SAML 2.0 Identity Provider (IdP) for BrightMove.
- Maintain and support the existing Insperity SSO integration, including SSO flows initiated from the Insperity ESC portal.
- Configure BrightMove to accept and validate SAML assertions from both WorkDay and Insperity IdPs.
- Map SAML attributes from both IdPs to BrightMove user and company records.
- Support x509 certificate management for SAML signature validation for both IdPs.
- Provide configuration and documentation for ongoing support.

### 3.2. Deliverables

- **Technical Design Document** (High Level Design) referencing both current and future SSO coexistence
- **SAML SSO Integration** between WorkDay and BrightMove, coexisting with Insperity SSO and ESC portal flows
- **Configuration of SAML endpoints and certificates** for both IdPs
- **Attribute mapping** from both WorkDay and Insperity to BrightMove user model
- **End-to-end testing** in QA and Production environments for both SSO flows (including ESC portal)
- **User and admin documentation** for SSO login and troubleshooting (covering both IdPs and ESC portal)
- **Support for go-live and post-launch stabilization**

### 3.3. Out of Scope

- Changes to WorkDay's or Insperity's SAML implementation (handled by Insperity/WorkDay team)
- Non-SAML authentication methods

## 4. Roles and Responsibilities

| Role                | Responsibility                                      |
|---------------------|-----------------------------------------------------|
| Insperity           | Provide WorkDay and Insperity SSO metadata, test users, and support; maintain ESC portal integration |
| BrightMove Team     | Implement, configure, and test SSO integration for both IdPs and ESC portal |
| WorkDay Admins      | Configure SAML link and attributes in WorkDay       |
| ESC Admins          | Support SSO launch and user experience from the ESC portal |

## 5. Timeline

| Phase                | Dates (TBD)         |
|----------------------|---------------------|
| Requirements & Design| [Date] - [Date]     |
| Implementation       | [Date] - [Date]     |
| Testing              | [Date] - [Date]     |
| Go-Live              | [Date]              |
| Post-Go-Live Support | [Date] - [Date]     |

## 6. Acceptance Criteria

- Users can log in to BrightMove via either WorkDay SSO or Insperity SSO in QA and Production.
- SAML assertions from both IdPs are validated and mapped to correct users.
- All security and compliance requirements are met.
- Documentation is delivered and reviewed.

## 7. Coexistence and Future State

- The solution must support coexistence of both WorkDay and Insperity SSO integrations.
- BrightMove will accept SAML assertions from both IdPs, with configuration and attribute mapping for each.
- User experience and support processes will cover both SSO flows.

## 8. Assumptions

- WorkDay and Insperity SSO metadata and certificates are provided in advance.
- Test users and access to both WorkDay and Insperity environments are available.
- No major changes to existing SAML SSO infrastructure are required, only extension for coexistence.

## 9. Risks & Mitigations

- **Certificate issues:** Early coordination for x509 exchange and renewal for both IdPs.
- **Attribute mapping errors:** Thorough testing with real user data from both systems.
- **User provisioning mismatches:** Clear documentation and support for user mapping.

## 10. Signatures

| Name                | Title                        | Date       |
|---------------------|------------------------------|------------|
| [Insperity Rep]     | [Title]                      | [Date]     |
| [BrightMove Rep]    | [Title]                      | [Date]     |

</rewritten_file> 