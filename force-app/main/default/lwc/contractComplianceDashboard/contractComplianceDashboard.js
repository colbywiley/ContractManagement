import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import COI_REQUIRED from '@salesforce/schema/YGSF_Contract__c.COI_Required__c';
import COI_RECEIVED from '@salesforce/schema/YGSF_Contract__c.COI_Received__c';
import ADDITIONAL_INSURED_REQUIRED from '@salesforce/schema/YGSF_Contract__c.Additional_Insured_Required__c';
import ADDITIONAL_INSURED_RECEIVED from '@salesforce/schema/YGSF_Contract__c.Additional_Insured_Received__c';
import ICA_FORM_REQUIRED from '@salesforce/schema/YGSF_Contract__c.ICA_Approval_Form_Required__c';
import ICA_FORM_RECEIVED from '@salesforce/schema/YGSF_Contract__c.ICA_Approval_Form_Received__c';
import LEGAL_REVIEW_COMPLETE from '@salesforce/schema/YGSF_Contract__c.Legal_Review_Complete__c';
import LEGAL_REVIEW_REQUIRED from '@salesforce/schema/YGSF_Contract__c.Legal_Review_Required__c';
import STATUS from '@salesforce/schema/YGSF_Contract__c.Status__c';
import BOARD_APPROVAL_REQUIRED from '@salesforce/schema/YGSF_Contract__c.Board_Approval_Required__c';
import BOARD_APPROVAL_DATE from '@salesforce/schema/YGSF_Contract__c.Board_Approval_Date__c';
import CFO_PAYMENT_APPROVAL from '@salesforce/schema/YGSF_Contract__c.CFO_Payment_Approval__c';
import PAYMENT_METHOD from '@salesforce/schema/YGSF_Contract__c.Payment_Method__c';

const FIELDS = [
    COI_REQUIRED, COI_RECEIVED,
    ADDITIONAL_INSURED_REQUIRED, ADDITIONAL_INSURED_RECEIVED,
    ICA_FORM_REQUIRED, ICA_FORM_RECEIVED,
    LEGAL_REVIEW_COMPLETE, LEGAL_REVIEW_REQUIRED,
    STATUS,
    BOARD_APPROVAL_REQUIRED, BOARD_APPROVAL_DATE,
    CFO_PAYMENT_APPROVAL, PAYMENT_METHOD
];

export default class ContractComplianceDashboard extends LightningElement {
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
            : 'An error occurred loading compliance data.';
    }

    get complianceItems() {
        if (!this.contract.data) return [];
        const items = [];

        // COI check
        if (getFieldValue(this.contract.data, COI_REQUIRED)) {
            const received = getFieldValue(this.contract.data, COI_RECEIVED);
            items.push({
                id: 'coi',
                label: 'Certificate of Insurance (COI)',
                complete: received,
                icon: received ? 'utility:success' : 'utility:warning',
                variant: received ? 'success' : 'warning',
                statusText: received ? 'Received' : 'Pending'
            });
        }

        // Additional Insured Endorsement
        if (getFieldValue(this.contract.data, ADDITIONAL_INSURED_REQUIRED)) {
            const received = getFieldValue(this.contract.data, ADDITIONAL_INSURED_RECEIVED);
            items.push({
                id: 'additional-insured',
                label: 'Additional Insured Endorsement',
                complete: received,
                icon: received ? 'utility:success' : 'utility:warning',
                variant: received ? 'success' : 'warning',
                statusText: received ? 'Received' : 'Pending'
            });
        }

        // ICA Approval Form
        if (getFieldValue(this.contract.data, ICA_FORM_REQUIRED)) {
            const received = getFieldValue(this.contract.data, ICA_FORM_RECEIVED);
            items.push({
                id: 'ica-form',
                label: 'ICA Approval Form',
                complete: received,
                icon: received ? 'utility:success' : 'utility:warning',
                variant: received ? 'success' : 'warning',
                statusText: received ? 'Received' : 'Pending'
            });
        }

        // Legal Review
        if (getFieldValue(this.contract.data, LEGAL_REVIEW_REQUIRED)) {
            const complete = getFieldValue(this.contract.data, LEGAL_REVIEW_COMPLETE);
            items.push({
                id: 'legal-review',
                label: 'Legal Review',
                complete: complete,
                icon: complete ? 'utility:success' : 'utility:warning',
                variant: complete ? 'success' : 'warning',
                statusText: complete ? 'Complete' : 'Pending'
            });
        }

        // Board Approval
        if (getFieldValue(this.contract.data, BOARD_APPROVAL_REQUIRED)) {
            const approved = !!getFieldValue(this.contract.data, BOARD_APPROVAL_DATE);
            items.push({
                id: 'board-approval',
                label: 'Board Approval',
                complete: approved,
                icon: approved ? 'utility:success' : 'utility:warning',
                variant: approved ? 'success' : 'warning',
                statusText: approved ? 'Approved' : 'Pending'
            });
        }

        // CFO Payment Approval (only if electronic payment)
        const paymentMethod = getFieldValue(this.contract.data, PAYMENT_METHOD);
        if (paymentMethod === 'Electronic' || paymentMethod === 'ACH' || paymentMethod === 'Wire Transfer') {
            const approved = getFieldValue(this.contract.data, CFO_PAYMENT_APPROVAL);
            items.push({
                id: 'cfo-approval',
                label: 'CFO Payment Approval',
                complete: approved,
                icon: approved ? 'utility:success' : 'utility:warning',
                variant: approved ? 'success' : 'warning',
                statusText: approved ? 'Approved' : 'Pending'
            });
        }

        return items;
    }

    get completedCount() {
        return this.complianceItems.filter(item => item.complete).length;
    }

    get totalCount() {
        return this.complianceItems.length;
    }

    get complianceScore() {
        if (this.totalCount === 0) return 100;
        return Math.round((this.completedCount / this.totalCount) * 100);
    }

    get scoreVariant() {
        const score = this.complianceScore;
        if (score === 100) return 'success';
        if (score >= 50) return 'warning';
        return 'error';
    }

    get overallIcon() {
        const score = this.complianceScore;
        if (score === 100) return 'utility:success';
        if (score >= 50) return 'utility:warning';
        return 'utility:error';
    }

    get overallIconVariant() {
        return this.scoreVariant === 'error' ? 'error' : this.scoreVariant;
    }

    get scoreLabel() {
        return `${this.completedCount} of ${this.totalCount} items complete (${this.complianceScore}%)`;
    }

    get cardTitle() {
        return 'Compliance Status';
    }

    get hasItems() {
        return this.complianceItems.length > 0;
    }

    get progressValue() {
        return this.complianceScore;
    }

    get progressVariant() {
        const score = this.complianceScore;
        if (score === 100) return '';
        if (score >= 50) return 'warning';
        return 'expired';
    }
}
