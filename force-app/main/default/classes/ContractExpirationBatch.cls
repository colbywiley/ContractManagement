/**
 * @description Batch job that processes active YGSF contracts for expiration and
 * sends reminder emails at 90, 60, and 30 day intervals before the contract end date.
 * Contracts whose End_Date__c has passed are automatically set to Expired status.
 * Implements Database.Stateful to track processed record counts across batches.
 */
public with sharing class ContractExpirationBatch implements Database.Batchable<SObject>, Database.Stateful {

    /** Count of contracts marked as expired during this batch run */
    @TestVisible
    private Integer expiredCount = 0;

    /** Count of reminder emails sent during this batch run */
    @TestVisible
    private Integer reminderCount = 0;

    /**
     * @description Queries active contracts with a populated End_Date__c for processing.
     * @param bc The batch context
     * @return QueryLocator for active contracts with end dates
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Contract_Title__c, Status__c, End_Date__c, Auto_Renew__c,
                   Staff_Liaison__c, Branch_ED__c, Counterparty_Name__c,
                   Contract_Type__c, Contract_Subject_Picklist__c, Contract_Value__c,
                   Approval_Path__c, Legal_Review_Required__c
            FROM YGSF_Contract__c
            WHERE Status__c = 'Active'
              AND End_Date__c != null
        ]);
    }

    /**
     * @description Processes each batch of contracts. Expires contracts past their end date
     * and sends reminder emails at 90, 60, and 30 day thresholds.
     * @param bc The batch context
     * @param scope The list of YGSF_Contract__c records in this batch
     */
    public void execute(Database.BatchableContext bc, List<YGSF_Contract__c> scope) {
        Date today = Date.today();
        Date plus30 = today.addDays(30);
        Date plus60 = today.addDays(60);
        Date plus90 = today.addDays(90);

        List<YGSF_Contract__c> contractsToUpdate = new List<YGSF_Contract__c>();

        for (YGSF_Contract__c contract : scope) {
            // If end date has passed or is today, expire the contract
            if (contract.End_Date__c <= today) {
                contract.Status__c = 'Expired';
                contractsToUpdate.add(contract);
                expiredCount++;
                continue;
            }

            // Send reminder emails at 90, 60, and 30 day thresholds
            if (contract.End_Date__c == plus90) {
                ContractNotificationService.notifyExpirationWarning(contract, 90);
                reminderCount++;
            } else if (contract.End_Date__c == plus60) {
                ContractNotificationService.notifyExpirationWarning(contract, 60);
                reminderCount++;
            } else if (contract.End_Date__c == plus30) {
                ContractNotificationService.notifyExpirationWarning(contract, 30);
                reminderCount++;
            }
        }

        if (!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }
    }

    /**
     * @description Logs batch completion with summary statistics.
     * @param bc The batch context
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO,
            'ContractExpirationBatch completed. Expired: ' + expiredCount +
            ', Reminders sent: ' + reminderCount
        );
    }
}
