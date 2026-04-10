# YGSF Contract Management System - User Guide

## 1. System Overview

The YGSF Contract Management System is a custom Salesforce application built for the **YMCA of Greater San Francisco (YGSF)**. It digitizes and enforces the YGSF Contract Policy (Effective September 2025) and Contract Procedures, providing:

- **Contract entry and submission** with guided intake wizards
- **Automated approval routing** based on contract subject, type, and value
- **Legal review tracking** with SLA monitoring
- **Insurance compliance** (COI and endorsement tracking)
- **Signature tracking** for all required signatories
- **Renewal management** with expiration alerts
- **Policy enforcement** through validation rules
- **Reporting and dashboards** for contract portfolio visibility

---

## 2. Getting Started

### Accessing the Application
1. Log into Salesforce
2. Click the App Launcher (grid icon, top-left)
3. Search for and select **"YGSF Contract Management"**

### Navigation
The app includes these tabs:
- **YGSF Contracts** - Main contract list with pre-built views
- **Contract Documents** - All tracked documents (COI, endorsements, etc.)
- **Contract Renewals** - Renewal history and tracking
- **Reports** / **Dashboards** - Contract analytics

### Pre-Built List Views
| View | Description |
|------|-------------|
| All Contracts | Every contract in the system |
| My Contracts | Contracts where you are the Staff Liaison |
| Pending Legal Review | Contracts awaiting legal review |
| Pending Signatures | Contracts awaiting internal/external signatures |
| Active Contracts | Currently active contracts |
| Expiring Soon | Contracts approaching their end date |

### Permission Sets

| Permission Set | Role | Access Level |
|---|---|---|
| `YGSF_Contract_Full_Access` | System Administrator | Full CRUD on all objects and fields |
| `YGSF_Contract_Legal_Reviewer` | Legal Department staff | Read/Edit contracts, full access to legal review fields |
| `YGSF_Contract_Officer` | CEO, CPO, CFO, COO | Read/Edit contracts, approve as Association Officer |
| `YGSF_Contract_SVP` | Senior Vice Presidents | Read/Edit contracts, approve at SVP level |
| `YGSF_Contract_VP` | Vice Presidents | Read/Edit contracts, approve at VP level |
| `YGSF_Contract_Branch_ED` | Branch Executive Directors | Read/Edit branch contracts, create documents, approve |
| `YGSF_Contract_Staff_Liaison` | Staff submitting contracts | Create/Edit own contracts (Draft/Rejected only), manage documents |
| `YGSF_Contract_View_Only` | General read-only access | Read all contracts and related records |
| `YGSF_Contract_Finance` | Finance/Accounting team | Read contracts, edit payment and CFO approval fields |

---

## 3. Contract Types (Record Types)

When creating a contract, select the appropriate record type based on Section 2 of the YGSF Contract Policy:

| Record Type | Description |
|---|---|
| **Grant** | Financial award from a funding entity (government agency, foundation) for a specific program |
| **Service Agreement** | Contract where one party compensates YGSF for full-scale program/service delivery (e.g., School District agreements) |
| **Memorandum of Understanding (MOU)** | Agreement outlining terms for a mutual project or goal between two or more parties |
| **Independent Contractor Agreement (ICA)** | Contract with a service provider/contractor for delivery of services |
| **ICA Addendum** | Modification or renewal of an existing ICA |
| **Facility Lease** | Lease for property (landlord/tenant arrangement) |
| **Equipment Lease** | Lease for specific equipment for a set period |
| **Facility License** | Non-exclusive rights to occupy and use property |
| **Maintenance Agreement** | Ongoing maintenance and support of equipment, property, or systems |
| **Construction Contract** | Agreement for construction work including scope, payment, schedule, and quality |
| **Engagement Letter** | Formal agreement for professional services (audits, accounting, legal) |
| **Facility Use Agreement** | Non-exclusive use of YGSF facility space by a non-profit or individual |
| **User Group Agreement** | Camp Jones Gulch programming and overnight facility use |

---

## 4. Contract Subjects & Rules Engine

The system includes **39 pre-configured contract subjects** that automatically determine:
- Which **approval path** to follow (Sections 3.2.1 - 3.2.4)
- Whether **legal review** is required before or after execution
- Which **signatories** are required (Officer, SVP, VP, ED)
- Whether **Certificate of Insurance (COI)** must be collected
- Whether **Additional Insured Endorsement** must be collected
- Whether an **ICA Approval Form** is needed
- Which **YGSF template** to use

### Section 3.2.1 Subjects (Legal Before + Officer + SVP)
These are the highest-risk contracts requiring Legal Department review before execution, plus signatures from both a Senior VP and an Association Officer (CEO/CPO/CFO/COO):

Alcohol Service, Bus/Transportation Service, Business Associate Agreement, Consultant Agreement, Exchange of Employee/Member Data, Fiduciary Management Services, Fiscal Sponsorship, Grant Funded Contractor or Services, Independent Contractor (Professional), Independent Contractor (Youth), Legal Services, NDA, PII/HIPAA Related Contract, Professional Services, Property Lease/License/Rental, School District Service Agreement/MOU, Software as a Service (SaaS), Unique/Novel Program or Services, Youth Program Services

### Section 3.2.2 Subjects (Legal Before + SVP + VP)
Moderate-risk contracts requiring Legal review before execution, with SVP and VP signatures (VP may delegate to Branch ED/Facilities ED):

Bounce House/Stage/Tent, Health Screening/Medical Service, Internship/Affiliation/Placement, Photographer, Security Service, Staffing Service

### Section 3.2.3 Subjects (ED + VP; Legal After for <= $10K)
Lower-risk contracts that can be signed by Branch ED and VP without prior Legal review when $10,000 or less. **If the contract value exceeds $10,000, these automatically escalate to Section 3.2.1 rules.**

Auctioneers, Construction, Equipment/Furniture Rental, Event Production, Food Service/Catering, Grant Agreement, Hotel/Conference/Venue Rental, Maintenance Agreement, Musicians/DJs/Entertainers/Emcees, PTA Agreement for Enrichment, Staff Training, Workforce Development

### Section 3.2.4 Subjects (Branch ED Only)
Lowest-risk contracts that can be signed solely by the Branch Executive Director with no Legal Department review:

Facility Use Agreement, User Group Agreement

---

## 5. Contract Lifecycle

### Creating a New Contract

1. **Navigate** to the YGSF Contracts tab
2. **Click "New"** and select the appropriate Record Type
3. **Fill in required fields**:
   - Contract Title
   - Contract Subject (this triggers the rules engine)
   - Contract Type
   - Contract Value
   - Start Date / End Date
   - Counterparty information
   - Staff Liaison (yourself)
   - Location (YGSF branch/facility)
   - Branch Executive Director, VP, SVP, Officer approvers as applicable
4. **Save** the contract in Draft status

### Status Progression

```
Draft
  |
  v
Submitted ──────────────> Rejected (can return to Draft)
  |
  v
Legal Review In Progress
  |
  v
Legal Review Complete
  |
  v
Pending Signatures
  |
  v
Partially Executed ────> Fully Executed
                              |
                              v
                           Active
                           /    \
                          v      v
                      Expired   Terminated
                        |
                        v
                      Renewed
```

### What Happens at Each Stage

| Status | Automation |
|--------|-----------|
| **Draft** | Rules engine auto-populates approval path, required signatures, insurance requirements based on contract subject |
| **Submitted** | Submission date stamped; appropriate approval process launches; Legal Department notified (for Before-execution reviews) |
| **Legal Review In Progress** | Legal acknowledgment date stamped; SLA timer starts (5 business days) |
| **Legal Review Complete** | Review date stamped; Staff Liaison notified; contract advances to signatures |
| **Pending Signatures** | Signatory records created; signature request notifications sent |
| **Fully Executed** | Execution date stamped; all parties notified; contract becomes Active on Start Date |
| **Active** | Expiration monitoring begins (90/60/30-day reminders) |
| **Expired** | Auto-set when End Date passes; renewal notification sent |

---

## 6. Approval Processes

### Section 3.2.1: Legal + SVP + Officer
**For**: High-risk contracts (youth programs, professional services, property leases, grants, etc.)

| Step | Approver | SLA |
|------|----------|-----|
| 1. Legal Review | Legal Reviewer / Attorney | 5 business days |
| 2. SVP Approval | Senior VP of functional area | 1 business day |
| 3. Officer Approval | CEO, CPO, CFO, or COO | 1 business day |

### Section 3.2.2: Legal + SVP + VP
**For**: Moderate-risk contracts (bounce houses, health screenings, photographers, etc.)

| Step | Approver | SLA |
|------|----------|-----|
| 1. Legal Review | Legal Reviewer / Attorney | 5 business days |
| 2. SVP Approval | Senior VP of functional area | 1 business day |
| 3. VP Approval | Functional VP (may delegate to Branch ED) | 1 business day |

### Section 3.2.3: ED + VP (Legal After, <= $10K)
**For**: Lower-risk contracts at $10,000 or less. Legal reviews *after* execution.

| Step | Approver | SLA |
|------|----------|-----|
| 1. Branch ED Approval | Branch Executive Director | 1 business day |
| 2. VP Approval | Functional VP | 1 business day |

> **Important**: If the contract value exceeds $10,000, the system automatically routes to Section 3.2.1 instead.

### Section 3.2.4: Branch ED Only
**For**: Facility Use Agreements, User Group Agreements, Presenter Releases

| Step | Approver | SLA |
|------|----------|-----|
| 1. Branch ED Approval | Branch Executive Director | 1 business day |

---

## 7. Insurance & Compliance

### Certificate of Insurance (COI)
- The system automatically flags whether COI is required based on the contract subject
- COI must be collected and the "COI Received" checkbox marked before the contract can be executed
- COI expiration dates are tracked; the system sends alerts 30 days before expiration

### Additional Insured Endorsement
- Required for many contract subjects (auto-determined by the rules engine)
- Must be received before execution for contracts that require it

### ICA Approval Form
- Required for all Independent Contractor Agreements and some other subjects
- The "ICA Approval Form Received" checkbox must be checked before submission
- Branch ED signature required on the form

### Payment Compliance
- **Purchase cards CANNOT be used** for contract payments (blocked by validation rule)
- **Electronic payment** requires CFO approval before contract execution
- Payments made via check, ACH, or wire transfer only

---

## 8. Contract Renewal Management

### Renewing a Contract
1. Open the expiring contract
2. Use the **Contract Renewal Manager** component (right sidebar)
3. The system creates a new contract pre-populated with the original terms
4. Modify dates, value, and other terms as needed
5. A `Contract_Renewal__c` record links the original and renewed contracts

### Renewal Types
- **Auto Renewal** - Contract automatically renews (tracked by the Auto_Renew checkbox)
- **Manual Renewal** - Staff initiates the renewal process
- **Renegotiation** - Terms change significantly, requires full re-approval

### ICA Addendum Renewals
- Independent Contractor Agreements can be renewed via an ICA Addendum
- Select the "ICA Addendum" record type for the new contract
- Approval follows the same rules as the original contract's subject matter

### Expiration Alerts
The system sends automatic email reminders at:
- **90 days** before contract expiration
- **60 days** before contract expiration
- **30 days** before contract expiration

---

## 9. Validation Rules

The system enforces these policy rules:

| Rule | What It Does |
|------|-------------|
| **Require COI Before Execution** | Blocks moving to "Fully Executed" if COI is required but not received |
| **Require Additional Insured** | Blocks execution if endorsement is required but not received |
| **Require ICA Form** | Blocks submission if ICA Approval Form is required but not received |
| **No Services Before Execution** | Prevents marking "Services Started Before Execution" unless contract is Section 3.2.3 or 3.2.4 |
| **Require Legal Review Before Execution** | Blocks moving to "Pending Signatures" if legal review is required before execution but not complete |
| **Electronic Payment Requires CFO** | Blocks execution if payment method is "Electronic" without CFO approval |
| **No Purchase Card** | Blocks if payment method is set to "Purchase Card" |
| **Contract Value Required on Submit** | Requires a contract value before submission |
| **Require Board Approval** | Blocks execution if board approval is flagged as required but not obtained |

---

## 10. Lightning Web Components

These custom components appear on the contract record page:

| Component | Location | Description |
|-----------|----------|-------------|
| **Approval Path Indicator** | Header | Visual progress indicator showing where the contract is in its approval path |
| **Contract Compliance Dashboard** | Main area | At-a-glance view of all compliance requirements: COI status, legal review, signatures, SLA health |
| **SLA Timer** | Main area | Real-time countdown showing time remaining for legal review and signature SLAs |
| **Signature Tracker** | Main area | Shows all required signatories, their role, whether they've signed, and the date |
| **Document Checklist** | Main area | Lists required vs. received documents (COI, endorsements, ICA forms) |
| **Subject Rules Viewer** | Main area | Displays the auto-derived rules for the selected contract subject (approval path, required docs, signatories) |
| **Contract Renewal Manager** | Main area | Shows renewal options for contracts nearing expiration, with a button to initiate renewal |
| **Contract Intake Launcher** | Home page | Quick-launch button to start the guided contract intake flow |

---

## 11. Reports & Dashboard

### Reports

| Report | Description |
|--------|-------------|
| **Active Contracts by Type** | All active contracts grouped by contract type (Grant, ICA, MOU, etc.) |
| **Active Contracts by Location** | All active contracts grouped by YGSF Location |
| **Contracts Pending Legal Review** | Contracts currently awaiting Legal Department review |
| **SLA Compliance Report** | Contracts in the review pipeline grouped by SLA status (Green/Yellow/Red/Breached) |
| **Expiring Contracts Next 90 Days** | Contracts with end dates within the next 90 days |
| **Contracts by Approval Path** | Distribution of contracts across the 4 approval sections |
| **COI Expiration Report** | Contracts with COI expiring within 30 days |
| **Contract Value by Type** | Total contract value summarized by type |
| **Contracts Pending Signatures** | Contracts awaiting internal or external signatures |
| **Monthly Contract Submission Volume** | Trend of contract submissions over time |

### Dashboard
The **YGSF Contract Management Dashboard** provides an executive overview with:
- Donut chart: Contracts by Status
- Bar charts: Contract Value by Type, Contracts by Approval Path
- Tables: Expiring in 90 Days, Pending Legal Review, Pending Signatures

---

## 12. Automated Processes

### Scheduled Batch Jobs (Run Daily)

| Job | Purpose |
|-----|---------|
| **ContractExpirationBatch** | Sends 90/60/30-day expiration reminders; auto-updates expired contracts |
| **ContractSLAMonitorBatch** | Checks contracts for SLA breaches; updates SLA Status field; sends breach notifications |
| **COIExpirationBatch** | Monitors COI expiration dates; alerts Staff Liaison when COI is expiring within 30 days |

### Email Notifications (14 Templates)

| Template | Trigger |
|----------|---------|
| Contract Submission Confirmation | When a contract is submitted for review |
| Legal Review Assignment | When Legal Department receives a contract for review |
| Legal Review Complete | When Legal completes their review |
| Approval Request | When a contract is routed to an approver |
| Contract Approved | When all approvals are complete |
| Contract Rejected | When a contract is rejected (includes reason) |
| Signature Request | When a signatory needs to sign |
| Contract Executed | When a contract is fully executed |
| SLA Warning | When an SLA deadline is approaching |
| SLA Breach | When an SLA deadline has been exceeded |
| Contract Expiration (90 Day) | 90 days before contract end date |
| Contract Expiration (30 Day) | 30 days before contract end date |
| COI Expiration Warning | When a Certificate of Insurance is expiring |
| Post-Execution Legal Review | Task created for Legal on Section 3.2.3 contracts after execution |

### Flows

| Flow | Type | Purpose |
|------|------|---------|
| Contract Intake Flow | Screen Flow | Guided wizard for creating new contracts |
| Contract Renewal Flow | Screen Flow | Guided wizard for renewing contracts |
| Contract After Insert Flow | Record-Triggered | Auto-populates fields from subject config, creates signatory records |
| Contract Status Change Flow | Record-Triggered | Stamps dates and sends notifications on status transitions |
| Contract Subject Change Flow | Record-Triggered | Re-derives all rules when contract subject is changed |
| Signatory Completion Check Flow | Record-Triggered | Checks if all signatories have signed; updates contract to Fully Executed |
| Contract Expiration Reminder Flow | Scheduled | Daily check for contracts approaching expiration |
| SLA Escalation Flow | Scheduled | Daily check for SLA breaches |
| COI Renewal Reminder Flow | Scheduled | Daily check for expiring insurance certificates |

---

## 13. Administration Guide

### Modifying Contract Subject Rules

The rules engine is driven by **Custom Metadata Type** records (`Contract_Subject_Config__mdt`). To modify rules for an existing subject or add a new one:

1. Go to **Setup > Custom Metadata Types**
2. Click **"Manage Records"** next to "Contract Subject Config"
3. Click an existing record to edit, or **"New"** to create one
4. Configure these fields:

| Field | Description |
|-------|-------------|
| Subject Name | Display name of the contract subject |
| Default Approval Path | Section 3.2.1, 3.2.2, 3.2.3, or 3.2.4 |
| Approval Path Above $10K | Override path when contract value > $10,000 |
| Legal Review Timing | Before Execution, After Execution, or Not Required |
| Legal Review Timing Above $10K | Override timing when > $10,000 |
| Officer Signature Required | Whether CEO/CPO/CFO/COO must sign |
| SVP Signature Required | Whether Senior VP must sign |
| VP Signature Required | Whether VP must sign |
| ED Signature Required | Whether Branch ED must sign |
| ED Can Sole Sign | Whether Branch ED can be the only signer |
| COI Required | Whether Certificate of Insurance must be collected |
| Additional Insured Required | Whether endorsement must be collected |
| ICA Approval Form Required | Whether ICA Approval Form is needed |
| YGSF Template Required | Whether a YGSF template must be used |
| Template Name | Which specific template to use |
| Is Active | Enable/disable this subject |

### Modifying SLA Configuration

SLA timelines are stored in `SLA_Configuration__mdt`:

| Record | Default Value | Description |
|--------|--------------|-------------|
| Submission Lead Time | 5 business days | How far in advance contracts must be submitted |
| Legal Acknowledgment | 1 business day | Time for Legal to acknowledge receipt |
| Legal Review Completion | 5 business days | Time for Legal to complete review |
| Signatory Turnaround | 1 business day | Time for signatories to sign |
| Legal Return Executed | 1 business day | Time for Legal to return executed contract |

### Assigning Permission Sets

1. Go to **Setup > Users > [Select User]**
2. Click **"Permission Set Assignments"**
3. Click **"Edit Assignments"**
4. Add the appropriate permission set based on the user's role
5. Click **Save**

### Scheduling Batch Jobs

The three batch jobs should be scheduled to run daily. Execute in the Developer Console or via Setup > Apex Jobs:

```apex
// Schedule Contract Expiration Check (daily at 6 AM)
System.schedule('Contract Expiration Check', '0 0 6 * * ?', new ContractExpirationSchedulable());

// Schedule SLA Monitor (daily at 7 AM)
System.schedule('SLA Monitor', '0 0 7 * * ?', new ContractSLAMonitorSchedulable());

// Schedule COI Expiration Check (daily at 8 AM)
System.schedule('COI Expiration Check', '0 0 8 * * ?', new COIExpirationSchedulable());
```

---

## 14. Key Custom Objects

| Object | API Name | Purpose |
|--------|----------|---------|
| YGSF Contract | `YGSF_Contract__c` | Primary contract record with all fields, linked to Location |
| Contract Document | `Contract_Document__c` | Tracks documents (COI, endorsements, ICA forms, executed copies) |
| Contract Approval History | `Contract_Approval_History__c` | Audit trail of all approval actions |
| Contract Signatory | `Contract_Signatory__c` | Tracks each required signature (role, signed status, date) |
| Contract Renewal | `Contract_Renewal__c` | Links original contracts to their renewals |

---

## 15. Relationship to YMCA Contract Policy

This system directly implements the YMCA of Greater San Francisco Contract Policy (Effective September 2025):

| Policy Section | System Implementation |
|---|---|
| Section 2 (Definitions) | 13 Record Types matching all contract types |
| Section 3.1 (Templates) | Template Name field auto-populated by rules engine |
| Section 3.2.1 (High-risk approval) | Section 3.2.1 Approval Process |
| Section 3.2.2 (Moderate-risk approval) | Section 3.2.2 Approval Process |
| Section 3.2.3 (Low-risk, <= $10K) | Section 3.2.3 Approval Process with $10K threshold |
| Section 3.2.4 (ED-only approval) | Section 3.2.4 Approval Process |
| Section 4 (Retention) | Document tracking via Contract_Document__c |
| Section 5.1 (Insurance) | COI and Endorsement tracking with validation rules |
| Section 5.2 (Commencement) | "No Services Before Execution" validation rule |
| Section 5.3 (Payment) | Payment method tracking, purchase card block, CFO e-payment approval |
| Contract Procedure Section 9 (Timeline) | SLA configuration and monitoring batch jobs |
| Contract Procedure Section 10 (Responsibilities) | Role-based permission sets |
| Contract Procedure Section 12 (Subject Matrix) | 39 Custom Metadata records encoding the full policy matrix |

---

*Document Version: 1.0 | April 2026 | YMCA of Greater San Francisco*
