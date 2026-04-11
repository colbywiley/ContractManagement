/**
 * @description Controller for the Contract Action Panel LWC. Determines the current
 * user's role relative to a contract and provides methods to perform status transitions,
 * approval submissions, and approval actions. Bridges the gap between manual status
 * changes and the Salesforce approval process.
 */
public with sharing class ContractActionPanelController {

    /**
     * @description Returns the current user's role context for a specific contract,
     * including what actions are available based on their role and the contract's status.
     * @param contractId The Id of the YGSF_Contract__c record
     * @return ActionContext with role, status, available actions, and guidance message
     */
    @AuraEnabled(cacheable=true)
    public static ActionContext getActionContext(Id contractId) {
        YGSF_Contract__c contract = [
            SELECT Id, Name, Contract_Title__c, Status__c, Approval_Path__c,
                   Staff_Liaison__c, Legal_Reviewer__c, Attorney_Reviewer__c,
                   Branch_ED__c, VP_Approver__c, SVP_Approver__c, Officer_Approver__c,
                   Contract_Value__c, Contract_Type__c, Contract_Subject_Picklist__c,
                   Legal_Review_Required__c, Legal_Review_Complete__c,
                   COI_Required__c, COI_Received__c,
                   Additional_Insured_Required__c, Additional_Insured_Received__c,
                   ICA_Approval_Form_Required__c, ICA_Approval_Form_Received__c,
                   Counterparty_Name__c
            FROM YGSF_Contract__c
            WHERE Id = :contractId
            LIMIT 1
        ];

        ActionContext ctx = new ActionContext();
        ctx.contractStatus = contract.Status__c;
        ctx.approvalPath = contract.Approval_Path__c;
        ctx.contractTitle = contract.Contract_Title__c;
        ctx.contractName = contract.Name;

        // Determine the user's role
        Id currentUserId = UserInfo.getUserId();
        ctx.isStaffLiaison = (contract.Staff_Liaison__c == currentUserId);
        ctx.isLegalReviewer = hasPermissionSet('YGSF_Contract_Legal_Reviewer');
        ctx.isBranchED = (contract.Branch_ED__c == currentUserId);
        ctx.isVP = (contract.VP_Approver__c == currentUserId);
        ctx.isSVP = (contract.SVP_Approver__c == currentUserId);
        ctx.isOfficer = (contract.Officer_Approver__c == currentUserId);
        ctx.isAdmin = hasPermissionSet('YGSF_Contract_Full_Access');

        // Determine role label for display
        ctx.userRole = determineRoleLabel(ctx);

        // Check for pending approval assigned to current user
        ctx.hasPendingApproval = hasPendingApprovalForUser(contractId, currentUserId);

        // Check compliance readiness
        ctx.coiReady = !contract.COI_Required__c || contract.COI_Received__c;
        ctx.endorsementReady = !contract.Additional_Insured_Required__c || contract.Additional_Insured_Received__c;
        ctx.icaFormReady = !contract.ICA_Approval_Form_Required__c || contract.ICA_Approval_Form_Received__c;

        // Build the guidance message and available actions
        buildGuidance(ctx, contract);

        return ctx;
    }

    /**
     * @description Submit a Draft contract for review. Changes status to Submitted
     * and programmatically submits for Salesforce approval process.
     */
    @AuraEnabled
    public static void submitForReview(Id contractId) {
        YGSF_Contract__c contract = new YGSF_Contract__c(
            Id = contractId,
            Status__c = 'Submitted'
        );
        update contract;

        // Submit for approval process
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(contractId);
        req.setSubmitterId(UserInfo.getUserId());
        req.setComments('Submitted for review via Contract Action Panel');
        Approval.process(req);
    }

    /**
     * @description Legal reviewer begins their review. Changes status to Legal Review In Progress.
     */
    @AuraEnabled
    public static void beginLegalReview(Id contractId) {
        update new YGSF_Contract__c(
            Id = contractId,
            Status__c = 'Legal Review In Progress'
        );
    }

    /**
     * @description Legal reviewer completes their review and approves. Changes status
     * to Legal Review Complete and approves the current approval step.
     */
    @AuraEnabled
    public static void completeLegalReview(Id contractId, String comments) {
        update new YGSF_Contract__c(
            Id = contractId,
            Status__c = 'Legal Review Complete'
        );

        // Approve the legal review step in the approval process
        approveCurrentStep(contractId, String.isBlank(comments) ? 'Legal review completed - approved' : comments);
    }

    /**
     * @description Legal reviewer sends the contract back for revisions.
     */
    @AuraEnabled
    public static void requestRevisions(Id contractId, String comments) {
        // Reject the current approval step
        rejectCurrentStep(contractId, String.isBlank(comments) ? 'Revisions requested by Legal' : comments);

        update new YGSF_Contract__c(
            Id = contractId,
            Status__c = 'Rejected',
            Rejection_Reason__c = comments
        );
    }

    /**
     * @description Approver (SVP, VP, Officer, Branch ED) approves the contract
     * at their step in the approval process.
     */
    @AuraEnabled
    public static void approveContract(Id contractId, String comments) {
        approveCurrentStep(contractId, String.isBlank(comments) ? 'Approved' : comments);
    }

    /**
     * @description Approver rejects the contract at their step.
     */
    @AuraEnabled
    public static void rejectContract(Id contractId, String comments) {
        rejectCurrentStep(contractId, String.isBlank(comments) ? 'Rejected' : comments);

        update new YGSF_Contract__c(
            Id = contractId,
            Status__c = 'Rejected',
            Rejection_Reason__c = comments
        );
    }

    /**
     * @description Staff Liaison marks the contract as fully executed after
     * collecting all signatures.
     */
    @AuraEnabled
    public static void markFullyExecuted(Id contractId) {
        update new YGSF_Contract__c(
            Id = contractId,
            Status__c = 'Fully Executed'
        );
    }

    /**
     * @description Staff Liaison activates the contract after full execution.
     */
    @AuraEnabled
    public static void activateContract(Id contractId) {
        update new YGSF_Contract__c(
            Id = contractId,
            Status__c = 'Active'
        );
    }

    /**
     * @description Staff Liaison resubmits a rejected contract after making corrections.
     */
    @AuraEnabled
    public static void resubmitContract(Id contractId) {
        YGSF_Contract__c contract = new YGSF_Contract__c(
            Id = contractId,
            Status__c = 'Submitted',
            Rejection_Reason__c = null
        );
        update contract;

        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(contractId);
        req.setSubmitterId(UserInfo.getUserId());
        req.setComments('Resubmitted after revisions');
        Approval.process(req);
    }

    // ==================== Private Helpers ====================

    private static Boolean hasPermissionSet(String permSetName) {
        return [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.Name = :permSetName
        ] > 0;
    }

    private static Boolean hasPendingApprovalForUser(Id contractId, Id userId) {
        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :contractId
            AND ActorId = :userId
            LIMIT 1
        ];
        return !workItems.isEmpty();
    }

    private static void approveCurrentStep(Id contractId, String comments) {
        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :contractId
            LIMIT 1
        ];
        if (!workItems.isEmpty()) {
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItems[0].Id);
            req.setAction('Approve');
            req.setComments(comments);
            Approval.process(req);
        }
    }

    private static void rejectCurrentStep(Id contractId, String comments) {
        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :contractId
            LIMIT 1
        ];
        if (!workItems.isEmpty()) {
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItems[0].Id);
            req.setAction('Reject');
            req.setComments(comments);
            Approval.process(req);
        }
    }

    private static String determineRoleLabel(ActionContext ctx) {
        if (ctx.isAdmin) return 'Administrator';
        if (ctx.isStaffLiaison) return 'Staff Liaison';
        if (ctx.isLegalReviewer) return 'Legal Reviewer';
        if (ctx.isOfficer) return 'Association Officer';
        if (ctx.isSVP) return 'Senior Vice President';
        if (ctx.isVP) return 'Vice President';
        if (ctx.isBranchED) return 'Branch Executive Director';
        return 'Viewer';
    }

    private static void buildGuidance(ActionContext ctx, YGSF_Contract__c contract) {
        String status = ctx.contractStatus;
        ctx.actions = new List<ActionItem>();

        // ===== DRAFT =====
        if (status == 'Draft') {
            if (ctx.isStaffLiaison || ctx.isAdmin) {
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:edit';

                // Check readiness
                List<String> missing = new List<String>();
                if (contract.Staff_Liaison__c == null) missing.add('Staff Liaison');
                if (contract.Contract_Value__c == null) missing.add('Contract Value');
                if (contract.Counterparty_Name__c == null) missing.add('Counterparty Name');

                // Check approver readiness based on path
                if (contract.Approval_Path__c != null) {
                    if (contract.Approval_Path__c.contains('3.2.1') || contract.Approval_Path__c.contains('3.2.2')) {
                        if (contract.Legal_Reviewer__c == null) missing.add('Legal Reviewer');
                        if (contract.SVP_Approver__c == null) missing.add('SVP Approver');
                    }
                    if (contract.Approval_Path__c.contains('3.2.1') && contract.Officer_Approver__c == null) {
                        missing.add('Officer Approver');
                    }
                    if (contract.Approval_Path__c.contains('3.2.2') && contract.VP_Approver__c == null) {
                        missing.add('VP Approver');
                    }
                    if ((contract.Approval_Path__c.contains('3.2.3') || contract.Approval_Path__c.contains('3.2.4')) && contract.Branch_ED__c == null) {
                        missing.add('Branch Executive Director');
                    }
                    if (contract.Approval_Path__c.contains('3.2.3') && contract.VP_Approver__c == null) {
                        missing.add('VP Approver');
                    }
                }

                if (!missing.isEmpty()) {
                    ctx.guidanceMessage = 'This contract is in draft. Before submitting, please complete: ' + String.join(missing, ', ') + '.';
                    ctx.statusVariant = 'warning';
                    ctx.statusIcon = 'utility:warning';
                } else {
                    ctx.guidanceMessage = 'This contract is ready to submit for review. All required fields and approvers are set.';
                    ctx.actions.add(new ActionItem('submitForReview', 'Submit for Review', 'brand', 'utility:forward'));
                }
            } else {
                ctx.guidanceMessage = 'This contract is being prepared by the Staff Liaison. No action needed from you at this time.';
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:info';
            }
        }

        // ===== SUBMITTED =====
        else if (status == 'Submitted') {
            Boolean isLegalPath = contract.Approval_Path__c != null &&
                (contract.Approval_Path__c.contains('3.2.1') || contract.Approval_Path__c.contains('3.2.2'));

            if (isLegalPath && (ctx.isLegalReviewer || ctx.isAdmin)) {
                // Any user with Legal Reviewer permission set (or Admin) can begin the review
                ctx.guidanceMessage = 'This contract has been submitted and requires legal review. Please review for risk, liability, and compliance within 5 business days.';
                ctx.statusVariant = 'warning';
                ctx.statusIcon = 'utility:reassign';
                ctx.actions.add(new ActionItem('beginLegalReview', 'Begin Legal Review', 'brand', 'utility:preview'));
            } else if (ctx.hasPendingApproval || ((ctx.isBranchED || ctx.isAdmin) &&
                contract.Approval_Path__c != null &&
                (contract.Approval_Path__c.contains('3.2.3') || contract.Approval_Path__c.contains('3.2.4')))) {
                // Section 3.2.3 / 3.2.4 - no legal review, goes straight to Branch ED
                ctx.guidanceMessage = 'This contract requires your review and approval.';
                ctx.statusVariant = 'warning';
                ctx.statusIcon = 'utility:task';
                ctx.actions.add(new ActionItem('approveContract', 'Approve', 'success', 'utility:check'));
                ctx.actions.add(new ActionItem('rejectContract', 'Reject', 'destructive', 'utility:close'));
            } else if (ctx.isStaffLiaison) {
                ctx.guidanceMessage = 'Your contract has been submitted and is awaiting review. You will be notified when it progresses.';
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:clock';
            } else {
                ctx.guidanceMessage = 'This contract is awaiting review. No action needed from you at this time.';
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:clock';
            }
        }

        // ===== LEGAL REVIEW IN PROGRESS =====
        else if (status == 'Legal Review In Progress') {
            if (ctx.isLegalReviewer || ctx.isAdmin) {
                List<String> complianceNotes = new List<String>();
                if (!ctx.coiReady) complianceNotes.add('COI not yet received');
                if (!ctx.endorsementReady) complianceNotes.add('Additional Insured Endorsement not yet received');
                if (!ctx.icaFormReady) complianceNotes.add('ICA Approval Form not yet received');

                String compNote = complianceNotes.isEmpty() ? '' : ' Note: ' + String.join(complianceNotes, '; ') + '.';
                ctx.guidanceMessage = 'You are currently reviewing this contract. Complete your review for risk, liability, and compliance, then approve or request revisions.' + compNote;
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:search';
                ctx.actions.add(new ActionItem('completeLegalReview', 'Approve & Complete Review', 'success', 'utility:check'));
                ctx.actions.add(new ActionItem('requestRevisions', 'Request Revisions', 'destructive', 'utility:undo'));
            } else if (ctx.isStaffLiaison) {
                ctx.guidanceMessage = 'Your contract is currently under legal review. You will be notified when the review is complete.';
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:clock';
            } else {
                ctx.guidanceMessage = 'This contract is under legal review. No action needed from you at this time.';
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:clock';
            }
        }

        // ===== LEGAL REVIEW COMPLETE =====
        else if (status == 'Legal Review Complete') {
            if (ctx.hasPendingApproval || ctx.isSVP || ctx.isVP || ctx.isOfficer || ctx.isBranchED || ctx.isAdmin) {
                String approverRole = '';
                if (ctx.isSVP) approverRole = 'Senior Vice President';
                else if (ctx.isVP) approverRole = 'Vice President';
                else if (ctx.isOfficer) approverRole = 'Association Officer';
                else if (ctx.isBranchED) approverRole = 'Branch Executive Director';
                else if (ctx.isAdmin) approverRole = 'Administrator';
                else approverRole = 'Approver';

                ctx.guidanceMessage = 'Legal review is complete. As ' + approverRole + ', this contract requires your approval to proceed.';
                ctx.statusVariant = 'warning';
                ctx.statusIcon = 'utility:task';
                ctx.actions.add(new ActionItem('approveContract', 'Approve', 'success', 'utility:check'));
                ctx.actions.add(new ActionItem('rejectContract', 'Reject', 'destructive', 'utility:close'));
            } else if (ctx.isStaffLiaison) {
                ctx.guidanceMessage = 'Legal review is complete. The contract is now being routed to the required approvers for sign-off.';
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:routing_offline';
            } else {
                ctx.guidanceMessage = 'Legal review is complete. The contract is awaiting executive approvals.';
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:clock';
            }
        }

        // ===== PENDING SIGNATURES =====
        else if (status == 'Pending Signatures') {
            if (ctx.isStaffLiaison || ctx.isAdmin) {
                List<String> pendingItems = new List<String>();
                if (!ctx.coiReady) pendingItems.add('Collect Certificate of Insurance');
                if (!ctx.endorsementReady) pendingItems.add('Collect Additional Insured Endorsement');

                String pendingNote = pendingItems.isEmpty() ? '' : ' Outstanding items: ' + String.join(pendingItems, '; ') + '.';
                ctx.guidanceMessage = 'All approvals are complete. Collect the required signatures from all parties, then mark as fully executed.' + pendingNote;
                ctx.statusVariant = 'warning';
                ctx.statusIcon = 'utility:edit';
                ctx.actions.add(new ActionItem('markFullyExecuted', 'Mark as Fully Executed', 'brand', 'utility:check'));
            } else {
                ctx.guidanceMessage = 'This contract has been approved and is awaiting signatures from all parties.';
                ctx.statusVariant = 'info';
                ctx.statusIcon = 'utility:clock';
            }
        }

        // ===== FULLY EXECUTED =====
        else if (status == 'Fully Executed') {
            if (ctx.isStaffLiaison || ctx.isAdmin) {
                ctx.guidanceMessage = 'This contract is fully executed. Activate it to begin the contract term.';
                ctx.statusVariant = 'success';
                ctx.statusIcon = 'utility:check';
                ctx.actions.add(new ActionItem('activateContract', 'Activate Contract', 'success', 'utility:play'));
            } else {
                ctx.guidanceMessage = 'This contract has been fully executed and is awaiting activation.';
                ctx.statusVariant = 'success';
                ctx.statusIcon = 'utility:check';
            }
        }

        // ===== ACTIVE =====
        else if (status == 'Active') {
            ctx.guidanceMessage = 'This contract is active and in effect.';
            ctx.statusVariant = 'success';
            ctx.statusIcon = 'utility:success';
        }

        // ===== REJECTED =====
        else if (status == 'Rejected') {
            if (ctx.isStaffLiaison || ctx.isAdmin) {
                String reason = String.isNotBlank(contract.Rejection_Reason__c) ?
                    ' Reason: ' + contract.Rejection_Reason__c : '';
                ctx.guidanceMessage = 'This contract was rejected.' + reason + ' Make the necessary corrections and resubmit.';
                ctx.statusVariant = 'error';
                ctx.statusIcon = 'utility:error';
                ctx.actions.add(new ActionItem('resubmitContract', 'Resubmit for Review', 'brand', 'utility:redo'));
            } else {
                ctx.guidanceMessage = 'This contract was rejected and returned to the Staff Liaison for revisions.';
                ctx.statusVariant = 'error';
                ctx.statusIcon = 'utility:error';
            }
        }

        // ===== EXPIRED / TERMINATED / RENEWED =====
        else if (status == 'Expired') {
            ctx.guidanceMessage = 'This contract has expired.';
            ctx.statusVariant = 'warning';
            ctx.statusIcon = 'utility:warning';
        } else if (status == 'Terminated') {
            ctx.guidanceMessage = 'This contract has been terminated.';
            ctx.statusVariant = 'error';
            ctx.statusIcon = 'utility:ban';
        } else if (status == 'Renewed') {
            ctx.guidanceMessage = 'This contract has been renewed. See the related renewal record for the new contract.';
            ctx.statusVariant = 'success';
            ctx.statusIcon = 'utility:refresh';
        }

        // Default
        else {
            ctx.guidanceMessage = 'Contract status: ' + status;
            ctx.statusVariant = 'info';
            ctx.statusIcon = 'utility:info';
        }
    }

    // ==================== Inner Classes ====================

    public class ActionContext {
        @AuraEnabled public String contractStatus;
        @AuraEnabled public String approvalPath;
        @AuraEnabled public String contractTitle;
        @AuraEnabled public String contractName;
        @AuraEnabled public String userRole;
        @AuraEnabled public String guidanceMessage;
        @AuraEnabled public String statusVariant; // info, warning, success, error
        @AuraEnabled public String statusIcon;
        @AuraEnabled public List<ActionItem> actions;

        @AuraEnabled public Boolean isStaffLiaison;
        @AuraEnabled public Boolean isLegalReviewer;
        @AuraEnabled public Boolean isBranchED;
        @AuraEnabled public Boolean isVP;
        @AuraEnabled public Boolean isSVP;
        @AuraEnabled public Boolean isOfficer;
        @AuraEnabled public Boolean isAdmin;
        @AuraEnabled public Boolean hasPendingApproval;

        @AuraEnabled public Boolean coiReady;
        @AuraEnabled public Boolean endorsementReady;
        @AuraEnabled public Boolean icaFormReady;
    }

    public class ActionItem {
        @AuraEnabled public String actionName;
        @AuraEnabled public String label;
        @AuraEnabled public String variant; // brand, success, destructive
        @AuraEnabled public String iconName;

        public ActionItem(String actionName, String label, String variant, String iconName) {
            this.actionName = actionName;
            this.label = label;
            this.variant = variant;
            this.iconName = iconName;
        }
    }
}
