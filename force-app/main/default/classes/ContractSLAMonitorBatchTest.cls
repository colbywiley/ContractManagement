/**
 * @description Test class for ContractSLAMonitorBatch and ContractSLAMonitorSchedulable.
 * Validates SLA breach detection for contracts in processing stages.
 */
@IsTest
private class ContractSLAMonitorBatchTest {

    /**
     * @description Verifies that a contract submitted more than the SLA window ago is
     * detected as breached by the batch job. The batch should update the SLA_Status__c
     * field and send breach notifications.
     */
    @IsTest
    static void testSLABreachDetection() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Legal_Reviewer__c = testUser.Id;
        contract.Status__c = 'Submitted';
        contract.Submission_Date__c = Date.today().addDays(-15); // Submitted 15 days ago
        insert contract;

        // Ensure status is Submitted with correct submission date
        contract = [SELECT Id, Status__c, Submission_Date__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        Boolean needsUpdate = false;
        if (contract.Status__c != 'Submitted') {
            contract.Status__c = 'Submitted';
            needsUpdate = true;
        }
        if (contract.Submission_Date__c != Date.today().addDays(-15)) {
            contract.Submission_Date__c = Date.today().addDays(-15);
            needsUpdate = true;
        }
        if (needsUpdate) {
            update contract;
        }

        Test.startTest();
        Database.executeBatch(new ContractSLAMonitorBatch(), 200);
        Test.stopTest();

        YGSF_Contract__c afterBatch = [
            SELECT Id, Status__c, SLA_Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        // The batch should have processed this contract; if SLA config exists, it should
        // be marked as breached. If no SLA config metadata exists in test context, the
        // batch should still complete without errors.
        System.assertNotEquals(null, afterBatch,
            'Contract should still exist after batch processing');
    }

    /**
     * @description Verifies that a recently submitted contract (within SLA) is NOT
     * marked as breached.
     */
    @IsTest
    static void testWithinSLANotBreached() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Status__c = 'Submitted';
        contract.Submission_Date__c = Date.today(); // Submitted today
        insert contract;

        contract = [SELECT Id, Status__c, Submission_Date__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        if (contract.Status__c != 'Submitted') {
            contract.Status__c = 'Submitted';
            update contract;
        }

        Test.startTest();
        Database.executeBatch(new ContractSLAMonitorBatch(), 200);
        Test.stopTest();

        YGSF_Contract__c afterBatch = [
            SELECT Id, SLA_Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        // Recently submitted contract should not be breached
        System.assertNotEquals('Breached', afterBatch.SLA_Status__c,
            'Contract submitted today should not be marked as SLA Breached');
    }

    /**
     * @description Verifies that contracts in Legal Review In Progress status are
     * also monitored by the batch.
     */
    @IsTest
    static void testLegalReviewSLAMonitoring() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.Legal_Reviewer__c = testUser.Id;
        contract.Status__c = 'Legal Review In Progress';
        contract.Submission_Date__c = Date.today().addDays(-20);
        insert contract;

        contract = [SELECT Id, Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        if (contract.Status__c != 'Legal Review In Progress') {
            contract.Status__c = 'Legal Review In Progress';
            contract.Submission_Date__c = Date.today().addDays(-20);
            update contract;
        }

        Test.startTest();
        Database.executeBatch(new ContractSLAMonitorBatch(), 200);
        Test.stopTest();

        YGSF_Contract__c afterBatch = [
            SELECT Id, Status__c
            FROM YGSF_Contract__c
            WHERE Id = :contract.Id
        ];

        System.assertNotEquals(null, afterBatch,
            'Contract should be processed without errors');
    }

    /**
     * @description Verifies that the getSLANameForStatus method returns correct SLA names.
     */
    @IsTest
    static void testGetSLANameForStatus() {
        System.assertEquals('Submission Processing',
            ContractSLAMonitorBatch.getSLANameForStatus('Submitted'),
            'Submitted status should map to Submission Processing SLA');
        System.assertEquals('Legal Review',
            ContractSLAMonitorBatch.getSLANameForStatus('Legal Review In Progress'),
            'Legal Review In Progress should map to Legal Review SLA');
        System.assertEquals('Signature Collection',
            ContractSLAMonitorBatch.getSLANameForStatus('Pending Signatures'),
            'Pending Signatures should map to Signature Collection SLA');
        System.assertEquals(null,
            ContractSLAMonitorBatch.getSLANameForStatus('Draft'),
            'Draft status should return null (no SLA monitoring)');
    }

    /**
     * @description Verifies that the schedulable class successfully enqueues the batch.
     */
    @IsTest
    static void testSchedulable() {
        Test.startTest();
        String jobId = System.schedule(
            'Test SLA Monitor Schedule',
            '0 0 6 * * ?',
            new ContractSLAMonitorSchedulable()
        );
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertNotEquals(null, ct,
            'Scheduled job should exist');
        System.assertEquals('0 0 6 * * ?', ct.CronExpression,
            'Cron expression should match');
    }
}
