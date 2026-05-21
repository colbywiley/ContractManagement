import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import CONTRACT_SUBJECT from '@salesforce/schema/YGSF_Contract__c.Contract_Subject_Picklist__c';
import APPROVAL_PATH from '@salesforce/schema/YGSF_Contract__c.Approval_Path__c';
import CONTRACT_VALUE from '@salesforce/schema/YGSF_Contract__c.Contract_Value__c';
import COI_REQUIRED from '@salesforce/schema/YGSF_Contract__c.COI_Required__c';
import ADDITIONAL_INSURED_REQUIRED from '@salesforce/schema/YGSF_Contract__c.Additional_Insured_Required__c';
import ICA_FORM_REQUIRED from '@salesforce/schema/YGSF_Contract__c.ICA_Approval_Form_Required__c';
import LEGAL_REVIEW_REQUIRED from '@salesforce/schema/YGSF_Contract__c.Legal_Review_Required__c';
import LEGAL_REVIEW_REQUIRED_BEFORE from '@salesforce/schema/YGSF_Contract__c.Legal_Review_Required_Before__c';
import BOARD_APPROVAL_REQUIRED from '@salesforce/schema/YGSF_Contract__c.Board_Approval_Required__c';
import GIFT_ACCEPTANCE_REVIEW from '@salesforce/schema/YGSF_Contract__c.Gift_Acceptance_Review__c';
import YGSF_TEMPLATE_USED from '@salesforce/schema/YGSF_Contract__c.YGSF_Template_Used__c';
import TEMPLATE_NAME from '@salesforce/schema/YGSF_Contract__c.Template_Name__c';

const FIELDS = [
    CONTRACT_SUBJECT, APPROVAL_PATH, CONTRACT_VALUE,
    COI_REQUIRED, ADDITIONAL_INSURED_REQUIRED, ICA_FORM_REQUIRED,
    LEGAL_REVIEW_REQUIRED, LEGAL_REVIEW_REQUIRED_BEFORE,
    BOARD_APPROVAL_REQUIRED, GIFT_ACCEPTANCE_REVIEW,
    YGSF_TEMPLATE_USED, TEMPLATE_NAME
];

export default class ContractSubjectRulesViewer extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    contract;

    get isLoading() {
        return !this.contract.data && !this.contract.error;
    }

    get hasError() {
        return !!this.contract.error;
    }

    get errorMessage() {
        if (!this.contract.error) return '';
        return this.contract.error.body
            ? this.contract.error.body.message
            : 'An error occurred loading subject rules.';
    }

    get hasData() {
        return !!this.contract.data;
    }

    get contractSubject() {
        return getFieldValue(this.contract.data, CONTRACT_SUBJECT) || 'Not Specified';
    }

    get approvalPath() {
        return getFieldValue(this.contract.data, APPROVAL_PATH) || 'Not Determined';
    }

    get contractValue() {
        const val = getFieldValue(this.contract.data, CONTRACT_VALUE);
        if (val === null || val === undefined) return 'Not Specified';
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val);
    }

    get approvalPathDescription() {
        const path = getFieldValue(this.contract.data, APPROVAL_PATH);
        const descriptions = {
            '3.2.1': 'Requires Legal Review before execution, SVP and Officer approval. For contracts above $10,000 or specific high-risk subjects.',
            '3.2.2': 'Requires Legal Review before execution, SVP and VP approval. Standard path for mid-value contracts.',
            '3.2.3': 'ED and VP approval before execution, Legal Review after execution. For lower-risk operational contracts.',
            '3.2.4': 'ED approval only. Simplified path for low-value, routine contracts under $10,000.'
        };
        return descriptions[path] || 'Approval path rules have not been determined for this contract.';
    }

    get requiredDocuments() {
        if (!this.contract.data) return [];
        const docs = [];

        if (getFieldValue(this.contract.data, COI_REQUIRED)) {
            docs.push({ id: 'coi', label: 'Certificate of Insurance (COI)', icon: 'utility:file' });
        }
        if (getFieldValue(this.contract.data, ADDITIONAL_INSURED_REQUIRED)) {
            docs.push({ id: 'ai', label: 'Additional Insured Endorsement', icon: 'utility:file' });
        }
        if (getFieldValue(this.contract.data, ICA_FORM_REQUIRED)) {
            docs.push({ id: 'ica', label: 'ICA Approval Form', icon: 'utility:file' });
        }

        return docs;
    }

    get hasRequiredDocuments() {
        return this.requiredDocuments.length > 0;
    }

    get legalReviewTiming() {
        const required = getFieldValue(this.contract.data, LEGAL_REVIEW_REQUIRED);
        if (!required) return 'Not Required';
        const before = getFieldValue(this.contract.data, LEGAL_REVIEW_REQUIRED_BEFORE);
        if (before === 'Before Execution' || before === true) return 'Before Execution';
        if (before === 'After Execution') return 'After Execution';
        return 'Required';
    }

    get legalReviewRequired() {
        return !!getFieldValue(this.contract.data, LEGAL_REVIEW_REQUIRED);
    }

    get boardApprovalRequired() {
        return !!getFieldValue(this.contract.data, BOARD_APPROVAL_REQUIRED);
    }

    get giftAcceptanceReview() {
        return !!getFieldValue(this.contract.data, GIFT_ACCEPTANCE_REVIEW);
    }

    get templateUsed() {
        return !!getFieldValue(this.contract.data, YGSF_TEMPLATE_USED);
    }

    get templateName() {
        return getFieldValue(this.contract.data, TEMPLATE_NAME) || 'N/A';
    }

    get signatoryRules() {
        const path = getFieldValue(this.contract.data, APPROVAL_PATH);
        const rules = {
            '3.2.1': [
                { id: 'officer', role: 'Officer', required: true },
                { id: 'svp', role: 'Senior VP (SVP)', required: true },
                { id: 'counterparty', role: 'Counterparty', required: true }
            ],
            '3.2.2': [
                { id: 'svp', role: 'Senior VP (SVP)', required: true },
                { id: 'vp', role: 'Vice President (VP)', required: true },
                { id: 'counterparty', role: 'Counterparty', required: true }
            ],
            '3.2.3': [
                { id: 'vp', role: 'Vice President (VP)', required: true },
                { id: 'ed', role: 'Executive Director (ED)', required: true },
                { id: 'counterparty', role: 'Counterparty', required: true }
            ],
            '3.2.4': [
                { id: 'ed', role: 'Executive Director (ED)', required: true },
                { id: 'counterparty', role: 'Counterparty', required: true }
            ]
        };
        return rules[path] || [];
    }

    get hasSignatoryRules() {
        return this.signatoryRules.length > 0;
    }

    get cardTitle() {
        return `Subject Rules: ${this.contractSubject}`;
    }
}
