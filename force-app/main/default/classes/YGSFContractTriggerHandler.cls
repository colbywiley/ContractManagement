/**
 * @description Trigger handler for YGSF_Contract__c. Orchestrates before/after logic
 * for insert and update events including subject configuration application, approval
 * path determination, signatory creation, status date stamping, approval history tracking,
 * and email notifications on status transitions.
 */
public with sharing class YGSFContractTriggerHandler {

    /**
     * @description Before insert: apply subject-driven configurations and determine
     * approval paths for new contracts.
     * @param newContracts The list of YGSF_Contract__c being inserted
     */
    public void beforeInsert(List<YGSF_Contract__c> newContracts) {
        ContractSubjectConfigService.applySubjectConfigs(newContracts);
        ApprovalPathDeterminator.determineApprovalPaths(newContracts);
    }

    /**
     * @description Before update: re-derive configuration when subject or value changes,
     * and stamp status transition dates.
     * @param newContracts The updated YGSF_Contract__c records
     * @param oldMap Map of old record versions keyed by Id
     */
    public void beforeUpdate(List<YGSF_Contract__c> newContracts, Map<Id, YGSF_Contract__c> oldMap) {
        List<YGSF_Contract__c> configChangedContracts = new List<YGSF_Contract__c>();

        for (YGSF_Contract__c newContract : newContracts) {
            YGSF_Contract__c oldContract = oldMap.get(newContract.Id);

            // Re-derive config if subject or value changed
            if (newContract.Contract_Subject_Picklist__c != oldContract.Contract_Subject_Picklist__c ||
                newContract.Contract_Value__c != oldContract.Contract_Value__c) {
                configChangedContracts.add(newContract);
            }

            // Stamp Submission_Date__c when status changes to Submitted
            if (newContract.Status__c == 'Submitted' && oldContract.Status__c != 'Submitted') {
                newContract.Submission_Date__c = Date.today();
            }

            // Stamp Legal_Acknowledgment_Date__c when status changes to Legal Review In Progress
            if (newContract.Status__c == 'Legal Review In Progress' && oldContract.Status__c != 'Legal Review In Progress') {
                newContract.Legal_Acknowledgment_Date__c = Date.today();
            }

            // Stamp Legal_Review_Date__c when status changes to Legal Review Complete
            if (newContract.Status__c == 'Legal Review Complete' && oldContract.Status__c != 'Legal Review Complete') {
                newContract.Legal_Review_Date__c = Date.today();
                newContract.Legal_Review_Complete__c = true;
            }

            // Stamp Execution_Date__c when status changes to Fully Executed
            if (newContract.Status__c == 'Fully Executed' && oldContract.Status__c != 'Fully Executed') {
                newContract.Execution_Date__c = Date.today();
            }
        }

        if (!configChangedContracts.isEmpty()) {
            ContractSubjectConfigService.applySubjectConfigs(configChangedContracts);
            ApprovalPathDeterminator.determineApprovalPaths(configChangedContracts);
        }
    }

    /**
     * @description After insert: auto-create signatory records based on subject configuration.
     * @param newContracts The newly inserted YGSF_Contract__c records (with Ids)
     */
    public void afterInsert(List<YGSF_Contract__c> newContracts) {
        ContractSignatoryService.createSignatories(newContracts);
    }

    /**
     * @description After update: recalculate signatories when subject changes,
     * create approval history records on status transitions, and send email
     * notifications for key status changes.
     * @param newContracts The updated YGSF_Contract__c records
     * @param oldMap Map of old record versions keyed by Id
     */
    public void afterUpdate(List<YGSF_Contract__c> newContracts, Map<Id, YGSF_Contract__c> oldMap) {
        List<YGSF_Contract__c> subjectChangedContracts = new List<YGSF_Contract__c>();
        List<Contract_Approval_History__c> historyRecords = new List<Contract_Approval_History__c>();

        for (YGSF_Contract__c newContract : newContracts) {
            YGSF_Contract__c oldContract = oldMap.get(newContract.Id);

            // Recalculate signatories when subject changes
            if (newContract.Contract_Subject_Picklist__c != oldContract.Contract_Subject_Picklist__c) {
                subjectChangedContracts.add(newContract);
            }

            // Handle status transitions
            if (newContract.Status__c != oldContract.Status__c) {
                // Create approval history record
                historyRecords.add(new Contract_Approval_History__c(
                    Contract__c = newContract.Id,
                    Action__c = 'Status Change: ' + oldContract.Status__c + ' -> ' + newContract.Status__c,
                    Actor__c = UserInfo.getUserId(),
                    Action_Date__c = Datetime.now(),
                    Step_Name__c = newContract.Status__c,
                    Comments__c = 'Status changed from ' + oldContract.Status__c + ' to ' + newContract.Status__c
                ));

                // Send email notifications based on the new status
                sendStatusChangeNotifications(newContract, oldContract.Status__c);
            }
        }

        if (!subjectChangedContracts.isEmpty()) {
            for (YGSF_Contract__c contract : subjectChangedContracts) {
                ContractSignatoryService.recalculateSignatories(contract);
            }
        }

        if (!historyRecords.isEmpty()) {
            insert historyRecords;
        }
    }

    /**
     * @description Sends appropriate email notifications when a contract's status changes.
     * Dispatches to ContractNotificationService based on the new status value.
     * @param contract The contract with the new status
     * @param oldStatus The previous status value
     */
    private void sendStatusChangeNotifications(YGSF_Contract__c contract, String oldStatus) {
        switch on contract.Status__c {
            when 'Submitted' {
                // Notify Staff Liaison (confirmation) and Legal Reviewer (assignment)
                ContractNotificationService.notifySubmission(contract);
            }
            when 'Legal Review Complete' {
                // Notify Staff Liaison that legal review is done
                ContractNotificationService.notifyLegalReviewComplete(contract);
            }
            when 'Pending Signatures' {
                // Notify the first required approver based on the approval path
                sendApprovalNotifications(contract);
            }
            when 'Rejected' {
                // Notify Staff Liaison of rejection
                if (contract.Staff_Liaison__c != null) {
                    ContractNotificationService.notifyApprovalRequired(contract, contract.Staff_Liaison__c);
                }
            }
            when 'Fully Executed' {
                // Notify Staff Liaison that the contract is fully executed
                if (contract.Staff_Liaison__c != null) {
                    ContractNotificationService.notifyApprovalRequired(contract, contract.Staff_Liaison__c);
                }
            }
        }
    }

    /**
     * @description Sends approval request notifications to the appropriate approvers
     * based on the contract's approval path. Each approval path routes to different
     * signatories as defined by the YMCA Contract Policy:
     * - Section 3.2.1: Legal Reviewer, SVP, then Officer
     * - Section 3.2.2: Legal Reviewer, SVP, then VP
     * - Section 3.2.3: Branch ED, then VP
     * - Section 3.2.4: Branch ED only
     * @param contract The contract entering the Pending Signatures status
     */
    private void sendApprovalNotifications(YGSF_Contract__c contract) {
        Set<Id> notified = new Set<Id>();

        if (contract.Approval_Path__c != null && contract.Approval_Path__c.contains('3.2.1')) {
            addApprover(contract, contract.Legal_Reviewer__c, notified);
            addApprover(contract, contract.SVP_Approver__c, notified);
            addApprover(contract, contract.Officer_Approver__c, notified);
        } else if (contract.Approval_Path__c != null && contract.Approval_Path__c.contains('3.2.2')) {
            addApprover(contract, contract.Legal_Reviewer__c, notified);
            addApprover(contract, contract.SVP_Approver__c, notified);
            addApprover(contract, contract.VP_Approver__c, notified);
        } else if (contract.Approval_Path__c != null && contract.Approval_Path__c.contains('3.2.3')) {
            addApprover(contract, contract.Branch_ED__c, notified);
            addApprover(contract, contract.VP_Approver__c, notified);
        } else if (contract.Approval_Path__c != null && contract.Approval_Path__c.contains('3.2.4')) {
            addApprover(contract, contract.Branch_ED__c, notified);
        }
    }

    /**
     * @description Sends an approval notification to an approver if not null and not
     * already notified in this cycle.
     */
    private void addApprover(YGSF_Contract__c contract, Id approverId, Set<Id> notified) {
        if (approverId != null && !notified.contains(approverId)) {
            ContractNotificationService.notifyApprovalRequired(contract, approverId);
            notified.add(approverId);
        }
    }
}
