/**
 * @description Batch job that processes Certificate of Insurance (COI) documents
 * approaching expiration. Sends warning emails to the parent contract's Staff Liaison
 * for COIs expiring within 30 days, and marks COIs that have already expired.
 */
public with sharing class COIExpirationBatch implements Database.Batchable<SObject> {

    /**
     * @description Queries current COI documents that have an expiration date within the
     * next 30 days or that have already expired.
     * @param bc The batch context
     * @return QueryLocator for COI documents approaching or past expiration
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Document_Type__c, Status__c, Expiration_Date__c,
                   Contract__c, Contract__r.Contract_Title__c,
                   Contract__r.Staff_Liaison__c, Contract__r.Branch_ED__c,
                   Contract__r.Counterparty_Name__c, Contract__r.Auto_Renew__c,
                   Contract__r.End_Date__c
            FROM Contract_Document__c
            WHERE Document_Type__c = 'COI'
              AND Status__c = 'Current'
              AND Expiration_Date__c != null
              AND Expiration_Date__c <= NEXT_N_DAYS:30
        ]);
    }

    /**
     * @description Processes each batch of COI documents. Expires documents past their
     * expiration date and sends warning emails for those approaching expiration.
     * @param bc The batch context
     * @param scope The list of Contract_Document__c records in this batch
     */
    public void execute(Database.BatchableContext bc, List<Contract_Document__c> scope) {
        Date today = Date.today();
        List<Contract_Document__c> docsToUpdate = new List<Contract_Document__c>();

        for (Contract_Document__c doc : scope) {
            if (doc.Expiration_Date__c <= today) {
                // COI has expired - mark as Expired
                doc.Status__c = 'Expired';
                docsToUpdate.add(doc);
            } else {
                // COI is approaching expiration - send warning email
                Integer daysUntilExpiry = today.daysBetween(doc.Expiration_Date__c);
                sendCOIExpirationWarning(doc, daysUntilExpiry);
            }
        }

        if (!docsToUpdate.isEmpty()) {
            update docsToUpdate;
        }
    }

    /**
     * @description Logs batch completion.
     * @param bc The batch context
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'COIExpirationBatch completed.');
    }

    /**
     * @description Sends a COI expiration warning email to the parent contract's
     * Staff Liaison. Constructs a notification with contract and COI details.
     * @param doc The Contract_Document__c record with expiring COI
     * @param daysUntilExpiry Number of days until the COI expires
     */
    private void sendCOIExpirationWarning(Contract_Document__c doc, Integer daysUntilExpiry) {
        if (doc.Contract__r.Staff_Liaison__c == null) {
            return;
        }

        String contractTitle = String.isNotBlank(doc.Contract__r.Contract_Title__c)
            ? doc.Contract__r.Contract_Title__c
            : '(Untitled Contract)';

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(doc.Contract__r.Staff_Liaison__c);
        email.setSubject('YGSF Contract: COI Expiration Warning (' + daysUntilExpiry +
            ' days) - ' + contractTitle);
        email.setPlainTextBody(
            'The Certificate of Insurance (COI) for the following contract is expiring in ' +
            daysUntilExpiry + ' day(s).\n\n' +
            'Contract Title: ' + contractTitle + '\n' +
            'COI Expiration Date: ' + String.valueOf(doc.Expiration_Date__c) + '\n' +
            'Counterparty: ' + (String.isNotBlank(doc.Contract__r.Counterparty_Name__c)
                ? doc.Contract__r.Counterparty_Name__c : 'N/A') + '\n\n' +
            'Please request an updated COI from the counterparty to maintain compliance.'
        );
        email.setSaveAsActivity(false);

        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email }, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'COIExpirationBatch email error: ' + e.getMessage()
            );
        }
    }
}
