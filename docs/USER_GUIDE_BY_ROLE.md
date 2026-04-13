# YGSF Contract Management - User Guide by Role

This guide walks each type of user through their specific responsibilities and the exact steps they take in the Salesforce application.

---

## Table of Contents
1. [Staff Liaison](#staff-liaison)
2. [Legal Reviewer](#legal-reviewer)
3. [Branch Executive Director](#branch-executive-director)
4. [Vice President (VP)](#vice-president-vp)
5. [Senior Vice President (SVP)](#senior-vice-president-svp)
6. [Association Officer](#association-officer-ceocpocfocoo)
7. [Finance User](#finance-user)
8. [View-Only User](#view-only-user)
9. [Administrator](#administrator)

---

## Staff Liaison

**Your role**: You initiate contracts, collect signatures, and drive them to execution. You are responsible for the entire contract lifecycle from creation through activation.

**Permission Set**: `YGSF Contract Staff Liaison`

### Your Workflow

#### 1. Creating a New Contract

1. Navigate to the **YGSF Contract Management** app from the App Launcher
2. Click the **YGSF Contracts** tab
3. Click **New** (or use the **Contract Intake** quick action from the home page)
4. Complete the 5-screen intake wizard:
   - **Contract Basics**: Title, Type, Subject, Location, Description
   - **Counterparty Info**: Name, Account, Contact
   - **Financial Details**: Value, Start/End Dates, Payment Method, Auto-Renew
   - **Approvers**: Assign Legal Reviewer, Branch ED, VP, SVP, Officer (only fill in those relevant to your contract's approval path)
   - **Review & Submit**: Confirm details and save
5. The contract is saved in **Draft** status

> **Tip**: The system auto-detects the approval path from the Contract Subject and Value. Check the Approval Path field on the record page to see which approvers you need to assign.

#### 2. Submitting for Review

1. Open the contract record
2. Review the **Contract Action Panel** at the top of the page - it shows if all required fields and approvers are set
3. If anything is missing, fix it in the record detail section
4. Once ready, click **Submit for Review** in the Action Panel
5. Status changes to **Submitted**, and the first approver (Legal Reviewer for 3.2.1/3.2.2, or Branch ED for 3.2.3/3.2.4) is notified by email

#### 3. Monitoring Progress

While the contract moves through approvals, monitor it from the record page:
- **Action Panel** shows current status and guidance
- **SLA Timers** show remaining time for legal acknowledgment and review
- **Approval History** shows which approvers have signed off
- **Signature Tracker** shows which parties have signed

You'll receive emails at each stage: Legal Review Complete, approvals, rejections.

#### 4. Handling Rejections

If a contract is rejected:
1. The Action Panel shows the rejection reason
2. Make the requested corrections on the record
3. Click **Resubmit for Review** in the Action Panel

#### 5. Collecting Signatures

When status changes to **Pending Signatures**:
1. All internal approvals are complete
2. Collect physical/electronic signatures from all required parties
3. Upload the signed contract to the **Contract Documents** related list
4. Update each **Signatory** record with the Signed date when received
5. Ensure COI and Additional Insured Endorsement are uploaded if required
6. Click **Mark as Fully Executed** in the Action Panel

#### 6. Activating the Contract

After marking Fully Executed:
1. Click **Activate Contract** in the Action Panel
2. Status changes to **Active**, and the contract term begins

#### 7. Managing Renewals

For contracts approaching expiration (90/60/30 days out):
1. You'll receive email reminders from the system
2. On the record page, use the **Renewal Manager** component
3. Click the renewal button to create a new contract from the existing one (data is cloned)
4. Process the new contract through the normal workflow

---

## Legal Reviewer

**Your role**: You review contracts for risk, liability, and compliance. The Legal Reviewer is a **queue/team role** - any user with the Legal Reviewer permission set can act on any contract requiring legal review.

**Permission Set**: `YGSF Contract Legal Reviewer`

### Your Workflow

#### 1. Receiving Review Assignments

When a Staff Liaison submits a contract for review (Section 3.2.1 or 3.2.2 path):
- You receive an email: **"Legal Review Assigned"**
- The email includes a direct link to the contract record

> **Note**: Legal Review applies to Section 3.2.1 and 3.2.2 paths only. Section 3.2.3 contracts get legal review AFTER execution, and Section 3.2.4 contracts don't require legal review.

#### 2. Starting a Review

1. Open the contract record from the email link (or from a Legal Review list view)
2. Read the contract and review insurance requirements
3. In the **Contract Action Panel**, click **Begin Legal Review**
4. Status changes to **Legal Review In Progress**
5. You have **5 business days** to complete the review (per YGSF policy SLA)

#### 3. Conducting the Review

Review the contract for:
- Risk and liability exposure
- Compliance with YGSF policies
- Correct legal entity name and branch
- Accurate dates and terms
- Insurance requirements match the contract type
- Indemnification clauses
- Payment terms

Use the **Subject Rules Viewer** component on the record page to see what's required for this contract subject.

Verify required documents are uploaded in the **Document Checklist** component:
- Certificate of Insurance (COI) if required
- Additional Insured Endorsement if required
- ICA Approval Form if required

#### 4. Completing the Review

**If the contract is acceptable:**
1. Click **Approve & Complete Review** in the Action Panel
2. Add optional comments
3. Status changes to **Legal Review Complete**
4. The contract automatically advances to the next approver (SVP)

**If revisions are needed:**
1. Click **Request Revisions** in the Action Panel
2. Enter required comments explaining what needs to change
3. Status changes to **Rejected**
4. The Staff Liaison is notified and can resubmit after corrections

---

## Branch Executive Director

**Your role**: You approve contracts for your branch. You are the primary approver for Section 3.2.3 (≤$10K) and 3.2.4 (Facility Use) contracts, and often the designated signatory for lower-value agreements.

**Permission Set**: `YGSF Contract Branch ED`

### Your Workflow

#### When You're Involved

You act on contracts where you are specifically named in the `Branch_ED__c` field on the contract. The approval buttons only appear for the user specifically assigned.

**Approval paths you're involved in:**
- **Section 3.2.3** (ED + VP, ≤$10K): You're the first approver
- **Section 3.2.4** (Branch ED only): You're the sole approver

#### 1. Receiving Approval Requests

When a Staff Liaison submits a contract where you're the assigned Branch ED:
- You receive an email: **"Approval Required"**
- The email includes contract details and a link to the record

#### 2. Reviewing the Contract

1. Open the contract record from the email
2. Review the contract details, counterparty, value, and scope
3. Verify required documents are in the **Document Checklist**
4. Check the **Signature Tracker** to see what signatures will be needed after your approval

#### 3. Approving or Rejecting

**To approve:**
1. In the Contract Action Panel, click **Approve**
2. Add optional comments
3. The approval advances to the next step:
   - **Section 3.2.3**: Goes to the VP
   - **Section 3.2.4**: Goes directly to "Pending Signatures" (you're the final approver)

**To reject:**
1. Click **Reject** in the Action Panel
2. Enter required rejection comments explaining why
3. Status changes to **Rejected**
4. The Staff Liaison is notified to make corrections

#### 4. Post-Execution Legal Review (Section 3.2.3 only)

For Section 3.2.3 contracts, remember that **legal review happens AFTER execution**. Once the contract is fully executed, the Staff Liaison will send it to Legal for post-execution review and filing.

---

## Vice President (VP)

**Your role**: You provide executive approval for contracts assigned to your area. You appear in Section 3.2.2 and 3.2.3 approval paths.

**Permission Set**: `YGSF Contract VP`

### Your Workflow

#### When You're Involved

You act on contracts where you are specifically named in the `VP_Approver__c` field on the contract.

**Approval paths:**
- **Section 3.2.2** (Legal + SVP + VP): You're the final approver after SVP
- **Section 3.2.3** (ED + VP, ≤$10K): You're the final approver after Branch ED

#### 1. Receiving Approval Requests

You receive an email when it's your turn to approve:
- **"Approval Required"** with contract details and link

#### 2. Reviewing the Contract

1. Open the contract record
2. Review the details, previous approvals (in **Approval History**), and legal review notes if applicable
3. Check the **Contract Action Panel** for guidance

#### 3. Approving or Rejecting

**To approve:**
1. Click **Approve** in the Action Panel
2. Add optional comments
3. Status changes to **Pending Signatures** (you're the final approver)

**To reject:**
1. Click **Reject** with required comments
2. Status changes to **Rejected**

---

## Senior Vice President (SVP)

**Your role**: You approve high-risk and moderate-risk contracts within your functional area. You appear in Section 3.2.1 and 3.2.2 approval paths.

**Permission Set**: `YGSF Contract SVP`

### Your Workflow

#### When You're Involved

You act on contracts where you are specifically named in the `SVP_Approver__c` field on the contract.

**Approval paths:**
- **Section 3.2.1** (Legal + SVP + Officer): You approve after Legal, before the Officer
- **Section 3.2.2** (Legal + SVP + VP): You approve after Legal, before the VP

#### 1. Receiving Approval Requests

You receive an email: **"Approval Required"** after Legal completes their review.

#### 2. Reviewing the Contract

1. Open the contract record
2. Review the contract details
3. Check the **Approval History** to see the Legal Reviewer's comments
4. Verify the **Subject Rules Viewer** shows this contract path is correct

#### 3. Approving or Rejecting

**To approve:**
1. Click **Approve** in the Action Panel
2. Add optional comments
3. The approval advances:
   - **Section 3.2.1**: Goes to the Officer for final approval
   - **Section 3.2.2**: Goes to the VP for final approval

**To reject:**
1. Click **Reject** with required comments
2. Status changes to **Rejected**

---

## Association Officer (CEO/CPO/CFO/COO)

**Your role**: You provide the highest-level approval for high-risk contracts. You appear only in Section 3.2.1 approval paths.

**Permission Set**: `YGSF Contract Officer`

### Your Workflow

#### When You're Involved

You act on contracts where you are specifically named in the `Officer_Approver__c` field on the contract.

**Approval path:**
- **Section 3.2.1** (Legal + SVP + Officer): You are the final approver

#### 1. Receiving Approval Requests

After Legal and SVP have both approved, you receive: **"Approval Required"**

#### 2. Reviewing the Contract

1. Open the contract record
2. Review the full approval history (Legal + SVP)
3. Consider strategic and organizational impact
4. Check Board approval requirement if `Board_Approval_Required__c` is checked

#### 3. Approving or Rejecting

**To approve:**
1. Click **Approve** in the Action Panel
2. Add optional comments
3. Status changes to **Pending Signatures** - the contract is fully approved

**To reject:**
1. Click **Reject** with required comments
2. Status changes to **Rejected**

#### 4. Special Responsibility: Board Approval

For contracts where Board approval is required, you coordinate with the Board of Directors before approving in Salesforce. Update the `Board_Approval_Date__c` field after Board approval is obtained.

---

## Finance User

**Your role**: You manage payment-related fields on contracts and provide CFO approval for electronic payment methods.

**Permission Set**: `YGSF Contract Finance`

### Your Workflow

#### What You Can Edit

You have edit access to:
- `Payment_Method__c`
- `CFO_Payment_Approval__c`
- `Contract_Value__c`
- `Notes__c`

All other fields are read-only.

#### 1. Approving Electronic Payments

When a contract is submitted with `Payment_Method__c = "Electronic"`:
- The system requires `CFO_Payment_Approval__c` to be checked before execution
- You review the contract's payment terms
- Check the **CFO Payment Approval** checkbox to approve

#### 2. Reviewing Purchase Card Violations

Per YGSF policy, Purchase Cards cannot be used for contract payments. If `Payment_Method__c = "Purchase Card"`, the validation rule will block the transaction. Work with the Staff Liaison to change the payment method to Check, ACH, or Wire.

#### 3. Reviewing Contract Values

You can monitor contracts by value through:
- The **Active Contracts by Type** report
- The **Contract Value by Type** report
- The main dashboard

---

## View-Only User

**Your role**: You can view all contracts and contract data but cannot make any changes. This role is for auditors, executives who need visibility, or staff who reference contracts but don't modify them.

**Permission Set**: `YGSF Contract View Only`

### Your Workflow

1. Navigate to the **YGSF Contract Management** app
2. Browse the **YGSF Contracts**, **Contract Documents**, and **Contract Renewals** tabs
3. Open any contract record to view details
4. Review reports and dashboard for overall metrics
5. Export data for external reporting (where permitted)

You cannot:
- Edit any fields
- Approve/reject contracts
- Create new records
- Delete records

---

## Administrator

**Your role**: You manage the application's configuration, troubleshoot issues, and have unrestricted access to all data.

**Permission Set**: `YGSF Contract Full Access`

### Your Workflow

#### 1. Managing Contract Subject Configuration

The system uses `Contract_Subject_Config__mdt` custom metadata to drive approval paths and rules. To add or modify a subject:

1. Go to **Setup > Custom Metadata Types**
2. Click **Manage Records** next to **Contract Subject Config**
3. Add or edit records to update:
   - Default Approval Path (3.2.1-3.2.4)
   - Legal Review Timing (Before/After Execution)
   - Required signatures by role
   - COI / Endorsement / ICA Form requirements
   - Template name and other guidance

#### 2. Managing SLA Configuration

SLA deadlines are defined in `SLA_Configuration__mdt`:
- Submission Lead Time (default: 5 business days)
- Legal Acknowledgment (default: 1 business day)
- Legal Review Completion (default: 5 business days)
- Signatory Turnaround (default: 1 business day)
- Legal Return Executed (default: 1 business day)

#### 3. Scheduling Batch Jobs

Run these in Developer Console (Execute Anonymous) to schedule daily batch jobs:

```apex
System.schedule('Contract Expiration Monitor', '0 0 7 * * ?', new ContractExpirationSchedulable());
System.schedule('Contract SLA Monitor', '0 0 7 * * ?', new ContractSLAMonitorSchedulable());
System.schedule('COI Expiration Monitor', '0 0 7 * * ?', new COIExpirationSchedulable());
```

#### 4. Assigning Permission Sets

Use Setup > Permission Sets to assign the appropriate permission set to each user:
- Staff Liaison roles -> `YGSF Contract Staff Liaison`
- Legal team -> `YGSF Contract Legal Reviewer`
- Branch EDs -> `YGSF Contract Branch ED`
- VPs, SVPs, Officers -> respective permission sets
- Finance team -> `YGSF Contract Finance`
- Auditors / viewers -> `YGSF Contract View Only`
- Admins -> `YGSF Contract Full Access`

#### 5. Override Actions

You have Admin-level access that lets you:
- Edit contracts at any status
- Bypass validation rules (not recommended)
- Manually trigger status changes via the Action Panel
- Recall approvals from the Approval History related list
- Delete records (use sparingly)

#### 6. Monitoring System Health

Check these regularly:
- **Setup > Apex Jobs**: Verify scheduled batch jobs ran successfully
- **Setup > Debug Logs**: Investigate any failures
- **Reports > SLA Compliance Report**: Identify contracts breaching SLAs
- **Dashboards > YGSF Contract Management Dashboard**: Overall health metrics

---

## Quick Reference: Who Does What

| Activity | Staff Liaison | Legal Reviewer | Branch ED | VP | SVP | Officer | Finance |
|---|---|---|---|---|---|---|---|
| Create contracts | Yes | | Yes | | | | |
| Assign approvers | Yes | | | | | | |
| Submit for review | Yes | | | | | | |
| Begin/Complete Legal Review | | Yes | | | | | |
| Approve as Branch ED (3.2.3/3.2.4) | | | Yes | | | | |
| Approve as VP (3.2.2/3.2.3) | | | | Yes | | | |
| Approve as SVP (3.2.1/3.2.2) | | | | | Yes | | |
| Approve as Officer (3.2.1) | | | | | | Yes | |
| Approve electronic payment | | | | | | | Yes |
| Collect signatures | Yes | | | | | | |
| Mark Fully Executed | Yes | | | | | | |
| Activate Contract | Yes | | | | | | |
| Create renewal | Yes | | | | | | |
| Edit payment method | | | | | | | Yes |
| View all contracts | Yes | Yes | Yes | Yes | Yes | Yes | Yes |

---

## Quick Reference: Approval Paths

| Path | When Used | Step 1 | Step 2 | Step 3 | Legal Timing |
|---|---|---|---|---|---|
| **3.2.1** | High-risk (Youth Programs, ICAs, Professional Services, Legal, etc.) OR >$10K on 3.2.3 subjects | Legal Reviewer | SVP | Officer | Before Execution |
| **3.2.2** | Moderate-risk (Bounce House, Health Screening, Photographer, Security, Staffing) | Legal Reviewer | SVP | VP | Before Execution |
| **3.2.3** | Low-risk operational contracts ≤$10K (Auctioneers, Construction, Food Service, Grants, etc.) | Branch ED | VP | -- | After Execution |
| **3.2.4** | Facility Use Agreement, User Group Agreement | Branch ED | -- | -- | Not Required |

---

## Getting Help

- **Policy questions**: Refer to the YGSF Contract Policy (Sept 2025) and Contract Procedure documents
- **Technical issues**: Contact your Salesforce Administrator
- **Legal questions**: Contact the Association Director of Risk and Legal
- **App issues**: Check the Contract Action Panel's guidance messages - they explain what's needed at each step
