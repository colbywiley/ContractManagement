/**
 * @description Service class for creating contract renewals. Clones the original
 * YGSF_Contract__c record with a Draft status and creates a Contract_Renewal__c
 * junction record linking the original to the renewed contract.
 */
public with sharing class ContractRenewalService {

    // Fields to copy from the original contract to the renewal
    private static final List<String> CLONE_FIELDS = new List<String>{
        'Contract_Title__c', 'Contract_Type__c', 'Contract_Subject_Picklist__c',
        'Approval_Path__c', 'Contract_Value__c', 'Location__c',
        'Staff_Liaison__c', 'Legal_Reviewer__c', 'Attorney_Reviewer__c',
        'Branch_ED__c', 'VP_Approver__c', 'SVP_Approver__c', 'Officer_Approver__c',
        'Counterparty_Name__c', 'Counterparty_Contact__c', 'Counterparty_Account__c',
        'Description__c', 'Legal_Review_Required__c',
        'ICA_Approval_Form_Required__c', 'COI_Required__c',
        'Additional_Insured_Required__c', 'YGSF_Template_Used__c', 'Template_Name__c',
        'Payment_Method__c', 'Gift_Acceptance_Review__c',
        'Board_Approval_Required__c', 'Auto_Renew__c', 'Renewal_Term_Months__c',
        'Branch__c', 'Notes__c'
    };

    /**
     * @description Creates a renewal contract from an existing contract. Clones key
     * fields from the original, sets status to Draft, and computes new date range
     * based on the original contract's Renewal_Term_Months__c (defaults to 12 months).
     * Creates a Contract_Renewal__c record linking the original to the new contract.
     * @param originalContractId The Id of the contract to renew
     * @return The Id of the newly created renewal contract
     * @throws ContractRenewalException if the original contract is not found
     */
    public static Id createRenewal(Id originalContractId) {
        return createRenewal(originalContractId, null, null, null);
    }

    /**
     * @description Creates a renewal contract with optional override values for value
     * and dates. If override values are null, defaults are computed from the original.
     * @param originalContractId The Id of the contract to renew
     * @param newValue Override contract value (null to keep original value)
     * @param newStartDate Override start date (null to compute from original end date)
     * @param newEndDate Override end date (null to compute from renewal term)
     * @return The Id of the newly created renewal contract
     * @throws ContractRenewalException if the original contract is not found
     */
    public static Id createRenewal(
        Id originalContractId,
        Decimal newValue,
        Date newStartDate,
        Date newEndDate
    ) {
        if (originalContractId == null) {
            throw new ContractRenewalException('Original contract Id is required.');
        }

        // Query all fields needed for cloning
        String fieldList = String.join(CLONE_FIELDS, ', ');
        String query = 'SELECT Id, ' + fieldList +
            ', End_Date__c, Renewal_Term_Months__c' +
            ' FROM YGSF_Contract__c WHERE Id = :originalContractId LIMIT 1';
        List<YGSF_Contract__c> originals = Database.query(query);

        if (originals.isEmpty()) {
            throw new ContractRenewalException(
                'Original contract not found: ' + originalContractId
            );
        }

        YGSF_Contract__c original = originals[0];

        // Build the renewal contract
        YGSF_Contract__c renewal = new YGSF_Contract__c();

        // Copy fields from original
        renewal.Contract_Title__c = original.Contract_Title__c;
        renewal.Contract_Type__c = original.Contract_Type__c;
        renewal.Contract_Subject_Picklist__c = original.Contract_Subject_Picklist__c;
        renewal.Approval_Path__c = original.Approval_Path__c;
        renewal.Location__c = original.Location__c;
        renewal.Staff_Liaison__c = original.Staff_Liaison__c;
        renewal.Legal_Reviewer__c = original.Legal_Reviewer__c;
        renewal.Attorney_Reviewer__c = original.Attorney_Reviewer__c;
        renewal.Branch_ED__c = original.Branch_ED__c;
        renewal.VP_Approver__c = original.VP_Approver__c;
        renewal.SVP_Approver__c = original.SVP_Approver__c;
        renewal.Officer_Approver__c = original.Officer_Approver__c;
        renewal.Counterparty_Name__c = original.Counterparty_Name__c;
        renewal.Counterparty_Contact__c = original.Counterparty_Contact__c;
        renewal.Counterparty_Account__c = original.Counterparty_Account__c;
        renewal.Description__c = original.Description__c;
        renewal.Legal_Review_Required__c = original.Legal_Review_Required__c;
        renewal.ICA_Approval_Form_Required__c = original.ICA_Approval_Form_Required__c;
        renewal.COI_Required__c = original.COI_Required__c;
        renewal.Additional_Insured_Required__c = original.Additional_Insured_Required__c;
        renewal.YGSF_Template_Used__c = original.YGSF_Template_Used__c;
        renewal.Template_Name__c = original.Template_Name__c;
        renewal.Payment_Method__c = original.Payment_Method__c;
        renewal.Gift_Acceptance_Review__c = original.Gift_Acceptance_Review__c;
        renewal.Board_Approval_Required__c = original.Board_Approval_Required__c;
        renewal.Auto_Renew__c = original.Auto_Renew__c;
        renewal.Renewal_Term_Months__c = original.Renewal_Term_Months__c;
        renewal.Branch__c = original.Branch__c;
        renewal.Notes__c = original.Notes__c;

        // Set renewal-specific values
        renewal.Status__c = 'Draft';

        // Contract value: use override or original
        renewal.Contract_Value__c = (newValue != null) ? newValue : original.Contract_Value__c;

        // Compute renewal date range
        Integer renewalTermMonths = 12; // default
        if (original.Renewal_Term_Months__c != null && original.Renewal_Term_Months__c > 0) {
            renewalTermMonths = original.Renewal_Term_Months__c.intValue();
        }

        // Start date: use override, or day after original end date, or today
        if (newStartDate != null) {
            renewal.Start_Date__c = newStartDate;
        } else if (original.End_Date__c != null) {
            renewal.Start_Date__c = original.End_Date__c.addDays(1);
        } else {
            renewal.Start_Date__c = Date.today();
        }

        // End date: use override, or compute from start date + renewal term
        if (newEndDate != null) {
            renewal.End_Date__c = newEndDate;
        } else {
            renewal.End_Date__c = renewal.Start_Date__c.addMonths(renewalTermMonths).addDays(-1);
        }

        // Renewal date is the start of the new term
        renewal.Renewal_Date__c = renewal.Start_Date__c;

        // Clear execution-specific fields that should not carry over
        renewal.Legal_Review_Complete__c = false;
        renewal.Legal_Review_Date__c = null;
        renewal.Legal_Acknowledgment_Date__c = null;
        renewal.Execution_Date__c = null;
        renewal.Submission_Date__c = null;
        renewal.COI_Received__c = false;
        renewal.COI_Expiration_Date__c = null;
        renewal.Additional_Insured_Received__c = false;
        renewal.ICA_Approval_Form_Received__c = false;
        renewal.CFO_Payment_Approval__c = false;
        renewal.Board_Approval_Date__c = null;
        renewal.Rejection_Reason__c = null;
        renewal.Services_Started_Before_Execution__c = false;

        insert renewal;

        // Create the Contract_Renewal__c junction record
        Contract_Renewal__c renewalRecord = new Contract_Renewal__c(
            Original_Contract__c = originalContractId,
            Renewed_Contract__c = renewal.Id,
            Renewal_Date__c = renewal.Start_Date__c,
            Renewal_Type__c = (original.Auto_Renew__c ? 'Automatic' : 'Manual'),
            Previous_Value__c = original.Contract_Value__c,
            New_Value__c = renewal.Contract_Value__c,
            Notes__c = 'Renewal created from contract: ' + original.Contract_Title__c
        );

        insert renewalRecord;

        // Update the original contract's status to Renewed
        YGSF_Contract__c originalUpdate = new YGSF_Contract__c(
            Id = originalContractId,
            Status__c = 'Renewed'
        );
        update originalUpdate;

        return renewal.Id;
    }

    /**
     * @description Custom exception for contract renewal errors.
     */
    public class ContractRenewalException extends Exception {}
}
