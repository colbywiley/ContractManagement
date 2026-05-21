/**
 * @description Service class for validating contract document requirements. Determines
 * which document types are required based on contract configuration (COI, Additional
 * Insured endorsement, ICA Approval Form, etc.) and checks whether those documents
 * have been uploaded.
 */
public with sharing class ContractDocumentService {

    // Document type constants matching Contract_Document__c.Document_Type__c picklist values
    public static final String DOC_TYPE_COI = 'Certificate of Insurance';
    public static final String DOC_TYPE_ADDITIONAL_INSURED = 'Additional Insured Endorsement';
    public static final String DOC_TYPE_ICA_FORM = 'ICA Approval Form';
    public static final String DOC_TYPE_EXECUTED_CONTRACT = 'Executed Contract';
    public static final String DOC_TYPE_BOARD_APPROVAL = 'Board Approval';

    /**
     * @description Determines which document types are required for the given contract
     * based on its configuration flags (COI_Required__c, Additional_Insured_Required__c,
     * ICA_Approval_Form_Required__c, Board_Approval_Required__c).
     * @param contract The YGSF_Contract__c record to evaluate
     * @return List of required document type strings
     */
    public static List<String> getRequiredDocumentTypes(YGSF_Contract__c contract) {
        List<String> requiredTypes = new List<String>();

        if (contract == null) {
            return requiredTypes;
        }

        if (contract.COI_Required__c) {
            requiredTypes.add(DOC_TYPE_COI);
        }

        if (contract.Additional_Insured_Required__c) {
            requiredTypes.add(DOC_TYPE_ADDITIONAL_INSURED);
        }

        if (contract.ICA_Approval_Form_Required__c) {
            requiredTypes.add(DOC_TYPE_ICA_FORM);
        }

        if (contract.Board_Approval_Required__c) {
            requiredTypes.add(DOC_TYPE_BOARD_APPROVAL);
        }

        return requiredTypes;
    }

    /**
     * @description Identifies which required document types have not yet been uploaded
     * for the given contract. Queries existing Contract_Document__c records and compares
     * against the required types.
     * @param contractId The Id of the YGSF_Contract__c to check
     * @return List of document type strings that are required but missing
     */
    public static List<String> getMissingDocuments(Id contractId) {
        if (contractId == null) {
            return new List<String>();
        }

        // Query the full contract to determine requirements
        List<YGSF_Contract__c> contracts = [
            SELECT Id, COI_Required__c, Additional_Insured_Required__c,
                   ICA_Approval_Form_Required__c, Board_Approval_Required__c
            FROM YGSF_Contract__c
            WHERE Id = :contractId
            LIMIT 1
        ];

        if (contracts.isEmpty()) {
            return new List<String>();
        }

        YGSF_Contract__c contract = contracts[0];
        List<String> requiredTypes = getRequiredDocumentTypes(contract);

        if (requiredTypes.isEmpty()) {
            return new List<String>();
        }

        // Query existing documents and collect their types into a set
        Set<String> uploadedTypes = new Set<String>();
        for (Contract_Document__c doc : [
            SELECT Document_Type__c
            FROM Contract_Document__c
            WHERE Contract__c = :contractId
              AND Document_Type__c IN :requiredTypes
        ]) {
            if (String.isNotBlank(doc.Document_Type__c)) {
                uploadedTypes.add(doc.Document_Type__c);
            }
        }

        // Identify missing types
        List<String> missingTypes = new List<String>();
        for (String requiredType : requiredTypes) {
            if (!uploadedTypes.contains(requiredType)) {
                missingTypes.add(requiredType);
            }
        }

        return missingTypes;
    }

    /**
     * @description Validates whether all required documents have been uploaded for
     * the given contract.
     * @param contractId The Id of the YGSF_Contract__c to validate
     * @return True if all required document types are present, false otherwise
     */
    public static Boolean validateDocumentCompleteness(Id contractId) {
        List<String> missing = getMissingDocuments(contractId);
        return missing.isEmpty();
    }
}
