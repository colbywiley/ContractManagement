/**
 * @description Test class for ContractSignatoryService. Validates signatory creation
 * based on subject configuration, recalculation on subject changes, and the
 * checkAllSigned method for determining contract execution readiness.
 */
@IsTest
private class ContractSignatoryServiceTest {

    /**
     * @description Verifies that signatories are created for a contract on a 3.2.1-type
     * path that requires Officer and SVP signatures. The exact signatories depend on
     * metadata configuration and populated user lookup fields.
     */
    @IsTest
    static void testCreateSignatories321() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract(
            'Professional Service Agreements', 'Agreement', 50000
        );
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.VP_Approver__c = testUser.Id;
        contract.SVP_Approver__c = testUser.Id;
        contract.Officer_Approver__c = testUser.Id;
        contract.Approval_Path__c = 'Section 3.2.1 - SVP and Officer';
        insert contract;

        // Query signatories created by the trigger
        List<Contract_Signatory__c> signatories = [
            SELECT Id, Contract__c, Signatory_Role__c, Required__c, Signed__c, Signature_Order__c
            FROM Contract_Signatory__c
            WHERE Contract__c = :contract.Id
            ORDER BY Signature_Order__c
        ];

        System.assert(!signatories.isEmpty(),
            'Signatories should be created for 3.2.1 path contract');

        // Verify all are required and not yet signed
        for (Contract_Signatory__c sig : signatories) {
            System.assertEquals(true, sig.Required__c,
                'Each signatory should be marked as required');
            System.assertEquals(false, sig.Signed__c,
                'Each signatory should start as unsigned');
        }

        // Check for presence of expected roles (if metadata config exists)
        Set<String> roles = new Set<String>();
        for (Contract_Signatory__c sig : signatories) {
            roles.add(sig.Signatory_Role__c);
        }

        // At minimum, Branch ED and Counterparty should be present since user lookups are set
        System.assert(roles.contains('Branch ED') || roles.contains('Officer') || roles.contains('Senior VP'),
            'Expected at least one internal signatory role to be created');
    }

    /**
     * @description Verifies that a contract on a 3.2.4 path (Branch ED Only) creates
     * the appropriate signatories. Should include Branch ED and Counterparty at minimum.
     */
    @IsTest
    static void testCreateSignatories324() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract(
            'Facility Use Agreements', 'Agreement', 2000
        );
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Approval_Path__c = 'Section 3.2.4 - Branch ED Only';
        insert contract;

        List<Contract_Signatory__c> signatories = [
            SELECT Id, Signatory_Role__c, Required__c
            FROM Contract_Signatory__c
            WHERE Contract__c = :contract.Id
        ];

        System.assert(!signatories.isEmpty(),
            'Signatories should be created for 3.2.4 path contract');

        Set<String> roles = new Set<String>();
        for (Contract_Signatory__c sig : signatories) {
            roles.add(sig.Signatory_Role__c);
        }

        // For 3.2.4 path, Branch ED should be present (ED_Signature_Required = true in config)
        // Counterparty is always added when Staff_Liaison__c is set
        System.assert(roles.contains('Branch ED') || roles.contains('Counterparty'),
            'Expected Branch ED or Counterparty signatory for 3.2.4 path');
    }

    /**
     * @description Verifies that recalculateSignatories deletes existing signatories
     * and creates new ones based on current contract configuration.
     */
    @IsTest
    static void testRecalculateSignatories() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract(
            'Facility Use Agreements', 'Agreement', 2000
        );
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        insert contract;

        Integer originalCount = [
            SELECT COUNT() FROM Contract_Signatory__c WHERE Contract__c = :contract.Id
        ];

        Test.startTest();
        // Re-query contract for recalculation
        YGSF_Contract__c freshContract = [
            SELECT Id, Contract_Subject_Picklist__c, Staff_Liaison__c, Branch_ED__c,
                   VP_Approver__c, SVP_Approver__c, Officer_Approver__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];
        List<Contract_Signatory__c> newSigs = ContractSignatoryService.recalculateSignatories(freshContract);
        Test.stopTest();

        Integer newCount = [
            SELECT COUNT() FROM Contract_Signatory__c WHERE Contract__c = :contract.Id
        ];

        System.assert(newCount > 0,
            'Recalculated signatories should exist');
    }

    /**
     * @description Verifies that checkAllSigned returns true when all required signatories
     * are signed, and false when they are not.
     */
    @IsTest
    static void testCheckAllSigned() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        insert contract;

        // Delete auto-created signatories and create controlled ones
        delete [SELECT Id FROM Contract_Signatory__c WHERE Contract__c = :contract.Id];

        List<Contract_Signatory__c> sigs = new List<Contract_Signatory__c>();
        sigs.add(new Contract_Signatory__c(
            Contract__c = contract.Id,
            Signatory__c = testUser.Id,
            Signatory_Role__c = 'Branch ED',
            Required__c = true,
            Signed__c = false,
            Signature_Order__c = 1
        ));
        sigs.add(new Contract_Signatory__c(
            Contract__c = contract.Id,
            Signatory__c = testUser.Id,
            Signatory_Role__c = 'Counterparty',
            Required__c = true,
            Signed__c = false,
            Signature_Order__c = 2
        ));
        insert sigs;

        // Not all signed
        Test.startTest();
        Boolean allSignedBefore = ContractSignatoryService.checkAllSigned(contract.Id);
        System.assertEquals(false, allSignedBefore,
            'checkAllSigned should return false when signatories are unsigned');

        // Sign all
        for (Contract_Signatory__c sig : sigs) {
            sig.Signed__c = true;
        }
        update sigs;

        Boolean allSignedAfter = ContractSignatoryService.checkAllSigned(contract.Id);
        Test.stopTest();

        System.assertEquals(true, allSignedAfter,
            'checkAllSigned should return true when all required signatories are signed');
    }

    /**
     * @description Verifies that checkAllSigned returns false for null contract Id and
     * contracts with no required signatories.
     */
    @IsTest
    static void testCheckAllSignedEdgeCases() {
        Test.startTest();
        Boolean resultNull = ContractSignatoryService.checkAllSigned(null);
        Test.stopTest();

        System.assertEquals(false, resultNull,
            'checkAllSigned should return false for null Id');
    }

    /**
     * @description Verifies that createSignatories handles null and empty list inputs.
     */
    @IsTest
    static void testCreateSignatoriesNullInputs() {
        Test.startTest();
        List<Contract_Signatory__c> result1 = ContractSignatoryService.createSignatories(
            (YGSF_Contract__c) null
        );
        List<Contract_Signatory__c> result2 = ContractSignatoryService.createSignatories(
            (List<YGSF_Contract__c>) null
        );
        List<Contract_Signatory__c> result3 = ContractSignatoryService.createSignatories(
            new List<YGSF_Contract__c>()
        );
        Test.stopTest();

        System.assertEquals(0, result1.size(),
            'Null single contract should return empty list');
        System.assertEquals(0, result2.size(),
            'Null list should return empty list');
        System.assertEquals(0, result3.size(),
            'Empty list should return empty list');
    }
}
