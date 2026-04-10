/**
 * @description Apex controller for the contractDocumentChecklist Lightning Web Component.
 * Provides methods to query Contract_Document__c records and create new document
 * records when files are uploaded through the component.
 */
public with sharing class ContractDocumentController {

    /**
     * @description Retrieves all documents associated with a contract, ordered by upload date
     * (most recent first). Returns document metadata including type, status, and file info.
     * @param contractId The Id of the YGSF_Contract__c record
     * @return List of Contract_Document__c records with document details
     */
    @AuraEnabled(cacheable=true)
    public static List<Contract_Document__c> getDocuments(Id contractId) {
        if (contractId == null) {
            throw new AuraHandledException('Contract ID is required.');
        }

        return [
            SELECT Id, Name, Document_Type__c, File_Name__c, Upload_Date__c,
                   Expiration_Date__c, Status__c, ContentDocumentId__c
            FROM Contract_Document__c
            WHERE Contract__c = :contractId
            ORDER BY Upload_Date__c DESC
        ];
    }

    /**
     * @description Creates a new Contract_Document__c record linking an uploaded file to
     * a contract. Sets the upload date to today and initial status to 'Current'.
     * @param contractId The Id of the parent YGSF_Contract__c record
     * @param docType The document type (e.g., 'COI', 'ICA Approval Form')
     * @param fileName The name of the uploaded file
     * @param contentDocId The ContentDocument Id from the file upload
     * @return The newly created Contract_Document__c record
     */
    @AuraEnabled
    public static Contract_Document__c createDocument(Id contractId, String docType, String fileName, String contentDocId) {
        if (contractId == null) {
            throw new AuraHandledException('Contract ID is required.');
        }
        if (String.isBlank(docType)) {
            throw new AuraHandledException('Document type is required.');
        }
        if (String.isBlank(fileName)) {
            throw new AuraHandledException('File name is required.');
        }

        try {
            Contract_Document__c doc = new Contract_Document__c(
                Contract__c = contractId,
                Document_Type__c = docType,
                File_Name__c = fileName,
                ContentDocumentId__c = contentDocId,
                Upload_Date__c = Date.today(),
                Status__c = 'Current'
            );
            insert doc;
            return doc;
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to create document record: ' + e.getMessage());
        }
    }
}
