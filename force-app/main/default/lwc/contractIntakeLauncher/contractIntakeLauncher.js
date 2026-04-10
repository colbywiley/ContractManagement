import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ContractIntakeLauncher extends NavigationMixin(LightningElement) {
    @api recordId;

    isFlowOpen = false;
    isNavigating = false;

    get flowInputVariables() {
        const variables = [];
        if (this.recordId) {
            variables.push({
                name: 'recordId',
                type: 'String',
                value: this.recordId
            });
        }
        return variables;
    }

    get buttonLabel() {
        return this.recordId ? 'Edit via Intake Form' : 'New Contract Intake';
    }

    get buttonIcon() {
        return this.recordId ? 'utility:edit' : 'utility:add';
    }

    get cardTitle() {
        return this.recordId ? 'Contract Intake' : 'Start New Contract';
    }

    get cardDescription() {
        return this.recordId
            ? 'Launch the contract intake form to update this contract.'
            : 'Launch the guided contract intake process to create a new contract request.';
    }

    handleLaunchFlow() {
        this.isFlowOpen = true;
    }

    handleNavigateToFlow() {
        this.isNavigating = true;

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: this.recordId
                    ? `/flow/Contract_Intake_Flow?recordId=${this.recordId}`
                    : '/flow/Contract_Intake_Flow'
            }
        }).catch(error => {
            this.showToast('Navigation Error', 'Unable to navigate to the intake flow. Please contact your administrator.', 'error');
            console.error('Navigation error:', error);
        }).finally(() => {
            this.isNavigating = false;
        });
    }

    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED' || event.detail.status === 'FINISHED_SCREEN') {
            this.isFlowOpen = false;
            this.showToast('Success', 'Contract intake completed successfully.', 'success');

            // Navigate to the created/updated record if available
            const outputVariables = event.detail.outputVariables;
            if (outputVariables) {
                const createdRecordId = outputVariables.find(v => v.name === 'recordId' || v.name === 'contractId');
                if (createdRecordId && createdRecordId.value) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: createdRecordId.value,
                            objectApiName: 'YGSF_Contract__c',
                            actionName: 'view'
                        }
                    });
                }
            }
        } else if (event.detail.status === 'ERROR') {
            this.showToast('Error', 'An error occurred during the intake process.', 'error');
            this.isFlowOpen = false;
        }
    }

    handleCloseFlow() {
        this.isFlowOpen = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
