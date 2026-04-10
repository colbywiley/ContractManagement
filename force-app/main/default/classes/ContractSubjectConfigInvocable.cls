/**
 * @description Invocable Apex class for Flow integration. Accepts a list of contract Ids,
 * applies subject configuration defaults, determines approval paths, and creates
 * signatory records. Designed to be called from Screen Flows or Record-Triggered Flows
 * after the contract subject picklist is set.
 */
public with sharing class ContractSubjectConfigInvocable {

    /**
     * @description Invocable method that applies subject configuration to contracts.
     * Queries the specified contracts, applies metadata-driven defaults (approval path,
     * legal review requirements, template info, insurance requirements), then updates
     * the contracts and creates signatory records.
     * @param contractIds List of YGSF_Contract__c record Ids to process
     */
    @InvocableMethod(
        label='Apply Subject Configuration'
        description='Applies subject-based configuration defaults, determines approval paths, and creates signatory records for the specified contracts.'
        category='Contract Management'
    )
    public static void applySubjectConfiguration(List<Id> contractIds) {
        if (contractIds == null || contractIds.isEmpty()) {
            return;
        }

        // Remove null Ids to prevent query errors
        List<Id> validIds = new List<Id>();
        for (Id contractId : contractIds) {
            if (contractId != null) {
                validIds.add(contractId);
            }
        }

        if (validIds.isEmpty()) {
            return;
        }

        // Query contracts with all fields needed by the configuration services
        List<YGSF_Contract__c> contracts = [
            SELECT Id, Contract_Title__c, Contract_Type__c, Contract_Subject_Picklist__c,
                   Status__c, Approval_Path__c, Contract_Value__c, Location__c,
                   Start_Date__c, End_Date__c, Desired_Execution_Date__c,
                   Staff_Liaison__c, Legal_Reviewer__c, Attorney_Reviewer__c,
                   Branch_ED__c, VP_Approver__c, SVP_Approver__c, Officer_Approver__c,
                   Counterparty_Name__c, Counterparty_Contact__c, Counterparty_Account__c,
                   Legal_Review_Required__c, ICA_Approval_Form_Required__c,
                   COI_Required__c, Additional_Insured_Required__c,
                   YGSF_Template_Used__c, Template_Name__c,
                   Gift_Acceptance_Review__c, Board_Approval_Required__c
            FROM YGSF_Contract__c
            WHERE Id IN :validIds
        ];

        if (contracts.isEmpty()) {
            return;
        }

        // Step 1: Apply subject configuration defaults (populates approval path,
        // legal review, template, insurance, and board approval fields)
        ContractSubjectConfigService.applySubjectConfigs(contracts);

        // Step 2: Determine and override approval paths based on contract value
        // (applies above-10K path and legal review timing adjustments)
        ApprovalPathDeterminator.determineApprovalPaths(contracts);

        // Step 3: Update the contracts with the applied configuration
        if (!contracts.isEmpty()) {
            update contracts;
        }

        // Step 4: Create signatory records based on the updated configuration
        // This must happen after update so the contracts have current field values
        ContractSignatoryService.createSignatories(contracts);
    }
}
