/**
 * @description Test class for ContractSignatoryTriggerHandler. Validates that signing
 * all required signatories advances the parent contract to Fully Executed, and that
 * partial signing does not change the contract status.
 */
@IsTest
private class ContractSignatoryTriggerHandlerTest {

    /**
     * @description Verifies that when all required signatories for a contract are marked
     * as signed, the parent contract's Status__c is updated to Fully Executed.
     */
    @IsTest
    static void testAllSignedUpdatesContract() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Status__c = 'Pending Signatures';
        insert contract;

        // Update contract status directly (it may have been overridden by trigger)
        contract = [SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        if (contract.Status__c != 'Pending Signatures') {
            contract.Status__c = 'Pending Signatures';
            update contract;
        }

        // Delete auto-created signatories and create controlled test signatories
        delete [SELECT Id FROM Contract_Signatory__c WHERE Contract__c = :contract.Id];

        List<Contract_Signatory__c> signatories = new List<Contract_Signatory__c>();
        signatories.add(new Contract_Signatory__c(
            Contract__c = contract.Id,
            Signatory__c = testUser.Id,
            Signatory_Role__c = 'Branch ED',
            Required__c = true,
            Signed__c = false,
            Signature_Order__c = 1
        ));
        signatories.add(new Contract_Signatory__c(
            Contract__c = contract.Id,
            Signatory__c = testUser.Id,
            Signatory_Role__c = 'Counterparty',
            Required__c = true,
            Signed__c = false,
            Signature_Order__c = 2
        ));
        insert signatories;

        Test.startTest();
        // Sign all signatories
        for (Contract_Signatory__c sig : signatories) {
            sig.Signed__c = true;
        }
        update signatories;
        Test.stopTest();

        YGSF_Contract__c updatedContract = [
            SELECT Id, Status__c, Execution_Date__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals('Fully Executed', updatedContract.Status__c,
            'Contract status should change to Fully Executed when all required signatories sign');
    }

    /**
     * @description Verifies that signing only some (not all) required signatories does
     * NOT change the parent contract's status to Fully Executed.
     */
    @IsTest
    static void testPartialSignDoesNotUpdateContract() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Status__c = 'Pending Signatures';
        insert contract;

        // Ensure status is Pending Signatures
        contract = [SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        if (contract.Status__c != 'Pending Signatures') {
            contract.Status__c = 'Pending Signatures';
            update contract;
        }

        // Delete auto-created signatories and create controlled test signatories
        delete [SELECT Id FROM Contract_Signatory__c WHERE Contract__c = :contract.Id];

        List<Contract_Signatory__c> signatories = new List<Contract_Signatory__c>();
        signatories.add(new Contract_Signatory__c(
            Contract__c = contract.Id,
            Signatory__c = testUser.Id,
            Signatory_Role__c = 'Branch ED',
            Required__c = true,
            Signed__c = false,
            Signature_Order__c = 1
        ));
        signatories.add(new Contract_Signatory__c(
            Contract__c = contract.Id,
            Signatory__c = testUser.Id,
            Signatory_Role__c = 'Counterparty',
            Required__c = true,
            Signed__c = false,
            Signature_Order__c = 2
        ));
        insert signatories;

        Test.startTest();
        // Sign only the first signatory
        signatories[0].Signed__c = true;
        update new List<Contract_Signatory__c>{ signatories[0] };
        Test.stopTest();

        YGSF_Contract__c updatedContract = [
            SELECT Id, Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertNotEquals('Fully Executed', updatedContract.Status__c,
            'Contract status should NOT change to Fully Executed when only some signatories have signed');
    }

    /**
     * @description Verifies that Signed_Date__c is automatically stamped when a
     * signatory's Signed__c field changes from false to true.
     */
    @IsTest
    static void testSignedDateStamped() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        insert contract;

        // Delete auto-created signatories
        delete [SELECT Id FROM Contract_Signatory__c WHERE Contract__c = :contract.Id];

        Contract_Signatory__c sig = new Contract_Signatory__c(
            Contract__c = contract.Id,
            Signatory__c = testUser.Id,
            Signatory_Role__c = 'Branch ED',
            Required__c = true,
            Signed__c = false,
            Signature_Order__c = 1
        );
        insert sig;

        Test.startTest();
        sig.Signed__c = true;
        update sig;
        Test.stopTest();

        Contract_Signatory__c updated = [
            SELECT Id, Signed__c, Signed_Date__c
            FROM Contract_Signatory__c
            WHERE Id = :sig.Id
        ];

        System.assertEquals(true, updated.Signed__c,
            'Signed__c should be true');
        System.assertEquals(Date.today(), updated.Signed_Date__c,
            'Signed_Date__c should be stamped to today when Signed__c becomes true');
    }
}
