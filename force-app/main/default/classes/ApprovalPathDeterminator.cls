/**
 * @description Determines the correct approval path for YGSF contracts based on
 * subject configuration and contract value. Contracts exceeding the $10,000
 * threshold may follow a different approval path and legal review timing.
 */
public with sharing class ApprovalPathDeterminator {

    /** Threshold above which alternate approval paths and legal review timing apply */
    private static final Decimal VALUE_THRESHOLD = 10000;

    /**
     * @description Determines the approval path for a single contract. If the contract
     * value exceeds $10,000 and the subject config specifies an alternate path, that
     * path is used. Also adjusts legal review timing for high-value contracts.
     * @param contract The YGSF_Contract__c record to evaluate
     * @return The resolved approval path picklist value, or null if undetermined
     */
    public static String determineApprovalPath(YGSF_Contract__c contract) {
        if (contract == null || String.isBlank(contract.Contract_Subject_Picklist__c)) {
            return null;
        }

        Contract_Subject_Config__mdt config =
            ContractSubjectConfigService.getConfigForSubject(contract.Contract_Subject_Picklist__c);
        if (config == null) {
            return null;
        }

        return resolvePathFromConfig(contract, config);
    }

    /**
     * @description Bulk version that determines approval paths for a list of contracts.
     * Modifies each contract's Approval_Path__c and Legal_Review_Required__c in place.
     * @param contracts List of YGSF_Contract__c records to process
     */
    public static void determineApprovalPaths(List<YGSF_Contract__c> contracts) {
        if (contracts == null || contracts.isEmpty()) {
            return;
        }

        for (YGSF_Contract__c contract : contracts) {
            if (contract == null || String.isBlank(contract.Contract_Subject_Picklist__c)) {
                continue;
            }

            Contract_Subject_Config__mdt config =
                ContractSubjectConfigService.getConfigForSubject(contract.Contract_Subject_Picklist__c);
            if (config == null) {
                continue;
            }

            String resolvedPath = resolvePathFromConfig(contract, config);
            if (String.isNotBlank(resolvedPath)) {
                contract.Approval_Path__c = resolvedPath;
            }

            // Adjust legal review timing for contracts above the value threshold
            adjustLegalReviewTiming(contract, config);
        }
    }

    /**
     * @description Resolves the correct approval path section based on contract value
     * and subject configuration. Uses the above-10K path when the contract value
     * exceeds the threshold and an alternate path is configured.
     * @param contract The contract to evaluate
     * @param config The subject configuration metadata
     * @return The full approval path picklist label
     */
    private static String resolvePathFromConfig(
        YGSF_Contract__c contract,
        Contract_Subject_Config__mdt config
    ) {
        String pathCode;

        // Use the above-10K approval path if contract value exceeds threshold and path is configured
        Boolean isAboveThreshold = contract.Contract_Value__c != null
            && contract.Contract_Value__c > VALUE_THRESHOLD;

        if (isAboveThreshold && String.isNotBlank(config.Approval_Path_Above_10K__c)) {
            pathCode = config.Approval_Path_Above_10K__c;
        } else {
            pathCode = config.Default_Approval_Path__c;
        }

        return ContractSubjectConfigService.resolveApprovalPathLabel(pathCode);
    }

    /**
     * @description Adjusts the Legal_Review_Required__c field on the contract when
     * the value exceeds $10,000 and the subject config defines a different legal
     * review timing for high-value contracts.
     * @param contract The contract to modify
     * @param config The subject configuration metadata
     */
    private static void adjustLegalReviewTiming(
        YGSF_Contract__c contract,
        Contract_Subject_Config__mdt config
    ) {
        Boolean isAboveThreshold = contract.Contract_Value__c != null
            && contract.Contract_Value__c > VALUE_THRESHOLD;

        if (isAboveThreshold && String.isNotBlank(config.Legal_Review_Timing_Above_10K__c)) {
            contract.Legal_Review_Required__c = config.Legal_Review_Timing_Above_10K__c;
        }
    }
}
