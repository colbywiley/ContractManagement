/**
 * @description Service class that reads Contract_Subject_Config__mdt custom metadata
 * and applies configuration rules to YGSF_Contract__c records. Uses cached metadata
 * to avoid repeated queries within a transaction.
 */
public with sharing class ContractSubjectConfigService {

    // Cached map of subject name to config record, loaded once per transaction
    private static Map<String, Contract_Subject_Config__mdt> configCache;

    // Map of metadata section codes to full picklist values for Approval_Path__c
    private static final Map<String, String> APPROVAL_PATH_MAP = new Map<String, String>{
        'Section 3.2.1' => 'Section 3.2.1 - SVP and Officer',
        'Section 3.2.2' => 'Section 3.2.2 - SVP and VP',
        'Section 3.2.3' => 'Section 3.2.3 - ED and VP',
        'Section 3.2.4' => 'Section 3.2.4 - Branch ED Only'
    };

    /**
     * @description Loads all active Contract_Subject_Config__mdt records into a cached map.
     * Keyed by Subject_Name__c for O(1) lookups.
     */
    private static void loadConfigCache() {
        if (configCache != null) {
            return;
        }
        configCache = new Map<String, Contract_Subject_Config__mdt>();
        for (Contract_Subject_Config__mdt config : Contract_Subject_Config__mdt.getAll().values()) {
            if (config.Is_Active__c) {
                configCache.put(config.Subject_Name__c, config);
            }
        }
    }

    /**
     * @description Returns the metadata configuration record for the given subject name.
     * @param subjectName The Contract_Subject_Picklist__c value to look up
     * @return The matching Contract_Subject_Config__mdt record, or null if not found
     */
    public static Contract_Subject_Config__mdt getConfigForSubject(String subjectName) {
        if (String.isBlank(subjectName)) {
            return null;
        }
        loadConfigCache();
        return configCache.get(subjectName);
    }

    /**
     * @description Applies subject configuration defaults to a single contract record.
     * Populates approval path, legal review requirements, template info, insurance
     * requirements, and board approval flag based on the contract's subject picklist.
     * @param contract The YGSF_Contract__c record to populate (modified in place)
     */
    public static void applySubjectConfig(YGSF_Contract__c contract) {
        if (contract == null || String.isBlank(contract.Contract_Subject_Picklist__c)) {
            return;
        }

        Contract_Subject_Config__mdt config = getConfigForSubject(contract.Contract_Subject_Picklist__c);
        if (config == null) {
            return;
        }

        applyConfigToContract(contract, config);
    }

    /**
     * @description Bulk version of applySubjectConfig. Processes a list of contracts
     * efficiently using the cached metadata map.
     * @param contracts List of YGSF_Contract__c records to populate
     */
    public static void applySubjectConfigs(List<YGSF_Contract__c> contracts) {
        if (contracts == null || contracts.isEmpty()) {
            return;
        }

        loadConfigCache();

        for (YGSF_Contract__c contract : contracts) {
            if (contract == null || String.isBlank(contract.Contract_Subject_Picklist__c)) {
                continue;
            }
            Contract_Subject_Config__mdt config = configCache.get(contract.Contract_Subject_Picklist__c);
            if (config != null) {
                applyConfigToContract(contract, config);
            }
        }
    }

    /**
     * @description Internal method that maps config field values onto a contract record.
     * @param contract The contract to populate
     * @param config The metadata config to read from
     */
    private static void applyConfigToContract(YGSF_Contract__c contract, Contract_Subject_Config__mdt config) {
        // Set approval path using the section-to-label mapping
        String approvalPathCode = config.Default_Approval_Path__c;
        if (String.isNotBlank(approvalPathCode)) {
            contract.Approval_Path__c = APPROVAL_PATH_MAP.containsKey(approvalPathCode)
                ? APPROVAL_PATH_MAP.get(approvalPathCode)
                : approvalPathCode;
        }

        // Set legal review timing
        if (String.isNotBlank(config.Legal_Review_Timing__c)) {
            contract.Legal_Review_Required__c = config.Legal_Review_Timing__c;
        }

        // Set document and form requirements
        contract.ICA_Approval_Form_Required__c = config.ICA_Approval_Form_Required__c;
        contract.COI_Required__c = config.COI_Required__c;
        contract.Additional_Insured_Required__c = config.Additional_Insured_Required__c;

        // Set template information
        contract.YGSF_Template_Used__c = config.YGSF_Template_Required__c;
        if (String.isNotBlank(config.Template_Name__c)) {
            contract.Template_Name__c = config.Template_Name__c;
        }

        // Set review and approval flags
        contract.Gift_Acceptance_Review__c = config.Gift_Acceptance_Review__c;

        // Only set Board_Approval_Required__c to true if config indicates it may apply
        if (config.Board_Approval_May_Apply__c) {
            contract.Board_Approval_Required__c = true;
        }
    }

    /**
     * @description Resolves an approval path section code to the full picklist label.
     * @param sectionCode The section code (e.g., 'Section 3.2.1')
     * @return The full picklist value, or the original code if no mapping exists
     */
    public static String resolveApprovalPathLabel(String sectionCode) {
        if (String.isBlank(sectionCode)) {
            return null;
        }
        return APPROVAL_PATH_MAP.containsKey(sectionCode)
            ? APPROVAL_PATH_MAP.get(sectionCode)
            : sectionCode;
    }
}
