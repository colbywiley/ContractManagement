/**
 * @description Schedulable class that launches the ContractExpirationBatch on a recurring
 * schedule. Intended to run daily to expire contracts and send reminder notifications.
 *
 * Schedule example:
 *   String cronExp = '0 0 1 * * ?'; // Daily at 1 AM
 *   System.schedule('Contract Expiration Check', cronExp, new ContractExpirationSchedulable());
 */
public with sharing class ContractExpirationSchedulable implements Schedulable {

    /** Default batch size for the expiration batch job */
    private static final Integer DEFAULT_BATCH_SIZE = 200;

    /**
     * @description Executes the scheduled job by launching ContractExpirationBatch.
     * @param sc The schedulable context
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ContractExpirationBatch(), DEFAULT_BATCH_SIZE);
    }
}
