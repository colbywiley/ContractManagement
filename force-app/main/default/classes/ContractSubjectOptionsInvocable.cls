/**
 * @description Invocable Apex class that provides contract subject options from
 * Contract_Subject_Config__mdt custom metadata for use in Screen Flows.
 * Returns active subject names as a list of strings that can be used as a
 * collection choice set, keeping the flow in sync with metadata configuration.
 */
public with sharing class ContractSubjectOptionsInvocable {

    /**
     * @description Returns all active contract subject names from custom metadata.
     * Used by Screen Flows to populate the Contract Subject picklist dynamically.
     * @param requests Not used - invocable methods require a List parameter
     * @return List of SubjectOption lists (one per invocation, each containing all subjects)
     */
    @InvocableMethod(
        label='Get Contract Subject Options'
        description='Returns active contract subject names from Contract_Subject_Config__mdt'
    )
    public static List<List<SubjectOption>> getSubjectOptions(List<String> requests) {
        List<SubjectOption> options = new List<SubjectOption>();

        for (Contract_Subject_Config__mdt config : Contract_Subject_Config__mdt.getAll().values()) {
            if (config.Is_Active__c) {
                SubjectOption opt = new SubjectOption();
                opt.subjectName = config.Subject_Name__c;
                opt.approvalPath = config.Default_Approval_Path__c;
                opt.legalReviewTiming = config.Legal_Review_Timing__c;
                opt.coiRequired = config.COI_Required__c;
                opt.icaFormRequired = config.ICA_Approval_Form_Required__c;
                opt.templateName = config.Template_Name__c;
                options.add(opt);
            }
        }

        // Sort alphabetically
        options.sort();

        // Wrap in outer list (one result per invocation)
        return new List<List<SubjectOption>>{ options };
    }

    /**
     * @description Wrapper class for subject option data passed back to the flow.
     * Implements Comparable for alphabetical sorting.
     */
    public class SubjectOption implements Comparable {
        @InvocableVariable(label='Subject Name' required=true)
        public String subjectName;

        @InvocableVariable(label='Approval Path')
        public String approvalPath;

        @InvocableVariable(label='Legal Review Timing')
        public String legalReviewTiming;

        @InvocableVariable(label='COI Required')
        public Boolean coiRequired;

        @InvocableVariable(label='ICA Form Required')
        public Boolean icaFormRequired;

        @InvocableVariable(label='Template Name')
        public String templateName;

        public Integer compareTo(Object other) {
            SubjectOption otherOpt = (SubjectOption) other;
            if (this.subjectName == null) return -1;
            if (otherOpt.subjectName == null) return 1;
            return this.subjectName.compareTo(otherOpt.subjectName);
        }
    }
}
