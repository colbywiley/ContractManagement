/**
 * @description Trigger handler for YGSF_Contract__c. Orchestrates before/after logic
 * for insert and update events including subject configuration application, approval
 * path determination, signatory creation, status date stamping, and approval history tracking.
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
     * and create approval history records on status transitions.
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

            // Create approval history record on status change
            if (newContract.Status__c != oldContract.Status__c) {
                historyRecords.add(new Contract_Approval_History__c(
                    Contract__c = newContract.Id,
                    Action__c = 'Status Change: ' + oldContract.Status__c + ' -> ' + newContract.Status__c,
                    Actor__c = UserInfo.getUserId(),
                    Action_Date__c = Datetime.now(),
                    Step_Name__c = newContract.Status__c,
                    Comments__c = 'Status changed from ' + oldContract.Status__c + ' to ' + newContract.Status__c
                ));
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
}
