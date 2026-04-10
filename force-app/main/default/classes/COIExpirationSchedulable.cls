/**
 * @description Schedulable class that launches the COIExpirationBatch on a recurring
 * schedule. Intended to run daily to check for expiring COI documents and send warnings.
 *
 * Schedule example:
 *   String cronExp = '0 0 2 * * ?'; // Daily at 2 AM
 *   System.schedule('COI Expiration Check', cronExp, new COIExpirationSchedulable());
 */
public with sharing class COIExpirationSchedulable implements Schedulable {

    /** Default batch size for the COI expiration batch job */
    private static final Integer DEFAULT_BATCH_SIZE = 200;

    /**
     * @description Executes the scheduled job by launching COIExpirationBatch.
     * @param sc The schedulable context
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new COIExpirationBatch(), DEFAULT_BATCH_SIZE);
    }
}
