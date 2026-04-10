/**
 * @description Test class for ContractDocumentTriggerHandler. Validates upload date
 * auto-setting, expiration status changes, and parent contract flag updates when
 * documents are uploaded.
 */
@IsTest
private class ContractDocumentTriggerHandlerTest {

    /**
     * @description Verifies that inserting a Contract_Document__c without an Upload_Date__c
     * automatically sets it to today.
     */
    @IsTest
    static void testUploadDateAutoSet() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();
        insert contract;

        Contract_Document__c doc = TestDataFactory.createContractDocument(contract.Id, 'COI');
        doc.Upload_Date__c = null; // Ensure it's blank

        Test.startTest();
        insert doc;
        Test.stopTest();

        Contract_Document__c inserted = [
            SELECT Id, Upload_Date__c
            FROM Contract_Document__c
            WHERE Id = :doc.Id
        ];

        System.assertEquals(Date.today(), inserted.Upload_Date__c,
            'Upload_Date__c should be automatically set to today when not provided');
    }

    /**
     * @description Verifies that uploading a COI document updates the parent contract's
     * COI_Received__c flag to true.
     */
    @IsTest
    static void testCOIUploadUpdatesParent() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();
        contract.COI_Required__c = true;
        insert contract;

        // Verify parent starts with COI_Received__c = false
        YGSF_Contract__c beforeDoc = [
            SELECT Id, COI_Received__c FROM YGSF_Contract__c WHERE Id = :contract.Id
        ];
        System.assertEquals(false, beforeDoc.COI_Received__c,
            'COI_Received__c should be false before document upload');

        Contract_Document__c doc = TestDataFactory.createContractDocument(contract.Id, 'COI');

        Test.startTest();
        insert doc;
        Test.stopTest();

        YGSF_Contract__c afterDoc = [
            SELECT Id, COI_Received__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals(true, afterDoc.COI_Received__c,
            'COI_Received__c should be true after COI document upload');
    }

    /**
     * @description Verifies that uploading an Additional Insured Endorsement document
     * updates the parent contract's Additional_Insured_Received__c flag to true.
     */
    @IsTest
    static void testEndorsementUploadUpdatesParent() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();
        contract.Additional_Insured_Required__c = true;
        insert contract;

        Contract_Document__c doc = TestDataFactory.createContractDocument(
            contract.Id, 'Additional Insured Endorsement'
        );

        Test.startTest();
        insert doc;
        Test.stopTest();

        YGSF_Contract__c afterDoc = [
            SELECT Id, Additional_Insured_Received__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals(true, afterDoc.Additional_Insured_Received__c,
            'Additional_Insured_Received__c should be true after endorsement upload');
    }

    /**
     * @description Verifies that updating a document with an expired Expiration_Date__c
     * sets the document's Status__c to Expired.
     */
    @IsTest
    static void testExpiredDocumentStatusUpdate() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();
        insert contract;

        Contract_Document__c doc = TestDataFactory.createContractDocument(contract.Id, 'COI');
        doc.Expiration_Date__c = Date.today().addDays(30);
        insert doc;

        Test.startTest();
        doc.Expiration_Date__c = Date.today().addDays(-1);
        update doc;
        Test.stopTest();

        Contract_Document__c updated = [
            SELECT Id, Status__c, Expiration_Date__c
            FROM Contract_Document__c
            WHERE Id = :doc.Id
        ];

        System.assertEquals('Expired', updated.Status__c,
            'Document Status__c should be set to Expired when Expiration_Date__c is in the past');
    }

    /**
     * @description Verifies that uploading an ICA Approval Form updates the parent contract's
     * ICA_Approval_Form_Received__c flag.
     */
    @IsTest
    static void testICAFormUploadUpdatesParent() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();
        contract.ICA_Approval_Form_Required__c = true;
        insert contract;

        Contract_Document__c doc = TestDataFactory.createContractDocument(
            contract.Id, 'ICA Approval Form'
        );

        Test.startTest();
        insert doc;
        Test.stopTest();

        YGSF_Contract__c afterDoc = [
            SELECT Id, ICA_Approval_Form_Received__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals(true, afterDoc.ICA_Approval_Form_Received__c,
            'ICA_Approval_Form_Received__c should be true after ICA form upload');
    }
}
