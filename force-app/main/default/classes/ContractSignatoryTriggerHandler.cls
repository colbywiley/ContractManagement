/**
 * @description Trigger handler for Contract_Signatory__c. Stamps the Signed_Date__c
 * when a signatory signs, and checks whether all required signatories have signed
 * to advance the parent contract to Fully Executed status.
 */
public with sharing class ContractSignatoryTriggerHandler {

    /**
     * @description Before update: stamp Signed_Date__c with today when Signed__c
     * changes from false to true.
     * @param newSignatories The updated Contract_Signatory__c records
     * @param oldMap Map of old record versions keyed by Id
     */
    public void beforeUpdate(List<Contract_Signatory__c> newSignatories, Map<Id, Contract_Signatory__c> oldMap) {
        for (Contract_Signatory__c sig : newSignatories) {
            Contract_Signatory__c oldSig = oldMap.get(sig.Id);
            if (sig.Signed__c && !oldSig.Signed__c) {
                sig.Signed_Date__c = Date.today();
            }
        }
    }

    /**
     * @description After update: when a signatory is marked as signed, check if all
     * required signatories for the parent contract are now signed. If so, update the
     * parent contract Status__c to Fully Executed.
     * @param newSignatories The updated Contract_Signatory__c records
     * @param oldMap Map of old record versions keyed by Id
     */
    public void afterUpdate(List<Contract_Signatory__c> newSignatories, Map<Id, Contract_Signatory__c> oldMap) {
        // Collect parent contract Ids where a signatory just signed
        Set<Id> contractIdsToCheck = new Set<Id>();

        for (Contract_Signatory__c sig : newSignatories) {
            Contract_Signatory__c oldSig = oldMap.get(sig.Id);
            if (sig.Signed__c && !oldSig.Signed__c && sig.Contract__c != null) {
                contractIdsToCheck.add(sig.Contract__c);
            }
        }

        if (contractIdsToCheck.isEmpty()) {
            return;
        }

        // For each parent contract, check if all required signatories are signed
        List<YGSF_Contract__c> contractsToUpdate = new List<YGSF_Contract__c>();

        for (Id contractId : contractIdsToCheck) {
            if (ContractSignatoryService.checkAllSigned(contractId)) {
                contractsToUpdate.add(new YGSF_Contract__c(
                    Id = contractId,
                    Status__c = 'Fully Executed'
                ));
            }
        }

        if (!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }
    }
}
