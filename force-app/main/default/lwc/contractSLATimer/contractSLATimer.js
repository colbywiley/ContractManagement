import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import SUBMISSION_DATE from '@salesforce/schema/YGSF_Contract__c.Submission_Date__c';
import LEGAL_ACKNOWLEDGMENT_DATE from '@salesforce/schema/YGSF_Contract__c.Legal_Acknowledgment_Date__c';
import LEGAL_REVIEW_DATE from '@salesforce/schema/YGSF_Contract__c.Legal_Review_Date__c';
import STATUS from '@salesforce/schema/YGSF_Contract__c.Status__c';
import SLA_STATUS from '@salesforce/schema/YGSF_Contract__c.SLA_Status__c';
import LEGAL_REVIEW_REQUIRED from '@salesforce/schema/YGSF_Contract__c.Legal_Review_Required__c';
import EXECUTION_DATE from '@salesforce/schema/YGSF_Contract__c.Execution_Date__c';

const FIELDS = [
    SUBMISSION_DATE, LEGAL_ACKNOWLEDGMENT_DATE, LEGAL_REVIEW_DATE,
    STATUS, SLA_STATUS, LEGAL_REVIEW_REQUIRED, EXECUTION_DATE
];

const MS_PER_HOUR = 1000 * 60 * 60;
const MS_PER_DAY = MS_PER_HOUR * 24;
const BUSINESS_HOURS_PER_DAY = 8;

export default class ContractSLATimer extends LightningElement {
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
            : 'An error occurred loading SLA data.';
    }

    get hasData() {
        return !!this.contract.data;
    }

    get submissionDate() {
        return getFieldValue(this.contract.data, SUBMISSION_DATE);
    }

    get legalAcknowledgmentDate() {
        return getFieldValue(this.contract.data, LEGAL_ACKNOWLEDGMENT_DATE);
    }

    get legalReviewDate() {
        return getFieldValue(this.contract.data, LEGAL_REVIEW_DATE);
    }

    get status() {
        return getFieldValue(this.contract.data, STATUS);
    }

    get slaStatus() {
        return getFieldValue(this.contract.data, SLA_STATUS);
    }

    get legalReviewRequired() {
        return getFieldValue(this.contract.data, LEGAL_REVIEW_REQUIRED);
    }

    get executionDate() {
        return getFieldValue(this.contract.data, EXECUTION_DATE);
    }

    get isSubmitted() {
        return !!this.submissionDate;
    }

    get isExecuted() {
        const s = this.status;
        return s === 'Executed' || s === 'Active' || s === 'Expired' || s === 'Terminated';
    }

    get slaTimers() {
        if (!this.contract.data || !this.isSubmitted) return [];
        const timers = [];

        // SLA 1: Legal Acknowledgment - 1 business day from submission
        if (this.legalReviewRequired) {
            timers.push(this.buildTimer(
                'legal-ack',
                'Legal Acknowledgment',
                '1 business day from submission',
                this.submissionDate,
                1,
                this.legalAcknowledgmentDate
            ));
        }

        // SLA 2: Legal Review Completion - 5 business days from submission
        if (this.legalReviewRequired) {
            timers.push(this.buildTimer(
                'legal-review',
                'Legal Review Completion',
                '5 business days from submission',
                this.submissionDate,
                5,
                this.legalReviewDate
            ));
        }

        // SLA 3: Signatory Turnaround - 1 business day from approval/pending signatures
        if (this.status === 'Pending Signatures' || this.status === 'Awaiting Signatures') {
            timers.push(this.buildTimer(
                'sig-turnaround',
                'Signature Turnaround',
                '1 business day from approval',
                this.getApprovalDate(),
                1,
                this.executionDate
            ));
        }

        return timers;
    }

    get hasTimers() {
        return this.slaTimers.length > 0;
    }

    get overallSlaStatus() {
        if (this.slaStatus) return this.slaStatus;
        if (!this.hasTimers) return 'N/A';
        const breached = this.slaTimers.some(t => t.statusClass === 'breached');
        if (breached) return 'Breached';
        const approaching = this.slaTimers.some(t => t.statusClass === 'approaching');
        if (approaching) return 'At Risk';
        return 'On Track';
    }

    get overallStatusIcon() {
        const s = this.overallSlaStatus;
        if (s === 'On Track') return 'utility:success';
        if (s === 'At Risk') return 'utility:warning';
        if (s === 'Breached') return 'utility:error';
        return 'utility:info';
    }

    get overallStatusVariant() {
        const s = this.overallSlaStatus;
        if (s === 'On Track') return 'success';
        if (s === 'At Risk') return 'warning';
        if (s === 'Breached') return 'error';
        return '';
    }

    buildTimer(id, label, slaRule, startDateStr, businessDays, completedDateStr) {
        const now = new Date();
        const startDate = startDateStr ? this.parseDateAsLocal(startDateStr) : null;
        const completedDate = completedDateStr ? this.parseDateAsLocal(completedDateStr) : null;
        const deadline = startDate ? this.addBusinessDays(startDate, businessDays) : null;

        let statusClass = 'on-track';
        let statusLabel = 'On Track';
        let remainingText = '';
        let icon = 'utility:success';
        let variant = 'success';
        let progressValue = 0;

        if (completedDate) {
            // SLA was met or breached (already completed)
            if (deadline && completedDate <= deadline) {
                statusClass = 'completed';
                statusLabel = 'Met';
                icon = 'utility:success';
                variant = 'success';
                remainingText = 'Completed on time';
                progressValue = 100;
            } else {
                statusClass = 'breached';
                statusLabel = 'Breached (Late)';
                icon = 'utility:error';
                variant = 'error';
                remainingText = 'Completed late';
                progressValue = 100;
            }
        } else if (deadline) {
            // Still in progress
            const remaining = deadline.getTime() - now.getTime();
            const total = deadline.getTime() - startDate.getTime();
            const elapsed = now.getTime() - startDate.getTime();

            if (remaining < 0) {
                // Breached
                const overdueDays = Math.ceil(Math.abs(remaining) / MS_PER_DAY);
                statusClass = 'breached';
                statusLabel = 'Breached';
                icon = 'utility:error';
                variant = 'error';
                remainingText = `Overdue by ${overdueDays} day${overdueDays !== 1 ? 's' : ''}`;
                progressValue = 100;
            } else {
                const remainingHours = Math.ceil(remaining / MS_PER_HOUR);
                const remainingDays = Math.floor(remaining / MS_PER_DAY);
                progressValue = total > 0 ? Math.round((elapsed / total) * 100) : 0;

                // Approaching = less than 25% time remaining
                const approachingThreshold = total * 0.25;
                if (remaining <= approachingThreshold) {
                    statusClass = 'approaching';
                    statusLabel = 'At Risk';
                    icon = 'utility:warning';
                    variant = 'warning';
                } else {
                    statusClass = 'on-track';
                    statusLabel = 'On Track';
                    icon = 'utility:success';
                    variant = 'success';
                }

                if (remainingDays > 0) {
                    remainingText = `${remainingDays} day${remainingDays !== 1 ? 's' : ''}, ${remainingHours % 24} hour${(remainingHours % 24) !== 1 ? 's' : ''} remaining`;
                } else {
                    remainingText = `${remainingHours} hour${remainingHours !== 1 ? 's' : ''} remaining`;
                }
            }
        } else {
            statusClass = 'unknown';
            statusLabel = 'Unknown';
            icon = 'utility:info';
            variant = '';
            remainingText = 'Start date not available';
            progressValue = 0;
        }

        const deadlineFormatted = deadline
            ? deadline.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
            : 'N/A';

        return {
            id,
            label,
            slaRule,
            statusClass,
            statusLabel,
            icon,
            variant,
            remainingText,
            deadlineFormatted,
            progressValue,
            timerClass: `timer-card ${statusClass}`
        };
    }

    /**
     * Parses a date string (YYYY-MM-DD) as a local timezone date at 8 AM (start of business).
     * Salesforce Date fields have no time component and are returned as YYYY-MM-DD strings.
     * Using new Date("YYYY-MM-DD") parses as UTC midnight, which shifts the day in western
     * timezones. This method ensures the date is treated as the local business day start.
     */
    parseDateAsLocal(dateStr) {
        if (!dateStr) return null;
        const parts = dateStr.split('-');
        if (parts.length === 3) {
            return new Date(
                parseInt(parts[0], 10),
                parseInt(parts[1], 10) - 1,
                parseInt(parts[2], 10),
                8, 0, 0, 0
            );
        }
        return new Date(dateStr);
    }

    addBusinessDays(startDate, numDays) {
        const result = new Date(startDate);
        let added = 0;
        while (added < numDays) {
            result.setDate(result.getDate() + 1);
            const dayOfWeek = result.getDay();
            // Skip weekends (0 = Sunday, 6 = Saturday)
            if (dayOfWeek !== 0 && dayOfWeek !== 6) {
                added++;
            }
        }
        // Set to end of business day (5 PM)
        result.setHours(17, 0, 0, 0);
        return result;
    }

    getApprovalDate() {
        // Use submission date as fallback for approval date calculation
        // In a real scenario, you might have an explicit approval_date field
        return this.submissionDate;
    }

    get showNoTimersMessage() {
        return !this.hasTimers && !this.isExecuted && this.hasData;
    }

    get showExecutedMessage() {
        return this.isExecuted && this.hasData;
    }

    get showNotSubmittedMessage() {
        return !this.isSubmitted && !this.isExecuted && this.hasData;
    }
}
