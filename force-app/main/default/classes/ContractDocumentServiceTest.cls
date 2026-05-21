/**
 * @description Test class for ContractDocumentService. Validates document requirement
 * determination, missing document detection, and document completeness validation.
 */
@IsTest
private class ContractDocumentServiceTest {

    /**
     * @description Verifies that getRequiredDocumentTypes returns the correct document
     * types based on contract configuration flags (COI, Additional Insured, etc.).
     */
    @IsTest
    static void testGetRequiredDocumentTypes() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.COI_Required__c = true;
        contract.Additional_Insured_Required__c = true;
        contract.ICA_Approval_Form_Required__c = false;
        contract.Board_Approval_Required__c = false;

        Test.startTest();
        List<String> requiredTypes = ContractDocumentService.getRequiredDocumentTypes(contract);
        Test.stopTest();

        System.assertEquals(2, requiredTypes.size(),
            'Should return 2 required document types (COI and Additional Insured)');
        System.assert(requiredTypes.contains(ContractDocumentService.DOC_TYPE_COI),
            'Required types should include Certificate of Insurance');
        System.assert(requiredTypes.contains(ContractDocumentService.DOC_TYPE_ADDITIONAL_INSURED),
            'Required types should include Additional Insured Endorsement');
    }

    /**
     * @description Verifies that getRequiredDocumentTypes returns all four document types
     * when all requirement flags are true.
     */
    @IsTest
    static void testGetAllRequiredDocumentTypes() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.COI_Required__c = true;
        contract.Additional_Insured_Required__c = true;
        contract.ICA_Approval_Form_Required__c = true;
        contract.Board_Approval_Required__c = true;

        Test.startTest();
        List<String> requiredTypes = ContractDocumentService.getRequiredDocumentTypes(contract);
        Test.stopTest();

        System.assertEquals(4, requiredTypes.size(),
            'Should return 4 required document types when all flags are true');
    }

    /**
     * @description Verifies that getMissingDocuments correctly identifies document types
     * that are required but have not been uploaded.
     */
    @IsTest
    static void testMissingDocuments() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.COI_Required__c = true;
        contract.Additional_Insured_Required__c = true;
        contract.ICA_Approval_Form_Required__c = false;
        contract.Board_Approval_Required__c = false;
        insert contract;

        // Upload only the COI, leaving Additional Insured missing
        Contract_Document__c coiDoc = new Contract_Document__c(
            Contract__c = contract.Id,
            Document_Type__c = 'Certificate of Insurance',
            Status__c = 'Current',
            File_Name__c = 'coi.pdf'
        );
        insert coiDoc;

        Test.startTest();
        List<String> missingDocs = ContractDocumentService.getMissingDocuments(contract.Id);
        Test.stopTest();

        System.assertEquals(1, missingDocs.size(),
            'Should identify 1 missing document type');
        System.assertEquals(ContractDocumentService.DOC_TYPE_ADDITIONAL_INSURED, missingDocs[0],
            'Missing document should be Additional Insured Endorsement');
    }

    /**
     * @description Verifies that validateDocumentCompleteness returns true when all
     * required documents are uploaded.
     */
    @IsTest
    static void testDocumentCompletenessAllUploaded() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.COI_Required__c = true;
        contract.Additional_Insured_Required__c = false;
        contract.ICA_Approval_Form_Required__c = false;
        contract.Board_Approval_Required__c = false;
        insert contract;

        // Upload the required COI
        Contract_Document__c coiDoc = new Contract_Document__c(
            Contract__c = contract.Id,
            Document_Type__c = 'Certificate of Insurance',
            Status__c = 'Current',
            File_Name__c = 'coi.pdf'
        );
        insert coiDoc;

        Test.startTest();
        Boolean isComplete = ContractDocumentService.validateDocumentCompleteness(contract.Id);
        Test.stopTest();

        System.assertEquals(true, isComplete,
            'Document completeness should be true when all required docs are uploaded');
    }

    /**
     * @description Verifies that validateDocumentCompleteness returns false when a
     * required document is missing.
     */
    @IsTest
    static void testDocumentCompletenessIncomplete() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.COI_Required__c = true;
        contract.Additional_Insured_Required__c = true;
        contract.ICA_Approval_Form_Required__c = false;
        contract.Board_Approval_Required__c = false;
        insert contract;

        // Only upload COI, leaving Additional Insured missing
        Contract_Document__c coiDoc = new Contract_Document__c(
            Contract__c = contract.Id,
            Document_Type__c = 'Certificate of Insurance',
            Status__c = 'Current',
            File_Name__c = 'coi.pdf'
        );
        insert coiDoc;

        Test.startTest();
        Boolean isComplete = ContractDocumentService.validateDocumentCompleteness(contract.Id);
        Test.stopTest();

        System.assertEquals(false, isComplete,
            'Document completeness should be false when required docs are missing');
    }

    /**
     * @description Verifies null and edge case handling for getMissingDocuments.
     */
    @IsTest
    static void testMissingDocumentsNullId() {
        Test.startTest();
        List<String> result = ContractDocumentService.getMissingDocuments(null);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'Should return an empty list, not null');
        System.assertEquals(0, result.size(),
            'Should return empty list for null contract Id');
    }

    /**
     * @description Verifies that getRequiredDocumentTypes returns empty list for contracts
     * with no document requirements.
     */
    @IsTest
    static void testNoRequiredDocumentTypes() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.COI_Required__c = false;
        contract.Additional_Insured_Required__c = false;
        contract.ICA_Approval_Form_Required__c = false;
        contract.Board_Approval_Required__c = false;

        Test.startTest();
        List<String> requiredTypes = ContractDocumentService.getRequiredDocumentTypes(contract);
        Test.stopTest();

        System.assertEquals(0, requiredTypes.size(),
            'Should return empty list when no documents are required');
    }

    /**
     * @description Verifies that getRequiredDocumentTypes handles null contract input.
     */
    @IsTest
    static void testGetRequiredDocumentTypesNull() {
        Test.startTest();
        List<String> result = ContractDocumentService.getRequiredDocumentTypes(null);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'Should return empty list, not null');
        System.assertEquals(0, result.size(),
            'Should return empty list for null contract');
    }
}
