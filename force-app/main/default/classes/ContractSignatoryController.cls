/**
 * @description Apex controller for the contractSignatureTracker Lightning Web Component.
 * Provides methods to query and update Contract_Signatory__c records for display
 * in the signature tracking datatable.
 */
public with sharing class ContractSignatoryController {

    /**
     * @description Retrieves all signatories for a given contract, ordered by signature order.
     * Returns signatory details including related user names and delegation information.
     * @param contractId The Id of the YGSF_Contract__c record
     * @return List of Contract_Signatory__c records with related fields
     */
    @AuraEnabled(cacheable=true)
    public static List<Contract_Signatory__c> getSignatories(Id contractId) {
        if (contractId == null) {
            throw new AuraHandledException('Contract ID is required.');
        }

        return [
            SELECT Id, Name, Signatory__c, Signatory__r.Name, Signatory_Role__c,
                   Required__c, Signed__c, Signed_Date__c, Signature_Order__c,
                   Delegated_From__c, Delegated_From__r.Name
            FROM Contract_Signatory__c
            WHERE Contract__c = :contractId
            ORDER BY Signature_Order__c ASC
        ];
    }

    /**
     * @description Marks a signatory as having signed by setting Signed__c to true
     * and Signed_Date__c to today's date.
     * @param signatoryId The Id of the Contract_Signatory__c record to update
     */
    @AuraEnabled
    public static void markAsSigned(Id signatoryId) {
        if (signatoryId == null) {
            throw new AuraHandledException('Signatory ID is required.');
        }

        try {
            Contract_Signatory__c sig = [
                SELECT Id, Signed__c, Signed_Date__c
                FROM Contract_Signatory__c
                WHERE Id = :signatoryId
                LIMIT 1
            ];

            if (sig.Signed__c) {
                throw new AuraHandledException('This signatory has already been marked as signed.');
            }

            sig.Signed__c = true;
            sig.Signed_Date__c = Date.today();
            update sig;
        } catch (QueryException e) {
            throw new AuraHandledException('Signatory record not found.');
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to update signatory: ' + e.getMessage());
        }
    }
}
