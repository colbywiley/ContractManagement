/**
 * @description Service class for sending email notifications related to the YGSF
 * contract lifecycle. Handles submission confirmations, legal review completions,
 * approval requests, expiration warnings, and SLA breach alerts.
 *
 * Uses Messaging.SingleEmailMessage for transactional emails. In production,
 * consider replacing with org-wide email addresses and email templates.
 */
public with sharing class ContractNotificationService {

    // Email subject prefixes for easy identification in inboxes
    private static final String SUBJECT_PREFIX = 'YGSF Contract: ';
    private static final String DO_NOT_REPLY = '\n\n---\nDo not reply to this email. Please log in to Salesforce and use the Contract Action Panel to take action.';

    /**
     * @description Returns the URL to a contract record.
     */
    private static String getContractUrl(Id contractId) {
        return URL.getOrgDomainURL().toExternalForm() + '/' + contractId;
    }

    /**
     * @description Sends submission confirmation to the Staff Liaison and a review
     * assignment notification to the Legal Reviewer when a contract is submitted.
     * @param contract The submitted YGSF_Contract__c record (must have Staff_Liaison__c
     *        and optionally Legal_Reviewer__c populated)
     */
    public static void notifySubmission(YGSF_Contract__c contract) {
        if (contract == null) {
            return;
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String contractTitle = getContractTitle(contract);

        String contractUrl = getContractUrl(contract.Id);

        // Confirmation to Staff Liaison
        if (contract.Staff_Liaison__c != null) {
            emails.add(buildEmail(
                contract.Staff_Liaison__c,
                SUBJECT_PREFIX + 'Submission Confirmation - ' + contractTitle,
                'Your contract "' + contractTitle + '" has been successfully submitted for review. ' +
                'You will receive notifications as the contract progresses through the approval process.\n\n' +
                'Contract Status: ' + safeString(contract.Status__c) + '\n' +
                'Approval Path: ' + safeString(contract.Approval_Path__c) + '\n\n' +
                'View Contract: ' + contractUrl + DO_NOT_REPLY
            ));
        }

        // Assignment notification to Legal Reviewer (only our custom email here;
        // Salesforce sends its own approval request email at each step).
        if (contract.Legal_Reviewer__c != null
            && contract.Legal_Review_Required__c != 'Not Required') {
            emails.add(buildEmail(
                contract.Legal_Reviewer__c,
                SUBJECT_PREFIX + 'Legal Review Assigned - ' + contractTitle,
                'A new contract has been submitted and requires your legal review.\n\n' +
                'Contract Title: ' + contractTitle + '\n' +
                'Contract Type: ' + safeString(contract.Contract_Type__c) + '\n' +
                'Contract Subject: ' + safeString(contract.Contract_Subject_Picklist__c) + '\n' +
                'Contract Value: ' + formatCurrency(contract.Contract_Value__c) + '\n' +
                'Legal Review Timing: ' + safeString(contract.Legal_Review_Required__c) + '\n\n' +
                'Please log in to Salesforce to begin your review:\n' + contractUrl + DO_NOT_REPLY
            ));
        }

        sendEmails(emails);
    }

    /**
     * @description Notifies the Staff Liaison that legal review has been completed.
     * @param contract The YGSF_Contract__c record with legal review complete
     */
    public static void notifyLegalReviewComplete(YGSF_Contract__c contract) {
        if (contract == null || contract.Staff_Liaison__c == null) {
            return;
        }

        String contractTitle = getContractTitle(contract);

        Messaging.SingleEmailMessage email = buildEmail(
            contract.Staff_Liaison__c,
            SUBJECT_PREFIX + 'Legal Review Complete - ' + contractTitle,
            'The legal review for your contract "' + contractTitle + '" has been completed.\n\n' +
            'Legal Review Date: ' + formatDate(contract.Legal_Review_Date__c) + '\n' +
            'The contract will now proceed to the next step in the approval process.\n\n' +
            'View Contract: ' + getContractUrl(contract.Id) + DO_NOT_REPLY
        );

        sendEmails(new List<Messaging.SingleEmailMessage>{ email });
    }

    /**
     * @description Sends an approval request notification to the specified approver.
     * @param contract The YGSF_Contract__c record requiring approval
     * @param approverId The User Id of the approver to notify
     */
    public static void notifyApprovalRequired(YGSF_Contract__c contract, Id approverId) {
        if (contract == null || approverId == null) {
            return;
        }

        String contractTitle = getContractTitle(contract);

        Messaging.SingleEmailMessage email = buildEmail(
            approverId,
            SUBJECT_PREFIX + 'Approval Required - ' + contractTitle,
            'A contract requires your approval.\n\n' +
            'Contract Title: ' + contractTitle + '\n' +
            'Contract Type: ' + safeString(contract.Contract_Type__c) + '\n' +
            'Contract Subject: ' + safeString(contract.Contract_Subject_Picklist__c) + '\n' +
            'Contract Value: ' + formatCurrency(contract.Contract_Value__c) + '\n' +
            'Counterparty: ' + safeString(contract.Counterparty_Name__c) + '\n' +
            'Approval Path: ' + safeString(contract.Approval_Path__c) + '\n\n' +
            'Please log in to Salesforce to review and take action:\n' +
            getContractUrl(contract.Id) + DO_NOT_REPLY
        );

        sendEmails(new List<Messaging.SingleEmailMessage>{ email });
    }

    /**
     * @description Sends an expiration warning notification to the Staff Liaison and
     * Branch ED. Used by scheduled jobs to alert stakeholders before contract expiry.
     * @param contract The YGSF_Contract__c record approaching expiration
     * @param daysUntilExpiry Number of days until the contract expires
     */
    public static void notifyExpirationWarning(YGSF_Contract__c contract, Integer daysUntilExpiry) {
        if (contract == null) {
            return;
        }

        String contractTitle = getContractTitle(contract);
        String daysText = (daysUntilExpiry != null) ? String.valueOf(daysUntilExpiry) : 'unknown';
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        String body = 'The following contract is expiring in ' + daysText + ' day(s).\n\n' +
            'Contract Title: ' + contractTitle + '\n' +
            'End Date: ' + formatDate(contract.End_Date__c) + '\n' +
            'Auto-Renew: ' + (contract.Auto_Renew__c ? 'Yes' : 'No') + '\n' +
            'Counterparty: ' + safeString(contract.Counterparty_Name__c) + '\n\n' +
            'Please take appropriate action to renew or allow the contract to expire.\n\n' +
            'View Contract: ' + getContractUrl(contract.Id) + DO_NOT_REPLY;

        // Notify Staff Liaison
        if (contract.Staff_Liaison__c != null) {
            emails.add(buildEmail(
                contract.Staff_Liaison__c,
                SUBJECT_PREFIX + 'Expiration Warning (' + daysText + ' days) - ' + contractTitle,
                body
            ));
        }

        // Also notify Branch ED
        if (contract.Branch_ED__c != null && contract.Branch_ED__c != contract.Staff_Liaison__c) {
            emails.add(buildEmail(
                contract.Branch_ED__c,
                SUBJECT_PREFIX + 'Expiration Warning (' + daysText + ' days) - ' + contractTitle,
                body
            ));
        }

        sendEmails(emails);
    }

    /**
     * @description Sends an SLA breach alert to the Staff Liaison, Branch ED, and
     * Legal Reviewer when a contract has exceeded its SLA deadline.
     * @param contract The YGSF_Contract__c record that has breached its SLA
     */
    public static void notifySLABreach(YGSF_Contract__c contract) {
        if (contract == null) {
            return;
        }

        String contractTitle = getContractTitle(contract);
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        String body = 'ALERT: The following contract has exceeded its SLA deadline.\n\n' +
            'Contract Title: ' + contractTitle + '\n' +
            'Current Status: ' + safeString(contract.Status__c) + '\n' +
            'Submission Date: ' + formatDate(contract.Submission_Date__c) + '\n' +
            'Counterparty: ' + safeString(contract.Counterparty_Name__c) + '\n\n' +
            'Immediate attention is required to bring this contract back on track.\n\n' +
            'View Contract: ' + getContractUrl(contract.Id) + DO_NOT_REPLY;

        // Collect unique recipients
        Set<Id> notified = new Set<Id>();

        if (contract.Staff_Liaison__c != null) {
            emails.add(buildEmail(
                contract.Staff_Liaison__c,
                SUBJECT_PREFIX + 'SLA Breach Alert - ' + contractTitle,
                body
            ));
            notified.add(contract.Staff_Liaison__c);
        }

        if (contract.Branch_ED__c != null && !notified.contains(contract.Branch_ED__c)) {
            emails.add(buildEmail(
                contract.Branch_ED__c,
                SUBJECT_PREFIX + 'SLA Breach Alert - ' + contractTitle,
                body
            ));
            notified.add(contract.Branch_ED__c);
        }

        if (contract.Legal_Reviewer__c != null && !notified.contains(contract.Legal_Reviewer__c)) {
            emails.add(buildEmail(
                contract.Legal_Reviewer__c,
                SUBJECT_PREFIX + 'SLA Breach Alert - ' + contractTitle,
                body
            ));
        }

        sendEmails(emails);
    }

    // ========== Private Helper Methods ==========

    /**
     * @description Builds a SingleEmailMessage targeted to a specific user.
     * @param targetUserId The recipient User Id
     * @param subject The email subject line
     * @param body The plain text email body
     * @return A configured Messaging.SingleEmailMessage
     */
    private static Messaging.SingleEmailMessage buildEmail(
        Id targetUserId, String subject, String body
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(targetUserId);
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setSaveAsActivity(false);
        return email;
    }

    /**
     * @description Sends a list of emails, handling any errors gracefully.
     * Logs errors via System.debug rather than throwing exceptions so that
     * notification failures do not block contract processing.
     * @param emails List of emails to send
     */
    private static void sendEmails(List<Messaging.SingleEmailMessage> emails) {
        if (emails.isEmpty()) {
            return;
        }

        try {
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails, false);
            for (Messaging.SendEmailResult result : results) {
                if (!result.isSuccess()) {
                    for (Messaging.SendEmailError err : result.getErrors()) {
                        System.debug(LoggingLevel.ERROR,
                            'ContractNotificationService email error: ' + err.getMessage()
                        );
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'ContractNotificationService.sendEmails failed: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Safely returns the contract title, or a default if blank.
     */
    private static String getContractTitle(YGSF_Contract__c contract) {
        return String.isNotBlank(contract.Contract_Title__c)
            ? contract.Contract_Title__c
            : '(Untitled Contract)';
    }

    /**
     * @description Returns the string value or a default placeholder if null/blank.
     */
    private static String safeString(String value) {
        return String.isNotBlank(value) ? value : 'N/A';
    }

    /**
     * @description Formats a Date for display in email notifications.
     */
    private static String formatDate(Date d) {
        if (d == null) {
            return 'N/A';
        }
        return String.valueOf(d);
    }

    /**
     * @description Formats a Decimal as currency for display.
     */
    private static String formatCurrency(Decimal value) {
        if (value == null) {
            return 'N/A';
        }
        return '$' + value.setScale(2).format();
    }
}
