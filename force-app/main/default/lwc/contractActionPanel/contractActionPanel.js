import { LightningElement, api, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getActionContext from "@salesforce/apex/ContractActionPanelController.getActionContext";
import submitForReview from "@salesforce/apex/ContractActionPanelController.submitForReview";
import beginLegalReview from "@salesforce/apex/ContractActionPanelController.beginLegalReview";
import completeLegalReview from "@salesforce/apex/ContractActionPanelController.completeLegalReview";
import requestRevisions from "@salesforce/apex/ContractActionPanelController.requestRevisions";
import approveContract from "@salesforce/apex/ContractActionPanelController.approveContract";
import rejectContract from "@salesforce/apex/ContractActionPanelController.rejectContract";
import markFullyExecuted from "@salesforce/apex/ContractActionPanelController.markFullyExecuted";
import activateContract from "@salesforce/apex/ContractActionPanelController.activateContract";
import resubmitContract from "@salesforce/apex/ContractActionPanelController.resubmitContract";

import STATUS_FIELD from "@salesforce/schema/YGSF_Contract__c.Status__c";

export default class ContractActionPanel extends LightningElement {
  @api recordId;

  context;
  isLoading = true;
  isProcessing = false;
  showCommentsModal = false;
  comments = "";
  pendingAction = "";
  modalTitle = "";
  modalConfirmLabel = "";
  modalConfirmVariant = "brand";
  commentsPlaceholder = "";
  commentsRequired = false;

  _wiredContext;

  // Wire to detect record changes (status updates) and refresh
  @wire(getRecord, { recordId: "$recordId", fields: [STATUS_FIELD] })
  wiredRecord() {
    // When the record changes, refresh the action context
    if (this._wiredContext) {
      refreshApex(this._wiredContext);
    }
  }

  @wire(getActionContext, { contractId: "$recordId" })
  wiredContext(result) {
    this._wiredContext = result;
    if (result.data) {
      this.context = result.data;
      this.isLoading = false;
    } else if (result.error) {
      this.isLoading = false;
      console.error("Error loading action context:", result.error);
    }
  }

  get statusLabel() {
    if (!this.context) return "";
    return this.context.contractStatus;
  }

  get panelClass() {
    const variant = this.context?.statusVariant || "info";
    const variantMap = {
      info: "panel-info",
      warning: "panel-warning",
      success: "panel-success",
      error: "panel-error",
    };
    return `action-panel slds-box slds-theme_default ${variantMap[variant] || "panel-info"}`;
  }

  get hasActions() {
    return this.context?.actions && this.context.actions.length > 0;
  }

  get showApprovalPath() {
    return (
      this.context?.approvalPath &&
      this.context.contractStatus !== "Draft" &&
      this.context.contractStatus !== "Active" &&
      this.context.contractStatus !== "Expired"
    );
  }

  handleAction(event) {
    const actionName = event.target.dataset.action;

    // Actions that require comments modal
    if (
      actionName === "rejectContract" ||
      actionName === "requestRevisions"
    ) {
      this.pendingAction = actionName;
      if (actionName === "rejectContract") {
        this.modalTitle = "Reject Contract";
        this.modalConfirmLabel = "Reject";
        this.modalConfirmVariant = "destructive";
        this.commentsPlaceholder =
          "Please provide a reason for rejection...";
        this.commentsRequired = true;
      } else {
        this.modalTitle = "Request Revisions";
        this.modalConfirmLabel = "Send Back for Revisions";
        this.modalConfirmVariant = "destructive";
        this.commentsPlaceholder =
          "Describe what revisions are needed...";
        this.commentsRequired = true;
      }
      this.comments = "";
      this.showCommentsModal = true;
      return;
    }

    // Actions that optionally accept comments
    if (
      actionName === "approveContract" ||
      actionName === "completeLegalReview"
    ) {
      this.pendingAction = actionName;
      this.modalTitle =
        actionName === "approveContract"
          ? "Approve Contract"
          : "Complete Legal Review";
      this.modalConfirmLabel =
        actionName === "approveContract" ? "Approve" : "Complete Review";
      this.modalConfirmVariant = "success";
      this.commentsPlaceholder = "Add optional comments...";
      this.commentsRequired = false;
      this.comments = "";
      this.showCommentsModal = true;
      return;
    }

    // Direct actions (no comments needed)
    this.executeAction(actionName, "");
  }

  handleCommentsChange(event) {
    this.comments = event.target.value;
  }

  closeModal() {
    this.showCommentsModal = false;
    this.pendingAction = "";
    this.comments = "";
  }

  confirmModalAction() {
    if (this.commentsRequired && !this.comments.trim()) {
      this.showToast("Error", "Comments are required.", "error");
      return;
    }
    this.showCommentsModal = false;
    this.executeAction(this.pendingAction, this.comments);
  }

  async executeAction(actionName, comments) {
    this.isProcessing = true;

    const actionMap = {
      submitForReview: { fn: submitForReview, params: { contractId: this.recordId }, successMsg: "Contract submitted for review" },
      beginLegalReview: { fn: beginLegalReview, params: { contractId: this.recordId }, successMsg: "Legal review started" },
      completeLegalReview: { fn: completeLegalReview, params: { contractId: this.recordId, comments }, successMsg: "Legal review completed" },
      requestRevisions: { fn: requestRevisions, params: { contractId: this.recordId, comments }, successMsg: "Contract returned for revisions" },
      approveContract: { fn: approveContract, params: { contractId: this.recordId, comments }, successMsg: "Contract approved" },
      rejectContract: { fn: rejectContract, params: { contractId: this.recordId, comments }, successMsg: "Contract rejected" },
      markFullyExecuted: { fn: markFullyExecuted, params: { contractId: this.recordId }, successMsg: "Contract marked as fully executed" },
      activateContract: { fn: activateContract, params: { contractId: this.recordId }, successMsg: "Contract activated" },
      resubmitContract: { fn: resubmitContract, params: { contractId: this.recordId }, successMsg: "Contract resubmitted for review" },
    };

    const action = actionMap[actionName];
    if (!action) {
      this.isProcessing = false;
      return;
    }

    try {
      await action.fn(action.params);
      this.showToast("Success", action.successMsg, "success");
      await refreshApex(this._wiredContext);
      // Force record page refresh
      eval("$A.get('e.force:refreshView').fire()");
    } catch (error) {
      const errorMsg = this.extractErrorMessage(error);
      this.showToast("Error", errorMsg, "error");
    } finally {
      this.isProcessing = false;
      this.pendingAction = "";
      this.comments = "";
    }
  }

  extractErrorMessage(error) {
    if (!error) return "An unknown error occurred.";
    // Apex @AuraEnabled errors
    if (error.body) {
      if (error.body.message) return error.body.message;
      if (error.body.output && error.body.output.errors) {
        return error.body.output.errors.map((e) => e.message).join("; ");
      }
      if (error.body.fieldErrors) {
        const msgs = [];
        for (const field in error.body.fieldErrors) {
          error.body.fieldErrors[field].forEach((e) => msgs.push(e.message));
        }
        return msgs.join("; ");
      }
      if (error.body.pageErrors) {
        return error.body.pageErrors.map((e) => e.message).join("; ");
      }
    }
    // Standard JS error
    if (error.message) return error.message;
    // Array of errors
    if (Array.isArray(error)) {
      return error.map((e) => e.message || JSON.stringify(e)).join("; ");
    }
    return JSON.stringify(error);
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({ title, message, variant })
    );
  }
}
