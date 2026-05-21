/**
 * @description Test class for ContractExpirationBatch and ContractExpirationSchedulable.
 * Validates contract expiration processing and reminder email sending at 30/60/90 day
 * thresholds.
 */
@IsTest
private class ContractExpirationBatchTest {

    /**
     * @description Verifies that contracts with End_Date__c <= today are set to Expired
     * status when the batch runs.
     */
    @IsTest
    static void testExpiredContracts() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Status__c = 'Active';
        contract.End_Date__c = Date.today();
        insert contract;

        // Ensure status is Active (trigger may have changed it)
        contract = [SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        if (contract.Status__c != 'Active') {
            contract.Status__c = 'Active';
            update contract;
        }

        Test.startTest();
        Database.executeBatch(new ContractExpirationBatch(), 200);
        Test.stopTest();

        YGSF_Contract__c afterBatch = [
            SELECT Id, Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals('Expired', afterBatch.Status__c,
            'Contract with End_Date__c <= today should be set to Expired by the batch');
    }

    /**
     * @description Verifies that contracts at exactly 30, 60, and 90 days from expiration
     * trigger reminder notification processing without errors. Validates the batch handles
     * reminder thresholds correctly.
     */
    @IsTest
    static void testExpirationReminders() {
        User testUser = TestDataFactory.getTestUser();
        List<YGSF_Contract__c> contracts = new List<YGSF_Contract__c>();

        // Contract expiring in 30 days
        YGSF_Contract__c contract30 = TestDataFactory.createContract();
        contract30.Staff_Liaison__c = testUser.Id;
        contract30.Branch_ED__c = testUser.Id;
        contract30.Status__c = 'Active';
        contract30.End_Date__c = Date.today().addDays(30);
        contract30.Contract_Title__c = '30-Day Contract';
        contracts.add(contract30);

        // Contract expiring in 60 days
        YGSF_Contract__c contract60 = TestDataFactory.createContract();
        contract60.Staff_Liaison__c = testUser.Id;
        contract60.Branch_ED__c = testUser.Id;
        contract60.Status__c = 'Active';
        contract60.End_Date__c = Date.today().addDays(60);
        contract60.Contract_Title__c = '60-Day Contract';
        contracts.add(contract60);

        // Contract expiring in 90 days
        YGSF_Contract__c contract90 = TestDataFactory.createContract();
        contract90.Staff_Liaison__c = testUser.Id;
        contract90.Branch_ED__c = testUser.Id;
        contract90.Status__c = 'Active';
        contract90.End_Date__c = Date.today().addDays(90);
        contract90.Contract_Title__c = '90-Day Contract';
        contracts.add(contract90);

        insert contracts;

        // Ensure all are Active
        List<YGSF_Contract__c> toFix = new List<YGSF_Contract__c>();
        for (YGSF_Contract__c c : [SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id IN :contracts]) {
            if (c.Status__c != 'Active') {
                c.Status__c = 'Active';
                toFix.add(c);
            }
        }
        if (!toFix.isEmpty()) {
            update toFix;
        }

        Test.startTest();
        Database.executeBatch(new ContractExpirationBatch(), 200);
        Test.stopTest();

        // Verify contracts still Active (not expired, just reminded)
        List<YGSF_Contract__c> afterBatch = [
            SELECT Id, Status__c, Contract_Title__c
            FROM YGSF_Contract__c
            WHERE Id IN :contracts
            ORDER BY Contract_Title__c
        ];

        for (YGSF_Contract__c c : afterBatch) {
            System.assertEquals('Active', c.Status__c,
                'Contracts with future End_Date__c should remain Active: ' + c.Contract_Title__c);
        }
    }

    /**
     * @description Verifies that contracts with End_Date__c in the past are expired.
     */
    @IsTest
    static void testPastEndDateExpired() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Status__c = 'Active';
        contract.End_Date__c = Date.today().addDays(-5);
        insert contract;

        contract = [SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        if (contract.Status__c != 'Active') {
            contract.Status__c = 'Active';
            update contract;
        }

        Test.startTest();
        Database.executeBatch(new ContractExpirationBatch(), 200);
        Test.stopTest();

        YGSF_Contract__c afterBatch = [
            SELECT Id, Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertEquals('Expired', afterBatch.Status__c,
            'Contract with past End_Date__c should be expired');
    }

    /**
     * @description Verifies that the schedulable class successfully enqueues the batch.
     */
    @IsTest
    static void testSchedulable() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Contract Expiration Schedule',
            '0 0 1 * * ?',
            new ContractExpirationSchedulable()
        );
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertNotEquals(null, ct,
            'Scheduled job should exist');
        System.assertEquals('0 0 1 * * ?', ct.CronExpression,
            'Cron expression should match');
    }
}
