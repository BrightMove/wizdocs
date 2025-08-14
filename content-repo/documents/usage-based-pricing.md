# Usage-Based Billing Requirements

For an overview of usage-based pricing models, see [Pricing Models](pricing-models.md) and [SKU Catalog Structure](sku-catalog-structure.md). For partner/white label requirements, see [Partner/White Label Pricing](pricing-models.md#6-partnerwhite-label-pricing).

## Functional Requirements

1. **Product Catalog & SKU Management**
   - Admins can define usage-based products (e.g., SMS, AI tokens, job sponsorships) as SKUs.
   - Each SKU supports batch (prepaid) and overage (pay-as-you-go) pricing.
   - SKUs can be assigned to customers, including partner/white-label accounts.

2. **Purchase & Allocation**
   - Customers can purchase batches of usage units (e.g., 1,000 SMS).
   - System allocates purchased units to the customer’s account.
   - Batches have an expiration date (“use it or lose it”).

3. **Usage Tracking**
   - System tracks consumption of each usage-based product per customer.
   - Real-time decrement of available units as usage occurs.
   - Overage is automatically tracked and billed at the overage rate.

4. **Billing & Invoicing**
   - Monthly (or custom period) invoices include:
     - Batch purchases (prepaid)
     - Overage charges (if any)
     - Expired/unused units are not refunded
   - Invoices are itemized by SKU and usage type.
   - Support for both credit card and invoice billing.

5. **Notifications & Alerts**
   - Customers receive alerts as they approach batch limits (e.g., 80%, 100%).
   - Admins can configure alert thresholds.
   - Customers are notified of overage charges and batch expirations.

6. **Self-Service Portal**
   - Customers can view current usage, remaining units, and purchase history.
   - Customers can top up (buy more units) or upgrade to larger batches.
   - Partners can view and manage their own sub-accounts.

7. **Partner/White Label Support**
   - Partners can purchase usage in bulk and allocate to their customers.
   - Partner pricing and margin logic is supported.
   - Partner usage is tracked separately from retail.
   - See [Partner/White Label Usage-Based Pricing](#partnerwhite-label-usage-based-pricing) for more details.

8. **Reporting & Analytics**
   - Admins can generate reports on usage, revenue, overage, and margin by SKU, customer, and partner.
   - Exportable data for finance and operations.

## Non-Functional Requirements

1. **Performance**
   - Usage tracking and decrementing must occur in real-time or near real-time.
   - System must support high transaction volumes (e.g., thousands of SMS per minute).

2. **Reliability & Availability**
   - 99.9% uptime for billing and usage tracking components.
   - No loss of usage data, even during outages (durable event logging).

3. **Security**
   - All billing and usage data must be encrypted at rest and in transit.
   - Role-based access control for admin, partner, and customer views.
   - PCI compliance for credit card processing.

4. **Scalability**
   - System must scale horizontally to support growth in customers and usage events.
   - Batch and overage logic must work for both small and enterprise customers.

5. **Auditability**
   - All usage events, purchases, and billing actions are logged and auditable.
   - Ability to reconstruct usage and billing history for any customer.

6. **Extensibility**
   - New usage-based products/SKUs can be added without code changes (config-driven).
   - Pricing tiers and overage rates can be updated without downtime.

7. **Integration**
   - Integrates with accounting (e.g., QuickBooks) and payment gateways.
   - API endpoints for partners to automate usage reporting and top-ups.

8. **Localization & Compliance**
   - Support for multiple currencies and tax rules.
   - Compliance with relevant financial regulations (e.g., SOX, GDPR).

---

# Usage-Based Pricing for BrightMove

## Overview
Usage-based pricing allows customers to purchase a batch of units ("use it or lose it") and pay for overages if they exceed their allocation. This model is ideal for:
- **SMS Messages**
- **AI Tokens** (for agentic workflows)
- **Job Sponsorships** (Indeed, Monster, ZipRecruiter)

## Model Structure
- **Bulk Purchase:** Customers buy a batch of units at a discount (e.g., 1,000 SMS, 10,000 AI tokens)
- **Overage:** If usage exceeds batch, overage is charged at a higher per-unit rate
- **Expiration:** Batches expire after a set period (e.g., 30/90 days)
- **Arbitrage:** BrightMove buys in larger bulk, resells in smaller units with margin

## Example
- **SMS:** $0.04/SMS in 1,000 batch, $0.06/SMS overage
- **AI Tokens:** $10/10,000 tokens, $1.50/1,000 overage
- **Job Sponsorships:** $100/10 jobs, $15/job overage

## Best Practices
- Make overage rates and batch expiration clear
- Allow self-service top-up and overage tracking
- Track COGS and margin per SKU
- Automate usage alerts and billing

## Partner/White Label Usage-Based Pricing
- Partners may receive discounted rates on usage-based products (SMS, AI, job sponsorships) to allow for their own margin.
- Partner usage is tracked separately from retail customers.
- Implementation/onboarding fees may apply for partners when launching new usage-based products.

---

*See also: [pricing-models.md](pricing-models.md), [sku-catalog-structure.md](sku-catalog-structure.md)* 