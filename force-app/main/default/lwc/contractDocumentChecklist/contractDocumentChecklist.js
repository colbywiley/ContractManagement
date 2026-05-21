import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocuments from '@salesforce/apex/ContractDocumentController.getDocuments';
import createDocument from '@salesforce/apex/ContractDocumentController.createDocument';

import COI_REQUIRED from '@salesforce/schema/YGSF_Contract__c.COI_Required__c';
import COI_RECEIVED from '@salesforce/schema/YGSF_Contract__c.COI_Received__c';
import ADDITIONAL_INSURED_REQUIRED from '@salesforce/schema/YGSF_Contract__c.Additional_Insured_Required__c';
import ADDITIONAL_INSURED_RECEIVED from '@salesforce/schema/YGSF_Contract__c.Additional_Insured_Received__c';
import ICA_FORM_REQUIRED from '@salesforce/schema/YGSF_Contract__c.ICA_Approval_Form_Required__c';
import ICA_FORM_RECEIVED from '@salesforce/schema/YGSF_Contract__c.ICA_Approval_Form_Received__c';

const CONTRACT_FIELDS = [
    COI_REQUIRED, COI_RECEIVED,
    ADDITIONAL_INSURED_REQUIRED, ADDITIONAL_INSURED_RECEIVED,
    ICA_FORM_REQUIRED, ICA_FORM_RECEIVED
];

const DOCUMENT_COLUMNS = [
    {
        label: 'Status',
        fieldName: 'statusText',
        type: 'text',
        cellAttributes: {
            iconName: { fieldName: 'statusIcon' },
            iconPosition: 'left'
        },
        initialWidth: 120
    },
    { label: 'Document Type', fieldName: 'documentType', type: 'text' },
    { label: 'File Name', fieldName: 'fileName', type: 'text' },
    {
        label: 'Upload Date',
        fieldName: 'uploadDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' }
    },
    {
        label: 'Expiration Date',
        fieldName: 'expirationDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' }
    },
    { label: 'Record Status', fieldName: 'status', type: 'text' }
];

export default class ContractDocumentChecklist extends LightningElement {
    @api recordId;

    columns = DOCUMENT_COLUMNS;
    documentData = [];
    isLoading = true;
    showUploadModal = false;
    selectedDocumentType = '';

    _wiredDocuments;
    _wiredContract;

    documentTypeOptions = [
        { label: 'Certificate of Insurance (COI)', value: 'COI' },
        { label: 'Additional Insured Endorsement', value: 'Additional Insured Endorsement' },
        { label: 'ICA Approval Form', value: 'ICA Approval Form' },
        { label: 'Executed Contract', value: 'Executed Contract' },
        { label: 'Amendment', value: 'Amendment' },
        { label: 'Supporting Document', value: 'Supporting Document' },
        { label: 'Other', value: 'Other' }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: CONTRACT_FIELDS })
    wiredContract(result) {
        this._wiredContract = result;
    }

    @wire(getDocuments, { contractId: '$recordId' })
    wiredDocuments(result) {
        this._wiredDocuments = result;
        const { data, error } = result;
        this.isLoading = false;

        if (data) {
            this.documentData = data.map(doc => ({
                id: doc.Id,
                documentType: doc.Document_Type__c,
                fileName: doc.File_Name__c || doc.Name,
                uploadDate: doc.Upload_Date__c,
                expirationDate: doc.Expiration_Date__c,
                status: doc.Status__c,
                contentDocumentId: doc.ContentDocumentId__c,
                statusIcon: doc.Status__c === 'Current' ? 'utility:success' : 'utility:warning',
                statusText: doc.Status__c || 'Unknown'
            }));
        } else if (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
            this.documentData = [];
        }
    }

    get contractData() {
        return this._wiredContract ? this._wiredContract.data : null;
    }

    get requiredDocuments() {
        if (!this.contractData) return [];
        const items = [];

        if (getFieldValue(this.contractData, COI_REQUIRED)) {
            const received = getFieldValue(this.contractData, COI_RECEIVED);
            const uploaded = this.documentData.some(d => d.documentType === 'COI');
            items.push({
                id: 'coi',
                label: 'Certificate of Insurance (COI)',
                required: true,
                received: received,
                uploaded: uploaded,
                icon: received || uploaded ? 'utility:success' : 'utility:warning',
                variant: received || uploaded ? 'success' : 'warning',
                statusText: received ? 'Received' : uploaded ? 'Uploaded' : 'Missing',
                docType: 'COI'
            });
        }

        if (getFieldValue(this.contractData, ADDITIONAL_INSURED_REQUIRED)) {
            const received = getFieldValue(this.contractData, ADDITIONAL_INSURED_RECEIVED);
            const uploaded = this.documentData.some(d => d.documentType === 'Additional Insured Endorsement');
            items.push({
                id: 'additional-insured',
                label: 'Additional Insured Endorsement',
                required: true,
                received: received,
                uploaded: uploaded,
                icon: received || uploaded ? 'utility:success' : 'utility:warning',
                variant: received || uploaded ? 'success' : 'warning',
                statusText: received ? 'Received' : uploaded ? 'Uploaded' : 'Missing',
                docType: 'Additional Insured Endorsement'
            });
        }

        if (getFieldValue(this.contractData, ICA_FORM_REQUIRED)) {
            const received = getFieldValue(this.contractData, ICA_FORM_RECEIVED);
            const uploaded = this.documentData.some(d => d.documentType === 'ICA Approval Form');
            items.push({
                id: 'ica-form',
                label: 'ICA Approval Form',
                required: true,
                received: received,
                uploaded: uploaded,
                icon: received || uploaded ? 'utility:success' : 'utility:warning',
                variant: received || uploaded ? 'success' : 'warning',
                statusText: received ? 'Received' : uploaded ? 'Uploaded' : 'Missing',
                docType: 'ICA Approval Form'
            });
        }

        return items;
    }

    get hasRequiredDocuments() {
        return this.requiredDocuments.length > 0;
    }

    get hasUploadedDocuments() {
        return this.documentData.length > 0;
    }

    get receivedCount() {
        return this.requiredDocuments.filter(d => d.received || d.uploaded).length;
    }

    get requiredCount() {
        return this.requiredDocuments.length;
    }

    get checklistSummary() {
        if (this.requiredCount === 0) return 'No required documents for this contract.';
        return `${this.receivedCount} of ${this.requiredCount} required documents received`;
    }

    get acceptedFormats() {
        return ['.pdf', '.doc', '.docx', '.png', '.jpg', '.jpeg', '.xls', '.xlsx'];
    }

    handleOpenUpload() {
        this.showUploadModal = true;
    }

    handleCloseUpload() {
        this.showUploadModal = false;
        this.selectedDocumentType = '';
    }

    handleDocumentTypeChange(event) {
        this.selectedDocumentType = event.detail.value;
    }

    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;

        if (!this.selectedDocumentType) {
            this.showToast('Warning', 'Please select a document type before uploading.', 'warning');
            return;
        }

        try {
            for (const file of uploadedFiles) {
                await createDocument({
                    contractId: this.recordId,
                    docType: this.selectedDocumentType,
                    fileName: file.name,
                    contentDocId: file.documentId
                });
            }

            this.showToast('Success', `${uploadedFiles.length} document(s) uploaded successfully.`, 'success');
            this.handleCloseUpload();
            await refreshApex(this._wiredDocuments);
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this._wiredDocuments),
            refreshApex(this._wiredContract)
        ]).finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }
}
