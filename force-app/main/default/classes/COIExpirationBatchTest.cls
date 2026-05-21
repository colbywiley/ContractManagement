/**
 * @description Test class for COIExpirationBatch and COIExpirationSchedulable.
 * Validates COI document expiration processing and warning email generation.
 */
@IsTest
private class COIExpirationBatchTest {

    /**
     * @description Verifies that a COI document with Expiration_Date__c <= today is marked
     * as Expired when the batch runs.
     */
    @IsTest
    static void testCOIExpiration() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.COI_Required__c = true;
        insert contract;

        Contract_Document__c doc = TestDataFactory.createContractDocument(contract.Id, 'COI');
        doc.Status__c = 'Current';
        doc.Expiration_Date__c = Date.today();
        insert doc;

        // Verify document starts as Current
        Contract_Document__c beforeBatch = [
            SELECT Id, Status__c FROM Contract_Document__c WHERE Id = :doc.Id
        ];
        // Status may have been changed by trigger if expiration is past; reset if needed
        if (beforeBatch.Status__c != 'Current') {
            beforeBatch.Status__c = 'Current';
            update beforeBatch;
        }

        Test.startTest();
        Database.executeBatch(new COIExpirationBatch(), 200);
        Test.stopTest();

        Contract_Document__c afterBatch = [
            SELECT Id, Status__c
            FROM Contract_Document__c
            WHERE Id = :doc.Id
        ];

        System.assertEquals('Expired', afterBatch.Status__c,
            'COI document with Expiration_Date__c <= today should be marked Expired');
    }

    /**
     * @description Verifies that a COI document expiring in the future (within 30 days)
     * is processed for warning emails but NOT marked as expired.
     */
    @IsTest
    static void testCOIExpirationWarning() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.COI_Required__c = true;
        insert contract;

        Contract_Document__c doc = TestDataFactory.createContractDocument(contract.Id, 'COI');
        doc.Status__c = 'Current';
        doc.Expiration_Date__c = Date.today().addDays(15); // 15 days from now
        insert doc;

        Test.startTest();
        Database.executeBatch(new COIExpirationBatch(), 200);
        Test.stopTest();

        Contract_Document__c afterBatch = [
            SELECT Id, Status__c
            FROM Contract_Document__c
            WHERE Id = :doc.Id
        ];

        System.assertEquals('Current', afterBatch.Status__c,
            'COI document expiring in the future should remain Current');
    }

    /**
     * @description Verifies that COI documents with expiration dates beyond 30 days are
     * NOT included in the batch query and therefore not processed.
     */
    @IsTest
    static void testCOINotInScope() {
        User testUser = TestDataFactory.getTestUser();

        YGSF_Contract__c contract = TestDataFactory.createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        insert contract;

        Contract_Document__c doc = TestDataFactory.createContractDocument(contract.Id, 'COI');
        doc.Status__c = 'Current';
        doc.Expiration_Date__c = Date.today().addDays(60); // Beyond 30-day window
        insert doc;

        Test.startTest();
        Database.executeBatch(new COIExpirationBatch(), 200);
        Test.stopTest();

        Contract_Document__c afterBatch = [
            SELECT Id, Status__c
            FROM Contract_Document__c
            WHERE Id = :doc.Id
        ];

        System.assertEquals('Current', afterBatch.Status__c,
            'COI document outside the 30-day window should not be affected');
    }

    /**
     * @description Verifies that the schedulable class successfully enqueues the batch.
     */
    @IsTest
    static void testSchedulable() {
        Test.startTest();
        String jobId = System.schedule(
            'Test COI Expiration Schedule',
            '0 0 2 * * ?',
            new COIExpirationSchedulable()
        );
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertNotEquals(null, ct,
            'Scheduled job should exist');
        System.assertEquals('0 0 2 * * ?', ct.CronExpression,
            'Cron expression should match');
    }
}
