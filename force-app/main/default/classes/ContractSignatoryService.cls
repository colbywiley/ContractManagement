/**
 * @description Service class for managing Contract_Signatory__c records. Automatically
 * creates signatory records based on subject configuration rules and contract field values.
 * Handles signatory recalculation when contract subject or value changes.
 */
public with sharing class ContractSignatoryService {

    // Signatory role constants matching the Contract_Signatory__c.Signatory_Role__c picklist
    private static final String ROLE_OFFICER = 'Officer';
    private static final String ROLE_SVP = 'Senior VP';
    private static final String ROLE_VP = 'VP';
    private static final String ROLE_BRANCH_ED = 'Branch ED';
    private static final String ROLE_COUNTERPARTY = 'Counterparty';

    /**
     * @description Creates Contract_Signatory__c records for a single contract based on
     * its subject configuration and assigned approver/signatory users. Each signatory
     * record is marked as Required and given a sequential Signature_Order__c.
     * @param contract The YGSF_Contract__c record (must have Id and subject populated)
     * @return List of inserted Contract_Signatory__c records
     */
    public static List<Contract_Signatory__c> createSignatories(YGSF_Contract__c contract) {
        if (contract == null || contract.Id == null) {
            return new List<Contract_Signatory__c>();
        }

        List<Contract_Signatory__c> signatories = buildSignatoryRecords(contract);

        if (!signatories.isEmpty()) {
            insert signatories;
        }

        return signatories;
    }

    /**
     * @description Bulk version that creates signatories for multiple contracts.
     * Batches all signatory inserts into a single DML operation.
     * @param contracts List of YGSF_Contract__c records with Ids
     * @return List of all inserted Contract_Signatory__c records
     */
    public static List<Contract_Signatory__c> createSignatories(List<YGSF_Contract__c> contracts) {
        if (contracts == null || contracts.isEmpty()) {
            return new List<Contract_Signatory__c>();
        }

        List<Contract_Signatory__c> allSignatories = new List<Contract_Signatory__c>();

        for (YGSF_Contract__c contract : contracts) {
            if (contract == null || contract.Id == null) {
                continue;
            }
            allSignatories.addAll(buildSignatoryRecords(contract));
        }

        if (!allSignatories.isEmpty()) {
            insert allSignatories;
        }

        return allSignatories;
    }

    /**
     * @description Deletes existing signatories and recreates them based on current
     * contract configuration. Used when the contract subject or value changes and
     * the required signatories may be different.
     * @param contract The YGSF_Contract__c record to recalculate signatories for
     * @return List of newly created Contract_Signatory__c records
     */
    public static List<Contract_Signatory__c> recalculateSignatories(YGSF_Contract__c contract) {
        if (contract == null || contract.Id == null) {
            return new List<Contract_Signatory__c>();
        }

        // Delete existing signatories for this contract
        List<Contract_Signatory__c> existing = [
            SELECT Id
            FROM Contract_Signatory__c
            WHERE Contract__c = :contract.Id
        ];

        if (!existing.isEmpty()) {
            delete existing;
        }

        // Recreate based on current configuration
        return createSignatories(contract);
    }

    /**
     * @description Checks whether all required signatories for a contract have signed.
     * @param contractId The Id of the YGSF_Contract__c to check
     * @return True if every required signatory has Signed__c = true, false otherwise
     */
    public static Boolean checkAllSigned(Id contractId) {
        if (contractId == null) {
            return false;
        }

        List<Contract_Signatory__c> requiredSignatories = [
            SELECT Id, Signed__c
            FROM Contract_Signatory__c
            WHERE Contract__c = :contractId
              AND Required__c = true
        ];

        // If no required signatories exist, consider it not fully signed
        if (requiredSignatories.isEmpty()) {
            return false;
        }

        for (Contract_Signatory__c sig : requiredSignatories) {
            if (!sig.Signed__c) {
                return false;
            }
        }

        return true;
    }

    /**
     * @description Builds signatory records (without inserting) based on subject config
     * flags and the contract's assigned user fields. Creates signatories for Officer,
     * SVP, VP, Branch ED, and Counterparty roles as dictated by configuration.
     * @param contract The contract to build signatories for
     * @return List of Contract_Signatory__c records ready for insertion
     */
    private static List<Contract_Signatory__c> buildSignatoryRecords(YGSF_Contract__c contract) {
        List<Contract_Signatory__c> signatories = new List<Contract_Signatory__c>();

        Contract_Subject_Config__mdt config = null;
        if (String.isNotBlank(contract.Contract_Subject_Picklist__c)) {
            config = ContractSubjectConfigService.getConfigForSubject(contract.Contract_Subject_Picklist__c);
        }

        Integer signatureOrder = 1;

        // Officer signatory (highest authority, signs first in the internal chain)
        if (config != null && config.Officer_Signature_Required__c && contract.Officer_Approver__c != null) {
            signatories.add(buildSignatory(
                contract.Id, contract.Officer_Approver__c, ROLE_OFFICER, true, signatureOrder++
            ));
        }

        // SVP signatory
        if (config != null && config.SVP_Signature_Required__c && contract.SVP_Approver__c != null) {
            signatories.add(buildSignatory(
                contract.Id, contract.SVP_Approver__c, ROLE_SVP, true, signatureOrder++
            ));
        }

        // VP signatory
        if (config != null && config.VP_Signature_Required__c && contract.VP_Approver__c != null) {
            signatories.add(buildSignatory(
                contract.Id, contract.VP_Approver__c, ROLE_VP, true, signatureOrder++
            ));
        }

        // Branch ED signatory
        if (config != null && config.ED_Signature_Required__c && contract.Branch_ED__c != null) {
            signatories.add(buildSignatory(
                contract.Id, contract.Branch_ED__c, ROLE_BRANCH_ED, true, signatureOrder++
            ));
        }

        // If no config exists but Branch ED is assigned, still add as a default signatory
        if (config == null && contract.Branch_ED__c != null) {
            signatories.add(buildSignatory(
                contract.Id, contract.Branch_ED__c, ROLE_BRANCH_ED, true, signatureOrder++
            ));
        }

        // Counterparty signatory -- always created when a Staff Liaison is present,
        // as counterparty signature is a standard requirement for contract execution.
        // Note: Counterparty uses Staff_Liaison__c as a placeholder user reference since
        // counterparties are typically external and tracked via Counterparty_Contact__c.
        if (contract.Staff_Liaison__c != null) {
            signatories.add(buildSignatory(
                contract.Id, contract.Staff_Liaison__c, ROLE_COUNTERPARTY, true, signatureOrder++
            ));
        }

        return signatories;
    }

    /**
     * @description Creates a single Contract_Signatory__c record with the given values.
     * @param contractId The parent contract Id
     * @param signatoryUserId The User Id of the signatory
     * @param role The signatory role (Officer, Senior VP, VP, Branch ED, Counterparty)
     * @param required Whether this signature is required for execution
     * @param order The signature order (lower = earlier in sequence)
     * @return A new (unsaved) Contract_Signatory__c record
     */
    private static Contract_Signatory__c buildSignatory(
        Id contractId, Id signatoryUserId, String role, Boolean required, Integer order
    ) {
        return new Contract_Signatory__c(
            Contract__c = contractId,
            Signatory__c = signatoryUserId,
            Signatory_Role__c = role,
            Required__c = required,
            Signed__c = false,
            Signature_Order__c = order
        );
    }
}
