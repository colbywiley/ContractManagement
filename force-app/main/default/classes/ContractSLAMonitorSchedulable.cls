/**
 * @description Schedulable class that launches the ContractSLAMonitorBatch on a recurring
 * schedule. Intended to run daily to detect and alert on SLA breaches.
 *
 * Schedule example:
 *   String cronExp = '0 0 6 * * ?'; // Daily at 6 AM
 *   System.schedule('Contract SLA Monitor', cronExp, new ContractSLAMonitorSchedulable());
 */
public with sharing class ContractSLAMonitorSchedulable implements Schedulable {

    /** Default batch size for the SLA monitor batch job */
    private static final Integer DEFAULT_BATCH_SIZE = 200;

    /**
     * @description Executes the scheduled job by launching ContractSLAMonitorBatch.
     * @param sc The schedulable context
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ContractSLAMonitorBatch(), DEFAULT_BATCH_SIZE);
    }
}
