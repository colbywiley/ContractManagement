/**
 * @description Service class providing complex compliance validation logic for
 * YGSF contracts. Validates contracts at submission and execution stages, checking
 * required fields, document completeness, lead time SLAs, legal review status,
 * COI validity, and board approval requirements.
 */
public with sharing class ContractComplianceService {

    // SLA name constants matching SLA_Configuration__mdt records
    private static final String SLA_SUBMISSION_LEAD_TIME = 'Submission Lead Time';

    // Compliance check name constants used as map keys in getComplianceStatus
    public static final String CHECK_REQUIRED_FIELDS = 'Required Fields';
    public static final String CHECK_SUBMISSION_LEAD_TIME = 'Submission Lead Time';
    public static final String CHECK_COUNTERPARTY = 'Counterparty Information';
    public static final String CHECK_APPROVAL_PATH = 'Approval Path';
    public static final String CHECK_LEGAL_REVIEW = 'Legal Review';
    public static final String CHECK_COI = 'Certificate of Insurance';
    public static final String CHECK_COI_EXPIRATION = 'COI Expiration';
    public static final String CHECK_ADDITIONAL_INSURED = 'Additional Insured';
    public static final String CHECK_DOCUMENTS = 'Document Completeness';
    public static final String CHECK_SIGNATORIES = 'All Signatories Signed';
    public static final String CHECK_BOARD_APPROVAL = 'Board Approval';
    public static final String CHECK_ICA_FORM = 'ICA Approval Form';

    /**
     * @description Validates a contract for submission readiness. Checks required fields,
     * submission lead time relative to desired execution date, counterparty info, and
     * approval path assignment.
     * @param contract The YGSF_Contract__c record to validate
     * @return List of error messages; empty list means contract is compliant
     */
    public static List<String> validateForSubmission(YGSF_Contract__c contract) {
        List<String> errors = new List<String>();

        if (contract == null) {
            errors.add('Contract record is required.');
            return errors;
        }

        // Required field validation
        if (String.isBlank(contract.Contract_Title__c)) {
            errors.add('Contract Title is required.');
        }

        if (String.isBlank(contract.Contract_Type__c)) {
            errors.add('Contract Type is required.');
        }

        if (String.isBlank(contract.Contract_Subject_Picklist__c)) {
            errors.add('Contract Subject is required.');
        }

        if (contract.Start_Date__c == null) {
            errors.add('Start Date is required.');
        }

        if (contract.End_Date__c == null) {
            errors.add('End Date is required.');
        }

        // Date range validation
        if (contract.Start_Date__c != null && contract.End_Date__c != null
            && contract.End_Date__c <= contract.Start_Date__c) {
            errors.add('End Date must be after Start Date.');
        }

        // Counterparty validation
        if (String.isBlank(contract.Counterparty_Name__c)) {
            errors.add('Counterparty Name is required.');
        }

        // Staff Liaison must be assigned
        if (contract.Staff_Liaison__c == null) {
            errors.add('Staff Liaison must be assigned.');
        }

        // Branch ED must be assigned
        if (contract.Branch_ED__c == null) {
            errors.add('Branch ED must be assigned.');
        }

        // Approval path must be determined
        if (String.isBlank(contract.Approval_Path__c)) {
            errors.add('Approval Path has not been determined. Please select a Contract Subject.');
        }

        // Submission lead time check: contract must be submitted at least N business days
        // before the desired execution date
        if (contract.Desired_Execution_Date__c != null) {
            Date today = Date.today();
            Date deadline = SLACalculatorService.calculateDeadline(SLA_SUBMISSION_LEAD_TIME, today);

            if (deadline != null && contract.Desired_Execution_Date__c < deadline) {
                Integer requiredDays = SLACalculatorService.getBusinessDaysForSLA(SLA_SUBMISSION_LEAD_TIME);
                errors.add(
                    'Desired Execution Date must be at least ' + requiredDays +
                    ' business days from today to meet the submission lead time requirement.'
                );
            }
        }

        return errors;
    }

    /**
     * @description Validates a contract for execution readiness. Checks legal review
     * completion, COI and endorsement receipt, document completeness, signatory status,
     * board approval, and ICA form requirements.
     * @param contract The YGSF_Contract__c record to validate (must have Id)
     * @return List of error messages; empty list means contract is ready for execution
     */
    public static List<String> validateForExecution(YGSF_Contract__c contract) {
        List<String> errors = new List<String>();

        if (contract == null) {
            errors.add('Contract record is required.');
            return errors;
        }

        // Legal review validation: if legal review is required before execution, it must be complete
        if (contract.Legal_Review_Required__c == 'Before Execution' && !contract.Legal_Review_Complete__c) {
            errors.add('Legal review must be completed before execution (Legal Review Required = Before Execution).');
        }

        // COI validation
        if (contract.COI_Required__c && !contract.COI_Received__c) {
            errors.add('Certificate of Insurance (COI) is required but has not been received.');
        }

        // COI expiration check: COI must not be expired at the time of execution
        if (contract.COI_Required__c && contract.COI_Received__c
            && contract.COI_Expiration_Date__c != null
            && contract.COI_Expiration_Date__c < Date.today()) {
            errors.add('Certificate of Insurance (COI) has expired. Please obtain an updated certificate.');
        }

        // Additional Insured endorsement validation
        if (contract.Additional_Insured_Required__c && !contract.Additional_Insured_Received__c) {
            errors.add('Additional Insured endorsement is required but has not been received.');
        }

        // ICA Approval Form validation
        if (contract.ICA_Approval_Form_Required__c && !contract.ICA_Approval_Form_Received__c) {
            errors.add('ICA Approval Form is required but has not been received.');
        }

        // Board approval validation
        if (contract.Board_Approval_Required__c && contract.Board_Approval_Date__c == null) {
            errors.add('Board approval is required but has not been received.');
        }

        // Document completeness check (queries related documents)
        if (contract.Id != null) {
            List<String> missingDocs = ContractDocumentService.getMissingDocuments(contract.Id);
            if (!missingDocs.isEmpty()) {
                errors.add('Missing required documents: ' + String.join(missingDocs, ', ') + '.');
            }

            // Signatory completeness check
            if (!ContractSignatoryService.checkAllSigned(contract.Id)) {
                errors.add('Not all required signatories have signed the contract.');
            }
        }

        return errors;
    }

    /**
     * @description Returns a comprehensive compliance status map for the contract.
     * Each entry maps a compliance check name to a Boolean (true = passing, false = failing).
     * Useful for displaying a compliance dashboard or checklist.
     * @param contract The YGSF_Contract__c record to evaluate (should have Id for document checks)
     * @return Map of check name to pass/fail Boolean
     */
    public static Map<String, Boolean> getComplianceStatus(YGSF_Contract__c contract) {
        Map<String, Boolean> status = new Map<String, Boolean>();

        if (contract == null) {
            return status;
        }

        // Required fields check
        Boolean hasRequiredFields = String.isNotBlank(contract.Contract_Title__c)
            && String.isNotBlank(contract.Contract_Type__c)
            && String.isNotBlank(contract.Contract_Subject_Picklist__c)
            && contract.Start_Date__c != null
            && contract.End_Date__c != null;
        status.put(CHECK_REQUIRED_FIELDS, hasRequiredFields);

        // Submission lead time check
        Boolean leadTimeMet = true;
        if (contract.Desired_Execution_Date__c != null) {
            Date today = Date.today();
            Date deadline = SLACalculatorService.calculateDeadline(SLA_SUBMISSION_LEAD_TIME, today);
            if (deadline != null) {
                leadTimeMet = contract.Desired_Execution_Date__c >= deadline;
            }
        }
        status.put(CHECK_SUBMISSION_LEAD_TIME, leadTimeMet);

        // Counterparty information
        status.put(CHECK_COUNTERPARTY, String.isNotBlank(contract.Counterparty_Name__c));

        // Approval path determined
        status.put(CHECK_APPROVAL_PATH, String.isNotBlank(contract.Approval_Path__c));

        // Legal review status
        Boolean legalReviewOk = true;
        if (contract.Legal_Review_Required__c == 'Before Execution') {
            legalReviewOk = contract.Legal_Review_Complete__c;
        }
        status.put(CHECK_LEGAL_REVIEW, legalReviewOk);

        // COI status
        Boolean coiOk = true;
        if (contract.COI_Required__c) {
            coiOk = contract.COI_Received__c;
        }
        status.put(CHECK_COI, coiOk);

        // COI expiration
        Boolean coiExpirationOk = true;
        if (contract.COI_Required__c && contract.COI_Received__c
            && contract.COI_Expiration_Date__c != null) {
            coiExpirationOk = contract.COI_Expiration_Date__c >= Date.today();
        }
        status.put(CHECK_COI_EXPIRATION, coiExpirationOk);

        // Additional Insured
        Boolean additionalInsuredOk = true;
        if (contract.Additional_Insured_Required__c) {
            additionalInsuredOk = contract.Additional_Insured_Received__c;
        }
        status.put(CHECK_ADDITIONAL_INSURED, additionalInsuredOk);

        // ICA Approval Form
        Boolean icaOk = true;
        if (contract.ICA_Approval_Form_Required__c) {
            icaOk = contract.ICA_Approval_Form_Received__c;
        }
        status.put(CHECK_ICA_FORM, icaOk);

        // Board approval
        Boolean boardOk = true;
        if (contract.Board_Approval_Required__c) {
            boardOk = contract.Board_Approval_Date__c != null;
        }
        status.put(CHECK_BOARD_APPROVAL, boardOk);

        // Document completeness (requires Id for query)
        if (contract.Id != null) {
            status.put(CHECK_DOCUMENTS, ContractDocumentService.validateDocumentCompleteness(contract.Id));
            status.put(CHECK_SIGNATORIES, ContractSignatoryService.checkAllSigned(contract.Id));
        } else {
            status.put(CHECK_DOCUMENTS, false);
            status.put(CHECK_SIGNATORIES, false);
        }

        return status;
    }
}
