import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import END_DATE from '@salesforce/schema/YGSF_Contract__c.End_Date__c';
import START_DATE from '@salesforce/schema/YGSF_Contract__c.Start_Date__c';
import AUTO_RENEW from '@salesforce/schema/YGSF_Contract__c.Auto_Renew__c';
import RENEWAL_DATE from '@salesforce/schema/YGSF_Contract__c.Renewal_Date__c';
import RENEWAL_TERM_MONTHS from '@salesforce/schema/YGSF_Contract__c.Renewal_Term_Months__c';
import STATUS from '@salesforce/schema/YGSF_Contract__c.Status__c';
import CONTRACT_TITLE from '@salesforce/schema/YGSF_Contract__c.Contract_Title__c';
import COUNTERPARTY_NAME from '@salesforce/schema/YGSF_Contract__c.Counterparty_Name__c';

const FIELDS = [
    END_DATE, START_DATE, AUTO_RENEW, RENEWAL_DATE,
    RENEWAL_TERM_MONTHS, STATUS, CONTRACT_TITLE, COUNTERPARTY_NAME
];

const MS_PER_DAY = 1000 * 60 * 60 * 24;

export default class ContractRenewalManager extends NavigationMixin(LightningElement) {
    @api recordId;

    isProcessing = false;

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
            : 'An error occurred loading renewal data.';
    }

    get hasData() {
        return !!this.contract.data;
    }

    get contractTitle() {
        return getFieldValue(this.contract.data, CONTRACT_TITLE) || 'Untitled Contract';
    }

    get counterpartyName() {
        return getFieldValue(this.contract.data, COUNTERPARTY_NAME) || 'N/A';
    }

    get endDate() {
        return getFieldValue(this.contract.data, END_DATE);
    }

    get startDate() {
        return getFieldValue(this.contract.data, START_DATE);
    }

    get autoRenew() {
        return !!getFieldValue(this.contract.data, AUTO_RENEW);
    }

    get renewalDate() {
        return getFieldValue(this.contract.data, RENEWAL_DATE);
    }

    get renewalTermMonths() {
        return getFieldValue(this.contract.data, RENEWAL_TERM_MONTHS);
    }

    get status() {
        return getFieldValue(this.contract.data, STATUS);
    }

    get endDateFormatted() {
        if (!this.endDate) return 'No end date set';
        return new Date(this.endDate).toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    get renewalDateFormatted() {
        if (!this.renewalDate) return 'N/A';
        return new Date(this.renewalDate).toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    get daysUntilExpiry() {
        if (!this.endDate) return null;
        const end = new Date(this.endDate);
        const now = new Date();
        now.setHours(0, 0, 0, 0);
        end.setHours(0, 0, 0, 0);
        return Math.ceil((end.getTime() - now.getTime()) / MS_PER_DAY);
    }

    get daysUntilExpiryText() {
        const days = this.daysUntilExpiry;
        if (days === null) return 'No end date';
        if (days < 0) return `Expired ${Math.abs(days)} day${Math.abs(days) !== 1 ? 's' : ''} ago`;
        if (days === 0) return 'Expires today';
        return `${days} day${days !== 1 ? 's' : ''} until expiration`;
    }

    get expiryIcon() {
        const days = this.daysUntilExpiry;
        if (days === null) return 'utility:info';
        if (days < 0) return 'utility:error';
        if (days <= 30) return 'utility:warning';
        if (days <= 90) return 'utility:info';
        return 'utility:success';
    }

    get expiryVariant() {
        const days = this.daysUntilExpiry;
        if (days === null) return '';
        if (days < 0) return 'error';
        if (days <= 30) return 'warning';
        if (days <= 90) return 'warning';
        return 'success';
    }

    get expiryStatusClass() {
        const days = this.daysUntilExpiry;
        if (days === null) return 'expiry-unknown';
        if (days < 0) return 'expiry-expired';
        if (days <= 30) return 'expiry-critical';
        if (days <= 90) return 'expiry-approaching';
        return 'expiry-safe';
    }

    get autoRenewLabel() {
        return this.autoRenew ? 'Yes' : 'No';
    }

    get autoRenewIcon() {
        return this.autoRenew ? 'utility:success' : 'utility:close';
    }

    get autoRenewVariant() {
        return this.autoRenew ? 'success' : '';
    }

    get renewalTermLabel() {
        const months = this.renewalTermMonths;
        if (!months) return 'N/A';
        return `${months} month${months !== 1 ? 's' : ''}`;
    }

    get contractDurationLabel() {
        if (!this.startDate || !this.endDate) return 'N/A';
        const start = new Date(this.startDate);
        const end = new Date(this.endDate);
        const months = (end.getFullYear() - start.getFullYear()) * 12 + (end.getMonth() - start.getMonth());
        if (months <= 0) return 'Less than 1 month';
        return `${months} month${months !== 1 ? 's' : ''}`;
    }

    get isExpired() {
        return this.status === 'Expired' || (this.daysUntilExpiry !== null && this.daysUntilExpiry < 0);
    }

    get isActive() {
        return this.status === 'Active' || this.status === 'Executed';
    }

    get canCreateRenewal() {
        return this.isActive || this.isExpired;
    }

    get renewalButtonLabel() {
        return this.isExpired ? 'Create Renewal (Expired)' : 'Create Renewal';
    }

    get renewalButtonVariant() {
        return this.isExpired ? 'destructive' : 'brand';
    }

    get showRenewalAlert() {
        const days = this.daysUntilExpiry;
        return days !== null && days <= 90 && days >= 0;
    }

    get renewalAlertMessage() {
        const days = this.daysUntilExpiry;
        if (days <= 30) {
            return `This contract expires in ${days} day${days !== 1 ? 's' : ''}. Immediate action is recommended.`;
        }
        return `This contract expires in ${days} day${days !== 1 ? 's' : ''}. Consider initiating the renewal process.`;
    }

    get renewalAlertVariant() {
        const days = this.daysUntilExpiry;
        if (days <= 30) return 'error';
        return 'warning';
    }

    get renewalAlertIcon() {
        const days = this.daysUntilExpiry;
        if (days <= 30) return 'utility:error';
        return 'utility:warning';
    }

    handleCreateRenewal() {
        this.isProcessing = true;

        // Navigate to the Contract Intake Flow with renewal context
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/flow/Contract_Intake_Flow?contractId=${this.recordId}&isRenewal=true`
            }
        }).catch(() => {
            // Fallback: navigate to new record page pre-populated with renewal data
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'YGSF_Contract__c',
                    actionName: 'new'
                },
                state: {
                    defaultFieldValues: `Contract_Title__c=${encodeURIComponent('Renewal: ' + this.contractTitle)}`
                }
            });
        }).finally(() => {
            this.isProcessing = false;
        });
    }

    handleViewHistory() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'YGSF_Contract__c',
                relationshipApiName: 'YGSF_Contract__c',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
