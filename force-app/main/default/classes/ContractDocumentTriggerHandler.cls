/**
 * @description Trigger handler for Contract_Document__c. Manages upload date defaults,
 * expiration status checks, and parent contract flag updates when documents are
 * uploaded (e.g., COI, endorsement, ICA form).
 */
public with sharing class ContractDocumentTriggerHandler {

    // Document type constants matching the Contract_Document__c.Document_Type__c picklist
    private static final String DOC_TYPE_COI = 'COI';
    private static final String DOC_TYPE_ENDORSEMENT = 'Additional Insured Endorsement';
    private static final String DOC_TYPE_ICA_FORM = 'ICA Approval Form';

    /**
     * @description Before insert: set Upload_Date__c to today if not already populated.
     * @param newDocuments The list of Contract_Document__c being inserted
     */
    public void beforeInsert(List<Contract_Document__c> newDocuments) {
        for (Contract_Document__c doc : newDocuments) {
            if (doc.Upload_Date__c == null) {
                doc.Upload_Date__c = Date.today();
            }
        }
    }

    /**
     * @description Before update: if Expiration_Date__c is in the past, set Status__c to Expired.
     * @param newDocuments The updated Contract_Document__c records
     * @param oldMap Map of old record versions keyed by Id
     */
    public void beforeUpdate(List<Contract_Document__c> newDocuments, Map<Id, Contract_Document__c> oldMap) {
        for (Contract_Document__c doc : newDocuments) {
            if (doc.Expiration_Date__c != null && doc.Expiration_Date__c < Date.today()) {
                doc.Status__c = 'Expired';
            }
        }
    }

    /**
     * @description After insert: check if uploaded document satisfies a parent contract
     * compliance requirement and update the parent accordingly.
     * @param newDocuments The newly inserted Contract_Document__c records
     */
    public void afterInsert(List<Contract_Document__c> newDocuments) {
        updateParentContractFlags(newDocuments);
    }

    /**
     * @description After update: re-check parent contract flags on document updates
     * (e.g., document type change or status change).
     * @param newDocuments The updated Contract_Document__c records
     * @param oldMap Map of old record versions keyed by Id
     */
    public void afterUpdate(List<Contract_Document__c> newDocuments, Map<Id, Contract_Document__c> oldMap) {
        updateParentContractFlags(newDocuments);
    }

    /**
     * @description Queries parent contracts for the given documents and updates compliance
     * flags based on the document type. Sets COI_Received__c, Additional_Insured_Received__c,
     * or ICA_Approval_Form_Received__c to true when matching documents are uploaded.
     * @param documents The Contract_Document__c records to process
     */
    private void updateParentContractFlags(List<Contract_Document__c> documents) {
        // Collect contract Ids and determine which flags need updating
        Map<Id, Set<String>> contractDocTypes = new Map<Id, Set<String>>();

        for (Contract_Document__c doc : documents) {
            if (doc.Contract__c == null || String.isBlank(doc.Document_Type__c)) {
                continue;
            }
            // Only process document types that map to parent flags
            if (doc.Document_Type__c == DOC_TYPE_COI ||
                doc.Document_Type__c == DOC_TYPE_ENDORSEMENT ||
                doc.Document_Type__c == DOC_TYPE_ICA_FORM) {
                if (!contractDocTypes.containsKey(doc.Contract__c)) {
                    contractDocTypes.put(doc.Contract__c, new Set<String>());
                }
                contractDocTypes.get(doc.Contract__c).add(doc.Document_Type__c);
            }
        }

        if (contractDocTypes.isEmpty()) {
            return;
        }

        // Query parent contracts and update flags
        List<YGSF_Contract__c> contractsToUpdate = [
            SELECT Id, COI_Received__c, Additional_Insured_Received__c, ICA_Approval_Form_Received__c
            FROM YGSF_Contract__c
            WHERE Id IN :contractDocTypes.keySet()
        ];

        List<YGSF_Contract__c> updatedContracts = new List<YGSF_Contract__c>();

        for (YGSF_Contract__c contract : contractsToUpdate) {
            Set<String> docTypes = contractDocTypes.get(contract.Id);
            Boolean changed = false;

            if (docTypes.contains(DOC_TYPE_COI) && !contract.COI_Received__c) {
                contract.COI_Received__c = true;
                changed = true;
            }
            if (docTypes.contains(DOC_TYPE_ENDORSEMENT) && !contract.Additional_Insured_Received__c) {
                contract.Additional_Insured_Received__c = true;
                changed = true;
            }
            if (docTypes.contains(DOC_TYPE_ICA_FORM) && !contract.ICA_Approval_Form_Received__c) {
                contract.ICA_Approval_Form_Received__c = true;
                changed = true;
            }

            if (changed) {
                updatedContracts.add(contract);
            }
        }

        if (!updatedContracts.isEmpty()) {
            update updatedContracts;
        }
    }
}
