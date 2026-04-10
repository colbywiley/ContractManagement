/**
 * @description Invocable Apex class for contract renewal Flow integration. Accepts
 * a list of original contract Ids and creates renewal contracts for each. Returns
 * the Ids of the newly created renewal contracts for downstream Flow processing.
 */
public with sharing class ContractRenewalInvocable {

    /**
     * @description Invocable method that creates renewal contracts from originals.
     * Processes each contract Id individually so that a failure on one record does
     * not block the others. Errors are captured in the result list as null Ids.
     * @param originalContractIds List of YGSF_Contract__c Ids to renew
     * @return List of new contract Ids (positionally aligned with the input list;
     *         null entries indicate a renewal that failed)
     */
    @InvocableMethod(
        label='Create Contract Renewals'
        description='Creates renewal contracts from the specified original contracts. Returns the new contract Ids.'
        category='Contract Management'
    )
    public static List<Id> createRenewals(List<Id> originalContractIds) {
        List<Id> renewedContractIds = new List<Id>();

        if (originalContractIds == null || originalContractIds.isEmpty()) {
            return renewedContractIds;
        }

        for (Id originalId : originalContractIds) {
            if (originalId == null) {
                renewedContractIds.add(null);
                continue;
            }

            try {
                Id renewalId = ContractRenewalService.createRenewal(originalId);
                renewedContractIds.add(renewalId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'ContractRenewalInvocable: Failed to renew contract ' + originalId +
                    '. Error: ' + e.getMessage()
                );
                renewedContractIds.add(null);
            }
        }

        return renewedContractIds;
    }
}
