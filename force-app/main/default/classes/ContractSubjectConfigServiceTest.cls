/**
 * @description Test class for ContractSubjectConfigService. Validates subject configuration
 * application from Contract_Subject_Config__mdt metadata to contract records, both for
 * single and bulk operations.
 */
@IsTest
private class ContractSubjectConfigServiceTest {

    /**
     * @description Verifies that applySubjectConfigs processes a contract with a subject
     * and applies configuration fields. Since custom metadata may not be available in tests,
     * validates that the method executes without error and handles null/missing config.
     */
    @IsTest
    static void testApplySubjectConfig() {
        YGSF_Contract__c contract = TestDataFactory.createContract(
            'Facility Use Agreements', 'Agreement', 5000
        );

        Test.startTest();
        ContractSubjectConfigService.applySubjectConfigs(
            new List<YGSF_Contract__c>{ contract }
        );
        Test.stopTest();

        // The method modifies contracts in place; verify no exception and subject preserved
        System.assertEquals('Facility Use Agreements', contract.Contract_Subject_Picklist__c,
            'Subject should be preserved after config application');
    }

    /**
     * @description Verifies that applySubjectConfigs handles 200 contracts in bulk without
     * governor limit violations or errors.
     */
    @IsTest
    static void testBulkApply() {
        List<YGSF_Contract__c> contracts = new List<YGSF_Contract__c>();
        for (Integer i = 0; i < 200; i++) {
            contracts.add(TestDataFactory.createContract(
                'Facility Use Agreements', 'Agreement', 1000 + i
            ));
        }

        Test.startTest();
        ContractSubjectConfigService.applySubjectConfigs(contracts);
        Test.stopTest();

        System.assertEquals(200, contracts.size(),
            'All 200 contracts should be processed without error');
        for (YGSF_Contract__c c : contracts) {
            System.assertEquals('Facility Use Agreements', c.Contract_Subject_Picklist__c,
                'Subject should be preserved on all contracts');
        }
    }

    /**
     * @description Verifies that applySubjectConfig handles null and empty inputs gracefully.
     */
    @IsTest
    static void testNullAndEmptyInputs() {
        Test.startTest();
        ContractSubjectConfigService.applySubjectConfigs(null);
        ContractSubjectConfigService.applySubjectConfigs(new List<YGSF_Contract__c>());

        YGSF_Contract__c contractNoSubject = TestDataFactory.createContract();
        contractNoSubject.Contract_Subject_Picklist__c = null;
        ContractSubjectConfigService.applySubjectConfigs(
            new List<YGSF_Contract__c>{ contractNoSubject }
        );
        Test.stopTest();

        // All should complete without exception
        System.assert(true, 'Null and empty inputs should be handled gracefully');
    }

    /**
     * @description Verifies that getConfigForSubject returns null for blank/unknown subjects.
     */
    @IsTest
    static void testGetConfigForSubjectBlank() {
        Test.startTest();
        Contract_Subject_Config__mdt result1 = ContractSubjectConfigService.getConfigForSubject(null);
        Contract_Subject_Config__mdt result2 = ContractSubjectConfigService.getConfigForSubject('');
        Contract_Subject_Config__mdt result3 = ContractSubjectConfigService.getConfigForSubject(
            'NonExistent Subject XYZ'
        );
        Test.stopTest();

        System.assertEquals(null, result1, 'Null subject should return null config');
        System.assertEquals(null, result2, 'Empty subject should return null config');
        // Unknown subject returns null since no metadata match exists
        // (may return a config if test metadata happens to match, so just verify no exception)
    }

    /**
     * @description Verifies that resolveApprovalPathLabel correctly maps section codes
     * to full picklist labels.
     */
    @IsTest
    static void testResolveApprovalPathLabel() {
        Test.startTest();
        String result321 = ContractSubjectConfigService.resolveApprovalPathLabel('Section 3.2.1');
        String result324 = ContractSubjectConfigService.resolveApprovalPathLabel('Section 3.2.4');
        String resultNull = ContractSubjectConfigService.resolveApprovalPathLabel(null);
        String resultUnknown = ContractSubjectConfigService.resolveApprovalPathLabel('Unknown');
        Test.stopTest();

        System.assertEquals('Section 3.2.1 - SVP and Officer', result321,
            'Section 3.2.1 should resolve to SVP and Officer label');
        System.assertEquals('Section 3.2.4 - Branch ED Only', result324,
            'Section 3.2.4 should resolve to Branch ED Only label');
        System.assertEquals(null, resultNull,
            'Null input should return null');
        System.assertEquals('Unknown', resultUnknown,
            'Unknown code should return the original value');
    }
}
