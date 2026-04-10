/**
 * @description Trigger for Contract_Signatory__c that delegates logic to ContractSignatoryTriggerHandler.
 * Handles signed date stamping and parent contract status updates when all signatories complete.
 */
trigger ContractSignatoryTrigger on Contract_Signatory__c (before update, after update) {
    ContractSignatoryTriggerHandler handler = new ContractSignatoryTriggerHandler();
    if (Trigger.isBefore) {
        if (Trigger.isUpdate) handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) handler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
