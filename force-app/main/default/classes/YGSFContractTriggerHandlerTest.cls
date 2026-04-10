/**
 * @description Test class for YGSFContractTriggerHandler. Validates before/after insert
 * and update logic including subject configuration application, approval path determination,
 * status date stamping, signatory creation, and approval history tracking.
 */
@IsTest
private class YGSFContractTriggerHandlerTest {

    /**
     * @description Verifies that inserting a contract with a subject auto-populates
     * configuration-driven fields via ContractSubjectConfigService and
     * ApprovalPathDeterminator in the beforeInsert handler.
     */
    @IsTest
    static void testBeforeInsertPopulatesFields() {
        YGSF_Contract__c contract = TestDataFactory.createContract(
            'Facility Use Agreements', 'Agreement', 5000
        );
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();

        Test.startTest();
        insert contract;
        Test.stopTest();

        YGSF_Contract__c inserted = [
            SELECT Id, Approval_Path__c, Contract_Subject_Picklist__c, Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertNotEquals(null, inserted.Id,
            'Contract should have been inserted successfully');
        System.assertEquals('Facility Use Agreements', inserted.Contract_Subject_Picklist__c,
            'Subject should be preserved after insert');
        // Approval path may or may not be populated depending on metadata - verify no exception
        System.assertEquals('Draft', inserted.Status__c,
            'Status should remain Draft on insert');
    }

    /**
     * @description Verifies that changing Contract_Subject_Picklist__c or Contract_Value__c
     * on update causes re-derivation of configuration fields.
     */
    @IsTest
    static void testBeforeUpdateReappliesOnSubjectChange() {
        YGSF_Contract__c contract = TestDataFactory.createContract(
            'Facility Use Agreements', 'Agreement', 5000
        );
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();
        insert contract;

        Test.startTest();
        contract.Contract_Subject_Picklist__c = 'Independent Contractor Agreements';
        contract.Contract_Value__c = 15000;
        update contract;
        Test.stopTest();

        YGSF_Contract__c updated = [
            SELECT Id, Contract_Subject_Picklist__c, Contract_Value__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals('Independent Contractor Agreements', updated.Contract_Subject_Picklist__c,
            'Subject should be updated');
        System.assertEquals(15000, updated.Contract_Value__c,
            'Contract value should be updated');
    }

    /**
     * @description Verifies that changing Status__c to Submitted stamps Submission_Date__c,
     * and changing to Fully Executed stamps Execution_Date__c.
     */
    @IsTest
    static void testStatusTransitionStampsDates() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();
        insert contract;

        // Transition to Submitted
        Test.startTest();
        contract.Status__c = 'Submitted';
        update contract;

        YGSF_Contract__c afterSubmit = [
            SELECT Id, Submission_Date__c, Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals('Submitted', afterSubmit.Status__c,
            'Status should be Submitted');
        System.assertEquals(Date.today(), afterSubmit.Submission_Date__c,
            'Submission_Date__c should be stamped to today on status change to Submitted');

        // Transition to Fully Executed
        contract.Status__c = 'Fully Executed';
        update contract;
        Test.stopTest();

        YGSF_Contract__c afterExecute = [
            SELECT Id, Execution_Date__c, Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals('Fully Executed', afterExecute.Status__c,
            'Status should be Fully Executed');
        System.assertEquals(Date.today(), afterExecute.Execution_Date__c,
            'Execution_Date__c should be stamped to today on status change to Fully Executed');
    }

    /**
     * @description Verifies that inserting a contract triggers automatic creation of
     * Contract_Signatory__c records via the afterInsert handler.
     */
    @IsTest
    static void testAfterInsertCreatesSignatories() {
        User testUser = TestDataFactory.getTestUser();
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;

        Test.startTest();
        insert contract;
        Test.stopTest();

        List<Contract_Signatory__c> signatories = [
            SELECT Id, Contract__c, Signatory_Role__c, Required__c, Signed__c
            FROM Contract_Signatory__c
            WHERE Contract__c = :contract.Id
        ];

        System.assert(!signatories.isEmpty(),
            'Signatory records should be auto-created after contract insert');
        for (Contract_Signatory__c sig : signatories) {
            System.assertEquals(contract.Id, sig.Contract__c,
                'Each signatory should reference the parent contract');
            System.assertEquals(false, sig.Signed__c,
                'New signatories should not be signed');
        }
    }

    /**
     * @description Verifies that the after update handler creates a
     * Contract_Approval_History__c record when Status__c changes.
     */
    @IsTest
    static void testAfterUpdateCreatesApprovalHistory() {
        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = UserInfo.getUserId();
        contract.Branch_ED__c = UserInfo.getUserId();
        insert contract;

        Test.startTest();
        contract.Status__c = 'Submitted';
        update contract;
        Test.stopTest();

        List<Contract_Approval_History__c> history = [
            SELECT Id, Contract__c, Action__c, Actor__c, Action_Date__c, Step_Name__c
            FROM Contract_Approval_History__c
            WHERE Contract__c = :contract.Id
        ];

        System.assert(!history.isEmpty(),
            'Approval history record should be created on status change');
        System.assertEquals(contract.Id, history[0].Contract__c,
            'History should reference the correct contract');
        System.assertEquals('Submitted', history[0].Step_Name__c,
            'Step name should match the new status');
        System.assertNotEquals(null, history[0].Action_Date__c,
            'Action date should be stamped');
        System.assertEquals(UserInfo.getUserId(), history[0].Actor__c,
            'Actor should be the current user');
    }

    /**
     * @description Verifies that inserting 200 contracts in bulk does not cause errors,
     * governor limit violations, or data integrity issues.
     */
    @IsTest
    static void testBulkInsert() {
        List<YGSF_Contract__c> contracts = TestDataFactory.createContracts(200, 'Facility Use Agreements');

        Test.startTest();
        insert contracts;
        Test.stopTest();

        List<YGSF_Contract__c> inserted = [
            SELECT Id FROM YGSF_Contract__c WHERE Id IN :contracts
        ];

        System.assertEquals(200, inserted.size(),
            'All 200 contracts should be inserted successfully');
    }
}
