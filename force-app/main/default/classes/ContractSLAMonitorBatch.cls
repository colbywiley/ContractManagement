/**
 * @description Batch job that monitors YGSF contracts in review/signature stages for
 * SLA compliance. Checks whether contracts have exceeded their expected processing time
 * based on SLA_Configuration__mdt settings and sends breach notifications when SLAs
 * are violated.
 */
public with sharing class ContractSLAMonitorBatch implements Database.Batchable<SObject> {

    // SLA name constants matching SLA_Configuration__mdt records
    private static final String SLA_LEGAL_REVIEW = 'Legal Review';
    private static final String SLA_SIGNATURE_COLLECTION = 'Signature Collection';
    private static final String SLA_SUBMISSION_PROCESSING = 'Submission Processing';

    /**
     * @description Queries contracts currently in processing stages that may be subject
     * to SLA monitoring.
     * @param bc The batch context
     * @return QueryLocator for contracts in review or pending signature statuses
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Contract_Title__c, Status__c, Submission_Date__c,
                   Staff_Liaison__c, Branch_ED__c, Legal_Reviewer__c,
                   Counterparty_Name__c, Contract_Type__c, Contract_Value__c,
                   Contract_Subject_Picklist__c, Approval_Path__c,
                   Legal_Review_Required__c, SLA_Status__c
            FROM YGSF_Contract__c
            WHERE Status__c IN ('Submitted', 'Legal Review In Progress', 'Pending Signatures')
        ]);
    }

    /**
     * @description Evaluates each contract against its applicable SLA and sends breach
     * notifications for contracts that have exceeded their deadline.
     * @param bc The batch context
     * @param scope The list of YGSF_Contract__c records in this batch
     */
    public void execute(Database.BatchableContext bc, List<YGSF_Contract__c> scope) {
        Date today = Date.today();
        List<YGSF_Contract__c> contractsToUpdate = new List<YGSF_Contract__c>();

        for (YGSF_Contract__c contract : scope) {
            if (contract.Submission_Date__c == null) {
                continue;
            }

            String slaName = getSLANameForStatus(contract.Status__c);
            if (String.isBlank(slaName)) {
                continue;
            }

            Boolean withinSLA = SLACalculatorService.isWithinSLA(
                slaName, contract.Submission_Date__c, today
            );

            if (!withinSLA) {
                // SLA is breached - send notification
                ContractNotificationService.notifySLABreach(contract);

                // Update SLA status on the contract if not already marked
                if (contract.SLA_Status__c != 'Breached') {
                    contract.SLA_Status__c = 'Breached';
                    contractsToUpdate.add(contract);
                }
            }
        }

        if (!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }
    }

    /**
     * @description Logs batch completion.
     * @param bc The batch context
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'ContractSLAMonitorBatch completed.');
    }

    /**
     * @description Maps contract status to the appropriate SLA configuration name.
     * @param status The contract Status__c value
     * @return The SLA_Name__c to use for deadline calculation, or null if no SLA applies
     */
    @TestVisible
    private static String getSLANameForStatus(String status) {
        if (status == 'Submitted') {
            return SLA_SUBMISSION_PROCESSING;
        } else if (status == 'Legal Review In Progress') {
            return SLA_LEGAL_REVIEW;
        } else if (status == 'Pending Signatures') {
            return SLA_SIGNATURE_COLLECTION;
        }
        return null;
    }
}
