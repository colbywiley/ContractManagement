/**
 * @description Service class for calculating SLA deadlines and checking SLA compliance.
 * Reads SLA_Configuration__mdt records and uses BusinessDayCalculator for date math.
 * SLA configurations define the number of business days allowed for each workflow step.
 */
public with sharing class SLACalculatorService {

    // Cached map of SLA name to configuration record, loaded once per transaction
    private static Map<String, SLA_Configuration__mdt> slaCache;

    /**
     * @description Loads all SLA_Configuration__mdt records into a cached map
     * keyed by SLA_Name__c for efficient lookups.
     */
    private static void loadSLACache() {
        if (slaCache != null) {
            return;
        }
        slaCache = new Map<String, SLA_Configuration__mdt>();
        for (SLA_Configuration__mdt config : SLA_Configuration__mdt.getAll().values()) {
            if (String.isNotBlank(config.SLA_Name__c)) {
                slaCache.put(config.SLA_Name__c, config);
            }
        }
    }

    /**
     * @description Retrieves the SLA configuration record for a given SLA name.
     * @param slaName The SLA_Name__c value to look up (e.g., 'Submission Lead Time')
     * @return The matching SLA_Configuration__mdt record, or null if not found
     */
    public static SLA_Configuration__mdt getSLAConfiguration(String slaName) {
        if (String.isBlank(slaName)) {
            return null;
        }
        loadSLACache();
        return slaCache.get(slaName);
    }

    /**
     * @description Calculates the SLA deadline date by adding the configured number of
     * business days to the start date. Uses BusinessDayCalculator for accurate
     * business day computation.
     * @param slaName The SLA_Name__c identifying which SLA to apply
     * @param startDate The date from which to begin counting business days
     * @return The deadline date, or null if the SLA config is not found or inputs are invalid
     */
    public static Date calculateDeadline(String slaName, Date startDate) {
        if (String.isBlank(slaName) || startDate == null) {
            return null;
        }

        SLA_Configuration__mdt config = getSLAConfiguration(slaName);
        if (config == null || config.Business_Days__c == null) {
            return null;
        }

        Integer businessDays = config.Business_Days__c.intValue();
        return BusinessDayCalculator.addBusinessDays(startDate, businessDays);
    }

    /**
     * @description Checks whether the current date is still within the SLA window.
     * The SLA window starts at startDate and extends for the configured number of
     * business days. Returns true if currentDate is on or before the deadline.
     * @param slaName The SLA_Name__c identifying which SLA to check
     * @param startDate The date the SLA clock started
     * @param currentDate The date to evaluate against the SLA deadline
     * @return True if within SLA, false if breached or inputs are invalid
     */
    public static Boolean isWithinSLA(String slaName, Date startDate, Date currentDate) {
        if (String.isBlank(slaName) || startDate == null || currentDate == null) {
            return false;
        }

        Date deadline = calculateDeadline(slaName, startDate);
        if (deadline == null) {
            return false;
        }

        return currentDate <= deadline;
    }

    /**
     * @description Returns the number of business days configured for a given SLA.
     * @param slaName The SLA name to look up
     * @return The number of business days, or null if not found
     */
    public static Integer getBusinessDaysForSLA(String slaName) {
        SLA_Configuration__mdt config = getSLAConfiguration(slaName);
        if (config == null || config.Business_Days__c == null) {
            return null;
        }
        return config.Business_Days__c.intValue();
    }
}
