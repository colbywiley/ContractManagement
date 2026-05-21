import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import STATUS from '@salesforce/schema/YGSF_Contract__c.Status__c';
import APPROVAL_PATH from '@salesforce/schema/YGSF_Contract__c.Approval_Path__c';

const FIELDS = [STATUS, APPROVAL_PATH];

const PATH_STEPS = {
    '3.2.1': [
        { label: 'Draft', value: 'Draft' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Legal Review', value: 'Legal Review' },
        { label: 'SVP Approval', value: 'SVP Approval' },
        { label: 'Officer Approval', value: 'Officer Approval' },
        { label: 'Pending Signatures', value: 'Pending Signatures' },
        { label: 'Executed', value: 'Executed' }
    ],
    '3.2.2': [
        { label: 'Draft', value: 'Draft' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Legal Review', value: 'Legal Review' },
        { label: 'SVP Approval', value: 'SVP Approval' },
        { label: 'VP Approval', value: 'VP Approval' },
        { label: 'Pending Signatures', value: 'Pending Signatures' },
        { label: 'Executed', value: 'Executed' }
    ],
    '3.2.3': [
        { label: 'Draft', value: 'Draft' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'ED Approval', value: 'ED Approval' },
        { label: 'VP Approval', value: 'VP Approval' },
        { label: 'Pending Signatures', value: 'Pending Signatures' },
        { label: 'Executed', value: 'Executed' },
        { label: 'Legal Review (After)', value: 'Legal Review (After)' }
    ],
    '3.2.4': [
        { label: 'Draft', value: 'Draft' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'ED Approval', value: 'ED Approval' },
        { label: 'Pending Signatures', value: 'Pending Signatures' },
        { label: 'Executed', value: 'Executed' }
    ]
};

const DEFAULT_STEPS = [
    { label: 'Draft', value: 'Draft' },
    { label: 'Submitted', value: 'Submitted' },
    { label: 'In Review', value: 'In Review' },
    { label: 'Pending Signatures', value: 'Pending Signatures' },
    { label: 'Executed', value: 'Executed' }
];

export default class ApprovalPathIndicator extends LightningElement {
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
            : 'An error occurred loading approval path data.';
    }

    get approvalPath() {
        if (!this.contract.data) return null;
        return getFieldValue(this.contract.data, APPROVAL_PATH);
    }

    get currentStatus() {
        if (!this.contract.data) return null;
        return getFieldValue(this.contract.data, STATUS);
    }

    get steps() {
        const path = this.approvalPath;
        if (path && PATH_STEPS[path]) {
            return PATH_STEPS[path];
        }
        return DEFAULT_STEPS;
    }

    get currentStep() {
        const status = this.currentStatus;
        if (!status) return 'Draft';

        // Map the contract status to the closest step value
        const stepValues = this.steps.map(s => s.value);
        if (stepValues.includes(status)) {
            return status;
        }

        // Map common statuses to step values
        const statusMapping = {
            'In Legal Review': 'Legal Review',
            'Legal Review In Progress': 'Legal Review',
            'Awaiting SVP Approval': 'SVP Approval',
            'Awaiting VP Approval': 'VP Approval',
            'Awaiting ED Approval': 'ED Approval',
            'Awaiting Officer Approval': 'Officer Approval',
            'Awaiting Signatures': 'Pending Signatures',
            'Active': 'Executed',
            'Expired': 'Executed',
            'Terminated': 'Executed'
        };

        return statusMapping[status] || status;
    }

    get pathLabel() {
        const path = this.approvalPath;
        if (!path) return 'Approval Path';
        return `Approval Path ${path}`;
    }

    get hasData() {
        return !!this.contract.data;
    }
}
