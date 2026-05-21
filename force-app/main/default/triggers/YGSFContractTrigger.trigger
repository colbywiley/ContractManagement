/**
 * @description Trigger for YGSF_Contract__c that delegates all logic to YGSFContractTriggerHandler.
 * Covers before/after insert and update events for field defaulting, status transitions,
 * signatory creation, and approval history tracking.
 */
trigger YGSFContractTrigger on YGSF_Contract__c (before insert, before update, after insert, after update) {
    YGSFContractTriggerHandler handler = new YGSFContractTriggerHandler();
    if (Trigger.isBefore) {
        if (Trigger.isInsert) handler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter) {
        if (Trigger.isInsert) handler.afterInsert(Trigger.new);
        if (Trigger.isUpdate) handler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
