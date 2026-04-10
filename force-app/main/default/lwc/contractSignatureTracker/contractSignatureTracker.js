import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSignatories from '@salesforce/apex/ContractSignatoryController.getSignatories';
import markAsSigned from '@salesforce/apex/ContractSignatoryController.markAsSigned';

const COLUMNS = [
    {
        label: 'Status',
        fieldName: 'signedIcon',
        type: 'text',
        cellAttributes: {
            iconName: { fieldName: 'statusIcon' },
            iconPosition: 'left',
            iconAlternativeText: { fieldName: 'statusText' }
        },
        initialWidth: 90
    },
    { label: 'Signatory Name', fieldName: 'signatoryName', type: 'text' },
    { label: 'Role', fieldName: 'signatoryRole', type: 'text' },
    {
        label: 'Required',
        fieldName: 'required',
        type: 'boolean',
        initialWidth: 100
    },
    {
        label: 'Signed',
        fieldName: 'signed',
        type: 'boolean',
        initialWidth: 90
    },
    {
        label: 'Signed Date',
        fieldName: 'signedDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit'
        }
    },
    { label: 'Delegated From', fieldName: 'delegatedFromName', type: 'text' },
    {
        label: 'Order',
        fieldName: 'signatureOrder',
        type: 'number',
        initialWidth: 80
    },
    {
        type: 'action',
        typeAttributes: { rowActions: { fieldName: 'availableActions' } }
    }
];

export default class ContractSignatureTracker extends LightningElement {
    @api recordId;

    columns = COLUMNS;
    signatoryData = [];
    isLoading = true;

    _wiredSignatories;

    @wire(getSignatories, { contractId: '$recordId' })
    wiredSignatories(result) {
        this._wiredSignatories = result;
        const { data, error } = result;
        this.isLoading = false;

        if (data) {
            this.signatoryData = data.map(sig => {
                const isSigned = sig.Signed__c;
                const actions = [];
                if (!isSigned) {
                    actions.push({ label: 'Mark as Signed', name: 'mark_signed' });
                }
                return {
                    id: sig.Id,
                    signatoryName: sig.Signatory__r ? sig.Signatory__r.Name : sig.Name,
                    signatoryRole: sig.Signatory_Role__c,
                    required: sig.Required__c,
                    signed: sig.Signed__c,
                    signedDate: sig.Signed_Date__c,
                    delegatedFromName: sig.Delegated_From__r ? sig.Delegated_From__r.Name : '',
                    signatureOrder: sig.Signature_Order__c,
                    statusIcon: isSigned ? 'utility:success' : 'utility:clock',
                    statusText: isSigned ? 'Signed' : 'Awaiting Signature',
                    signedIcon: isSigned ? 'Signed' : 'Pending',
                    availableActions: actions
                };
            });
        } else if (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
            this.signatoryData = [];
        }
    }

    get hasSignatories() {
        return this.signatoryData.length > 0;
    }

    get signedCount() {
        return this.signatoryData.filter(s => s.signed).length;
    }

    get totalCount() {
        return this.signatoryData.length;
    }

    get signatureProgress() {
        return `${this.signedCount} of ${this.totalCount} signatures collected`;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'mark_signed') {
            this.handleMarkAsSigned(row.id);
        }
    }

    async handleMarkAsSigned(signatoryId) {
        this.isLoading = true;
        try {
            await markAsSigned({ signatoryId: signatoryId });
            this.showToast('Success', 'Signatory marked as signed.', 'success');
            await refreshApex(this._wiredSignatories);
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredSignatories).finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}
