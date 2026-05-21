/**
 * @description Test class for ContractRenewalService. Validates contract renewal creation
 * including field cloning, date computation, status management, and Contract_Renewal__c
 * junction record creation.
 */
@IsTest
private class ContractRenewalServiceTest {

    /**
     * @description Verifies that creating a renewal from an existing contract produces
     * a new contract with Draft status, correct date range, and a linking
     * Contract_Renewal__c record. Also verifies the original contract is set to Renewed.
     */
    @IsTest
    static void testCreateRenewal() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c original = TestDataFactory.createContract(
            'Facility Use Agreements', 'Agreement', 10000
        );
        original.Staff_Liaison__c = testUser.Id;
        original.Branch_ED__c = testUser.Id;
        original.Status__c = 'Active';
        original.Start_Date__c = Date.today().addYears(-1);
        original.End_Date__c = Date.today();
        original.Renewal_Term_Months__c = 12;
        original.Auto_Renew__c = false;
        insert original;

        // Set status to Active
        original = [SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id = :original.Id];
        if (original.Status__c != 'Active') {
            original.Status__c = 'Active';
            update original;
        }

        Test.startTest();
        Id renewalId = ContractRenewalService.createRenewal(original.Id);
        Test.stopTest();

        System.assertNotEquals(null, renewalId,
            'Renewal contract Id should be returned');

        // Verify the renewed contract
        YGSF_Contract__c renewal = [
            SELECT Id, Status__c, Contract_Title__c, Contract_Subject_Picklist__c,
                   Contract_Value__c, Start_Date__c, End_Date__c, Renewal_Date__c,
                   Legal_Review_Complete__c, Execution_Date__c, Submission_Date__c
            FROM YGSF_Contract__c
            WHERE Id = :renewalId
        ];

        System.assertEquals('Draft', renewal.Status__c,
            'Renewal contract should have Draft status');
        System.assertEquals('Facility Use Agreements', renewal.Contract_Subject_Picklist__c,
            'Renewal should inherit subject from original');
        System.assertEquals(10000, renewal.Contract_Value__c,
            'Renewal should inherit value from original');
        System.assertEquals(Date.today().addDays(1), renewal.Start_Date__c,
            'Renewal start date should be day after original end date');
        System.assertEquals(false, renewal.Legal_Review_Complete__c,
            'Legal review complete should be cleared on renewal');
        System.assertEquals(null, renewal.Execution_Date__c,
            'Execution date should be cleared on renewal');
        System.assertEquals(null, renewal.Submission_Date__c,
            'Submission date should be cleared on renewal');

        // Verify the Contract_Renewal__c junction record
        List<Contract_Renewal__c> renewalRecords = [
            SELECT Id, Original_Contract__c, Renewed_Contract__c, Renewal_Type__c,
                   Previous_Value__c, New_Value__c
            FROM Contract_Renewal__c
            WHERE Original_Contract__c = :original.Id
        ];

        System.assertEquals(1, renewalRecords.size(),
            'One Contract_Renewal__c record should be created');
        System.assertEquals(renewalId, renewalRecords[0].Renewed_Contract__c,
            'Renewal record should link to the new contract');
        System.assertEquals('Manual', renewalRecords[0].Renewal_Type__c,
            'Renewal type should be Manual for non-auto-renew contracts');
        System.assertEquals(10000, renewalRecords[0].Previous_Value__c,
            'Previous value should match original contract value');

        // Verify original contract status changed to Renewed
        YGSF_Contract__c updatedOriginal = [
            SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id = :original.Id
        ];
        System.assertEquals('Renewed', updatedOriginal.Status__c,
            'Original contract should be set to Renewed status');
    }

    /**
     * @description Verifies that creating a renewal with override values applies the
     * overrides to the new contract instead of inheriting from the original.
     */
    @IsTest
    static void testCreateRenewalWithOverrides() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c original = TestDataFactory.createContract(
            'Facility Use Agreements', 'Agreement', 10000
        );
        original.Staff_Liaison__c = testUser.Id;
        original.Branch_ED__c = testUser.Id;
        original.Status__c = 'Active';
        original.End_Date__c = Date.today();
        original.Renewal_Term_Months__c = 12;
        insert original;

        original = [SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id = :original.Id];
        if (original.Status__c != 'Active') {
            original.Status__c = 'Active';
            update original;
        }

        Decimal newValue = 15000;
        Date newStart = Date.today().addMonths(1);
        Date newEnd = Date.today().addMonths(13);

        Test.startTest();
        Id renewalId = ContractRenewalService.createRenewal(
            original.Id, newValue, newStart, newEnd
        );
        Test.stopTest();

        YGSF_Contract__c renewal = [
            SELECT Id, Contract_Value__c, Start_Date__c, End_Date__c
            FROM YGSF_Contract__c
            WHERE Id = :renewalId
        ];

        System.assertEquals(newValue, renewal.Contract_Value__c,
            'Renewal should use the override value');
        System.assertEquals(newStart, renewal.Start_Date__c,
            'Renewal should use the override start date');
        System.assertEquals(newEnd, renewal.End_Date__c,
            'Renewal should use the override end date');
    }

    /**
     * @description Verifies that createRenewal throws an exception when given a null
     * contract Id.
     */
    @IsTest
    static void testCreateRenewalNullId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ContractRenewalService.createRenewal(null);
        } catch (ContractRenewalService.ContractRenewalException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('required'),
                'Exception message should indicate Id is required');
        }
        Test.stopTest();

        System.assert(exceptionThrown,
            'Exception should be thrown for null contract Id');
    }
}
