# High Level Design (HLD): Insperity BrightMove-WorkDay SSO Integration

## 1. Overview

The goal of this initiative is to enable Single Sign-On (SSO) integration between Insperity's WorkDay environment and the BrightMove ATS platform, leveraging SAML 2.0. This will allow users to authenticate via WorkDay and seamlessly access BrightMove, improving user experience and security.

## 2. Existing SSO Solution

BrightMove currently supports SSO integration with Insperity systems using SAML 2.0. The existing solution allows Insperity users to authenticate via Insperity's IdP and access BrightMove. This integration includes:
- SAML 2.0 protocol with HTTP-POST binding
- x509 certificate-based signature validation
- Attribute mapping for Insperity-specific user and company identifiers
- Session management and user provisioning logic

## 3. Actors and Systems

- **WorkDay (IdP):** Identity Provider, initiates SAML SSO and issues SAML assertions.
- **Insperity SSO (IdP):** Existing Identity Provider for Insperity users.
- **Insperity ESC (Employee Service Center) (SP):** Service provider portal that provides information and services to Insperity employees. This is the portal through which end users launch into BrightMove via SSO.
- **BrightMove ATS (SP):** Service Provider, consumes SAML assertions and authenticates users.
- **Insperity:** Customer organization, manages users in WorkDay and BrightMove.
- **End Users:** Employees, managers, and admins accessing BrightMove via WorkDay SSO or Insperity SSO (typically through the Insperity ESC portal).

## 4. SSO Flow

### TODO for Dave: What open questions do we have here?

1. **User initiates login** from either WorkDay (IdP) or Insperity ESC (which uses Insperity SSO as IdP).
2. **IdP generates a SAML 2.0 assertion** (signed with x509 private key) and posts it to BrightMove's SAML endpoint.
3. **BrightMove receives the SAML assertion** at a dedicated endpoint (e.g., `/auth/saml`).
4. **BrightMove parses and validates** the SAML response:
   - Validates signature using the IdP's public x509 certificate (WorkDay or Insperity).
   - Extracts user attributes (e.g., WorkDay Identifier, Insperity Employee ID, Email).
   - Maps SAML attributes to BrightMove user/company records.
5. **User session is established** in BrightMove, and the user is redirected to the appropriate landing page.

## 5. Technical Architecture

- **SAML 2.0 HTTP-POST Binding** is used for assertion delivery.
- **Endpoints:**
  - Assertion Consumer Service (ACS): `/auth/saml` (existing in BrightMove)
- **Certificate Management:**
  - Both WorkDay's and Insperity's x509 public certificates must be configured in BrightMove for signature validation.
  - Key rotation and renewal processes must be documented for both IdPs.
- **Attribute Mapping:**
  - SAML attributes from both WorkDay and Insperity are mapped to BrightMove's user model.
  - Required attributes: WorkDay Identifier, Insperity Employee ID, Email, Company ID (if applicable).

### Attribute Mapping Table

### TODO for Dave: What open questions do we have here?

| System/Actor         | EmployeeID Variable                | CompanyID Variable                | GKID Variable         | APIKey Variable         |
|----------------------|------------------------------------|-----------------------------------|-----------------------|------------------------|
| WorkDay (IdP)        | `Workday Identifier`               | `Company Reference`               | N/A                   | N/A                    |
| Insperity SSO (IdP)  | `EmployeeID` (AIMS)                | `CompanyID` (AIMS)                | N/A                   | `APIKey`               |
| Insperity ESC (SP)   | Pass-through from Insperity SSO    | Pass-through from Insperity SSO   | N/A                   | Pass-through           |
| BrightMove ATS (SP)  | `employeeId` (user model field)    | `companyId` (company model field) | `userGK` (user key)   | `apiKey` (company key) |

- **Session Management:**
  - On successful authentication, user session is created using existing BrightMove session logic.
  - Existing SAML session handling (as used for Azure/Insperity) is leveraged.

## 6. Coexistence and Future State

The future state must support coexistence of both WorkDay and Insperity SSO solutions. This means:
- BrightMove will accept SAML assertions from both WorkDay and Insperity IdPs.
- User provisioning, attribute mapping, and session management logic will support both sources.
- Configuration will allow for multiple IdPs, each with their own certificates and attribute mappings.
- The user experience will be seamless regardless of which IdP is used for authentication.

## 7. Integration with Existing Codebase

- **Reuses SAML SSO infrastructure** in `brightmove-ats`:
  - Controllers: `AuthenticationController`, `AzureSamlController`
  - Services: `AuthenticationService`, `AzureAuthenticationService`
  - SAML parsing and validation via OpenSAML.
- **Extensibility:**
  - WorkDay is added as a new SAML IdP, coexisting with Insperity.
  - Configuration-driven: new IdP metadata, certificates, and attribute mappings can be added without code changes.
- **Error Handling:**
  - Signature, attribute, and user mapping errors are logged and surfaced to the user as appropriate.
  - Fallbacks and support for troubleshooting are in place.

## 8. Security Considerations

- **All SAML assertions must be signed** and validated.
- **Only trusted IdPs (WorkDay, Insperity) are allowed**; configuration is restricted to admin users.
- **Sensitive data in SAML assertions** is handled per security best practices.
- **Audit logging** for SSO events is enabled.

## 9. User Experience

- **Seamless login** from either WorkDay or Insperity SSO to BrightMove.
- **Error messages** are user-friendly and actionable.
- **Support for multiple SSO providers** (Azure, Insperity, WorkDay) is maintained.

## 10. Deployment & Configuration

- **WorkDay and Insperity SSO metadata and certificates** are provided by Insperity/WorkDay and configured in BrightMove.
- **Testing in QA and Production** environments before go-live.
- **Documentation** for support and troubleshooting is updated. 