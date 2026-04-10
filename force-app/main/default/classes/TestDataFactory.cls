/**
 * @description Utility class for creating test data across YGSF Contract Management tests.
 * Provides static factory methods for YGSF_Contract__c, Contract_Document__c,
 * Contract_Signatory__c, and User records with sensible defaults.
 * NOT a test class - used by @IsTest classes.
 */
@IsTest
public class TestDataFactory {

    /**
     * @description Creates a YGSF_Contract__c with sensible defaults. Does NOT insert.
     * @return A new YGSF_Contract__c record ready for insertion
     */
    public static YGSF_Contract__c createContract() {
        return createContract('Facility Use Agreements', 'Agreement', 5000);
    }

    /**
     * @description Creates a YGSF_Contract__c with specific subject, type, and value.
     * Does NOT insert.
     * @param subject The Contract_Subject_Picklist__c value
     * @param contractType The Contract_Type__c value
     * @param value The Contract_Value__c amount
     * @return A new YGSF_Contract__c record ready for insertion
     */
    public static YGSF_Contract__c createContract(String subject, String contractType, Decimal value) {
        return new YGSF_Contract__c(
            Contract_Title__c = 'Test Contract - ' + subject,
            Contract_Type__c = contractType,
            Contract_Subject_Picklist__c = subject,
            Contract_Value__c = value,
            Status__c = 'Draft',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addYears(1),
            Counterparty_Name__c = 'Test Counterparty Inc.',
            Description__c = 'Test contract created by TestDataFactory',
            Location__c = 'Test Location'
        );
    }

    /**
     * @description Creates and inserts a contract with the specified subject, then creates
     * Contract_Signatory__c records for it based on the assigned approvers. The contract
     * is inserted with user lookup fields populated.
     * @param subject The Contract_Subject_Picklist__c value
     * @return The inserted YGSF_Contract__c record with Id
     */
    public static YGSF_Contract__c createContractWithSignatories(String subject) {
        User testUser = getTestUser();

        YGSF_Contract__c contract = createContract(subject, 'Agreement', 5000);
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        insert contract;

        // Signatories are auto-created by the trigger if ContractSignatoryService is working;
        // if not, create them manually
        List<Contract_Signatory__c> existingSigs = [
            SELECT Id FROM Contract_Signatory__c WHERE Contract__c = :contract.Id
        ];

        if (existingSigs.isEmpty()) {
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
        }

        return contract;
    }

    /**
     * @description Creates a Contract_Document__c for the given contract and document type.
     * Does NOT insert.
     * @param contractId The parent YGSF_Contract__c Id
     * @param docType The Document_Type__c value (e.g., 'COI', 'Additional Insured Endorsement')
     * @return A new Contract_Document__c record ready for insertion
     */
    public static Contract_Document__c createContractDocument(Id contractId, String docType) {
        return new Contract_Document__c(
            Contract__c = contractId,
            Document_Type__c = docType,
            Status__c = 'Current',
            File_Name__c = 'test_' + docType.replaceAll(' ', '_') + '.pdf',
            Description__c = 'Test document: ' + docType
        );
    }

    /**
     * @description Creates and inserts a test User with the given profile. Falls back to
     * 'Standard User' if the specified profile is not found.
     * @param profileName The Profile name to assign
     * @return The inserted User record
     */
    public static User createUser(String profileName) {
        Profile p;
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        if (!profiles.isEmpty()) {
            p = profiles[0];
        } else {
            p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }

        String uniqueKey = String.valueOf(Datetime.now().getTime()) +
            String.valueOf(Math.round(Math.random() * 10000));

        User u = new User(
            FirstName = 'Test',
            LastName = 'User' + uniqueKey,
            Email = 'testuser' + uniqueKey + '@ygsf.test.com',
            Username = 'testuser' + uniqueKey + '@ygsf.test.com',
            Alias = uniqueKey.right(8),
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    /**
     * @description Returns the current running user for test data that requires a User reference.
     * Uses the running user to avoid mixed DML issues in tests.
     * @return The current User record
     */
    public static User getTestUser() {
        return [SELECT Id, Name, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }

    /**
     * @description Creates multiple YGSF_Contract__c records for bulk testing.
     * Does NOT insert.
     * @param count Number of contracts to create
     * @param subject The Contract_Subject_Picklist__c value
     * @return List of new YGSF_Contract__c records
     */
    public static List<YGSF_Contract__c> createContracts(Integer count, String subject) {
        User testUser = getTestUser();
        List<YGSF_Contract__c> contracts = new List<YGSF_Contract__c>();
        for (Integer i = 0; i < count; i++) {
            YGSF_Contract__c c = createContract(subject, 'Agreement', 5000 + i);
            c.Contract_Title__c = 'Bulk Test Contract ' + (i + 1);
            c.Staff_Liaison__c = testUser.Id;
            c.Branch_ED__c = testUser.Id;
            contracts.add(c);
        }
        return contracts;
    }

    /**
     * @description Creates a YGSF_Contract__c with all user lookup fields populated
     * using the running user. Does NOT insert.
     * @return A fully populated YGSF_Contract__c record
     */
    public static YGSF_Contract__c createFullContract() {
        User testUser = getTestUser();
        YGSF_Contract__c contract = createContract();
        contract.Staff_Liaison__c = testUser.Id;
        contract.Branch_ED__c = testUser.Id;
        contract.VP_Approver__c = testUser.Id;
        contract.SVP_Approver__c = testUser.Id;
        contract.Officer_Approver__c = testUser.Id;
        contract.Legal_Reviewer__c = testUser.Id;
        contract.Attorney_Reviewer__c = testUser.Id;
        return contract;
    }
}
