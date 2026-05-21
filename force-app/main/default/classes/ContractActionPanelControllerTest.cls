@IsTest
private class ContractActionPanelControllerTest {

    @TestSetup
    static void setup() {
        YGSF_Contract__c contract = new YGSF_Contract__c(
            Contract_Title__c = 'Test Action Panel Contract',
            Contract_Type__c = 'Independent Contractor Agreement',
            Contract_Subject_Picklist__c = 'Youth Program Services',
            Status__c = 'Draft',
            Contract_Value__c = 5000,
            Counterparty_Name__c = 'Test Vendor',
            Staff_Liaison__c = UserInfo.getUserId(),
            Legal_Reviewer__c = UserInfo.getUserId(),
            Branch_ED__c = UserInfo.getUserId(),
            VP_Approver__c = UserInfo.getUserId(),
            SVP_Approver__c = UserInfo.getUserId(),
            Officer_Approver__c = UserInfo.getUserId()
        );
        insert contract;
    }

    @IsTest
    static void testGetActionContextDraft() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];

        Test.startTest();
        ContractActionPanelController.ActionContext ctx =
            ContractActionPanelController.getActionContext(contract.Id);
        Test.stopTest();

        System.assertEquals('Draft', ctx.contractStatus, 'Status should be Draft');
        System.assertNotEquals(null, ctx.guidanceMessage, 'Guidance message should be set');
        System.assertNotEquals(null, ctx.userRole, 'User role should be determined');
        System.assert(ctx.isStaffLiaison, 'Current user should be identified as Staff Liaison');
    }

    @IsTest
    static void testSubmitForReview() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];

        Test.startTest();
        try {
            ContractActionPanelController.submitForReview(contract.Id);
        } catch (Exception e) {
            // Approval process may not match in test context - that's OK
        }
        Test.stopTest();

        contract = [SELECT Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Submitted', contract.Status__c, 'Status should be Submitted');
    }

    @IsTest
    static void testBeginLegalReview() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];
        contract.Status__c = 'Submitted';
        update contract;

        Test.startTest();
        ContractActionPanelController.beginLegalReview(contract.Id);
        Test.stopTest();

        contract = [SELECT Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Legal Review In Progress', contract.Status__c);
    }

    @IsTest
    static void testCompleteLegalReview() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];
        contract.Status__c = 'Legal Review In Progress';
        update contract;

        Test.startTest();
        try {
            ContractActionPanelController.completeLegalReview(contract.Id, 'Looks good');
        } catch (Exception e) {
            // No active approval process in test context
        }
        Test.stopTest();

        contract = [SELECT Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Legal Review Complete', contract.Status__c);
    }

    @IsTest
    static void testRequestRevisions() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];
        contract.Status__c = 'Legal Review In Progress';
        update contract;

        Test.startTest();
        try {
            ContractActionPanelController.requestRevisions(contract.Id, 'Needs changes');
        } catch (Exception e) {
            // No active approval process in test context
        }
        Test.stopTest();

        contract = [SELECT Status__c, Rejection_Reason__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Rejected', contract.Status__c);
        System.assertEquals('Needs changes', contract.Rejection_Reason__c);
    }

    @IsTest
    static void testMarkFullyExecuted() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];
        contract.Status__c = 'Pending Signatures';
        update contract;

        Test.startTest();
        ContractActionPanelController.markFullyExecuted(contract.Id);
        Test.stopTest();

        contract = [SELECT Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Fully Executed', contract.Status__c);
    }

    @IsTest
    static void testActivateContract() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];
        contract.Status__c = 'Fully Executed';
        update contract;

        Test.startTest();
        ContractActionPanelController.activateContract(contract.Id);
        Test.stopTest();

        contract = [SELECT Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Active', contract.Status__c);
    }

    @IsTest
    static void testResubmitContract() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];
        contract.Status__c = 'Rejected';
        contract.Rejection_Reason__c = 'Missing info';
        update contract;

        Test.startTest();
        try {
            ContractActionPanelController.resubmitContract(contract.Id);
        } catch (Exception e) {
            // Approval process may not match in test context
        }
        Test.stopTest();

        contract = [SELECT Status__c FROM YGSF_Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Submitted', contract.Status__c);
    }

    @IsTest
    static void testGetActionContextAllStatuses() {
        YGSF_Contract__c contract = [SELECT Id FROM YGSF_Contract__c LIMIT 1];

        List<String> statuses = new List<String>{
            'Submitted', 'Legal Review In Progress', 'Legal Review Complete',
            'Pending Signatures', 'Fully Executed', 'Active',
            'Rejected', 'Expired', 'Terminated', 'Renewed'
        };

        Test.startTest();
        for (String status : statuses) {
            contract.Status__c = status;
            update contract;

            ContractActionPanelController.ActionContext ctx =
                ContractActionPanelController.getActionContext(contract.Id);

            System.assertNotEquals(null, ctx.guidanceMessage,
                'Guidance should be set for status: ' + status);
        }
        Test.stopTest();
    }
}
