/**
 * @description Trigger for Contract_Document__c that delegates logic to ContractDocumentTriggerHandler.
 * Handles upload date defaults, expiration checks, and parent contract flag updates.
 */
trigger ContractDocumentTrigger on Contract_Document__c (before insert, before update, after insert, after update) {
    ContractDocumentTriggerHandler handler = new ContractDocumentTriggerHandler();
    if (Trigger.isBefore) {
        if (Trigger.isInsert) handler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        if (Trigger.isInsert) handler.afterInsert(Trigger.new);
        if (Trigger.isUpdate) handler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
