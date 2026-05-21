/**
 * @description Test class for ContractComplianceService. Validates submission and execution
 * compliance checks including required fields, COI validation, legal review requirements,
 * signatory completeness, and board approval.
 */
@IsTest
private class ContractComplianceServiceTest {

    /**
     * @description Verifies that validateForSubmission returns no errors for a contract
     * with all required fields populated.
     */
    @IsTest
    static void testSubmissionValidation() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract(
            'Facility Use Agreements', 'Agreement', 5000
        );
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Approval_Path__c = 'Section 3.2.4 - Branch ED Only';
        contract.Counterparty_Name__c = 'Test Counterparty';
        contract.Start_Date__c = Date.today();
        contract.End_Date__c = Date.today().addYears(1);

        Test.startTest();
        List<String> errors = ContractComplianceService.validateForSubmission(contract);
        Test.stopTest();

        System.assertEquals(0, errors.size(),
            'No errors should be returned for a fully populated contract. Errors: ' +
            String.join(errors, '; '));
    }

    /**
     * @description Verifies that validateForSubmission returns appropriate errors when
     * required fields are missing.
     */
    @IsTest
    static void testSubmissionValidationMissingFields() {
        YGSF_Contract__c contract = new YGSF_Contract__c(
            Status__c = 'Draft'
        );

        Test.startTest();
        List<String> errors = ContractComplianceService.validateForSubmission(contract);
        Test.stopTest();

        System.assert(!errors.isEmpty(),
            'Errors should be returned for a contract missing required fields');

        // Check for specific error messages
        Boolean hasTitleError = false;
        Boolean hasTypeError = false;
        Boolean hasSubjectError = false;
        Boolean hasCounterpartyError = false;
        Boolean hasStaffLiaisonError = false;
        Boolean hasBranchEDError = false;

        for (String error : errors) {
            if (error.contains('Contract Title')) hasTitleError = true;
            if (error.contains('Contract Type')) hasTypeError = true;
            if (error.contains('Contract Subject')) hasSubjectError = true;
            if (error.contains('Counterparty Name')) hasCounterpartyError = true;
            if (error.contains('Staff Liaison')) hasStaffLiaisonError = true;
            if (error.contains('Branch ED')) hasBranchEDError = true;
        }

        System.assert(hasTitleError, 'Should report missing Contract Title');
        System.assert(hasTypeError, 'Should report missing Contract Type');
        System.assert(hasSubjectError, 'Should report missing Contract Subject');
        System.assert(hasCounterpartyError, 'Should report missing Counterparty Name');
        System.assert(hasStaffLiaisonError, 'Should report missing Staff Liaison');
        System.assert(hasBranchEDError, 'Should report missing Branch ED');
    }

    /**
     * @description Verifies that validateForExecution returns an error when COI is
     * required but not received.
     */
    @IsTest
    static void testExecutionValidationMissingCOI() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.COI_Required__c = true;
        contract.COI_Received__c = false;
        insert contract;

        // Re-query to get the full record
        contract = [
            SELECT Id, COI_Required__c, COI_Received__c, COI_Expiration_Date__c,
                   Additional_Insured_Required__c, Additional_Insured_Received__c,
                   ICA_Approval_Form_Required__c, ICA_Approval_Form_Received__c,
                   Board_Approval_Required__c, Board_Approval_Date__c,
                   Legal_Review_Required__c, Legal_Review_Complete__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        Test.startTest();
        List<String> errors = ContractComplianceService.validateForExecution(contract);
        Test.stopTest();

        Boolean hasCOIError = false;
        for (String error : errors) {
            if (error.contains('Certificate of Insurance') || error.contains('COI')) {
                hasCOIError = true;
                break;
            }
        }

        System.assert(hasCOIError,
            'Execution validation should report missing COI when required but not received');
    }

    /**
     * @description Verifies that validateForExecution returns an error when legal review
     * is required before execution but has not been completed.
     */
    @IsTest
    static void testExecutionValidationMissingLegalReview() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Legal_Review_Required__c = 'Before Execution';
        contract.Legal_Review_Complete__c = false;
        insert contract;

        contract = [
            SELECT Id, COI_Required__c, COI_Received__c, COI_Expiration_Date__c,
                   Additional_Insured_Required__c, Additional_Insured_Received__c,
                   ICA_Approval_Form_Required__c, ICA_Approval_Form_Received__c,
                   Board_Approval_Required__c, Board_Approval_Date__c,
                   Legal_Review_Required__c, Legal_Review_Complete__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        Test.startTest();
        List<String> errors = ContractComplianceService.validateForExecution(contract);
        Test.stopTest();

        Boolean hasLegalError = false;
        for (String error : errors) {
            if (error.contains('Legal review') || error.contains('legal review')) {
                hasLegalError = true;
                break;
            }
        }

        System.assert(hasLegalError,
            'Execution validation should report incomplete legal review');
    }

    /**
     * @description Verifies that validateForSubmission returns null-safe results.
     */
    @IsTest
    static void testSubmissionValidationNullContract() {
        Test.startTest();
        List<String> errors = ContractComplianceService.validateForSubmission(null);
        Test.stopTest();

        System.assert(!errors.isEmpty(),
            'Should return an error for null contract');
        System.assert(errors[0].contains('required'),
            'Error should indicate contract record is required');
    }

    /**
     * @description Verifies the getComplianceStatus method returns a populated map
     * with expected check names.
     */
    @IsTest
    static void testGetComplianceStatus() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Counterparty_Name__c = 'Test Corp';
        contract.Approval_Path__c = 'Section 3.2.4 - Branch ED Only';
        insert contract;

        contract = [
            SELECT Id, Contract_Title__c, Contract_Type__c, Contract_Subject_Picklist__c,
                   Start_Date__c, End_Date__c, Desired_Execution_Date__c,
                   Counterparty_Name__c, Approval_Path__c,
                   Legal_Review_Required__c, Legal_Review_Complete__c,
                   COI_Required__c, COI_Received__c, COI_Expiration_Date__c,
                   Additional_Insured_Required__c, Additional_Insured_Received__c,
                   ICA_Approval_Form_Required__c, ICA_Approval_Form_Received__c,
                   Board_Approval_Required__c, Board_Approval_Date__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        Test.startTest();
        Map<String, Boolean> status = ContractComplianceService.getComplianceStatus(contract);
        Test.stopTest();

        System.assertNotEquals(null, status,
            'Compliance status map should not be null');
        System.assert(!status.isEmpty(),
            'Compliance status map should contain check results');
        System.assert(status.containsKey(ContractComplianceService.CHECK_REQUIRED_FIELDS),
            'Status should contain Required Fields check');
        System.assert(status.containsKey(ContractComplianceService.CHECK_COUNTERPARTY),
            'Status should contain Counterparty check');
        System.assert(status.containsKey(ContractComplianceService.CHECK_APPROVAL_PATH),
            'Status should contain Approval Path check');
    }
}
