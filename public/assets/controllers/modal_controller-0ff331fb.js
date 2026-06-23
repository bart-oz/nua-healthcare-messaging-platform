import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["form"]
  static values = { retryUrl: String }

  connect() {
    // Initialize Bootstrap Modal
    this.modal = new bootstrap.Modal(this.element, {
      backdrop: false // matches the current data-bs-backdrop="false"
    })

    // Listen for successful form submission
    this.element.addEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))

    // Listen for Bootstrap modal show event to update form action
    this.element.addEventListener('show.bs.modal', this.handleModalShow.bind(this))
  }

  disconnect() {
    // Clean up event listeners
    this.element.removeEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))
    this.element.removeEventListener('show.bs.modal', this.handleModalShow.bind(this))

    // Dispose of the modal instance
    if (this.modal) {
      this.modal.dispose()
    }
  }

  // Action to show the modal
  show() {
    this.modal.show()
  }

  // Action to set retry URL and show modal
  showRetry(event) {
    const retryUrl = event.params.url
    this.retryUrlValue = retryUrl

    // Update the form action if we have a form
    if (this.hasFormTarget && retryUrl) {
      this.formTarget.action = retryUrl
    }

    this.show()
  }

  // Static method to show retry modal from anywhere
  static showRetryModal(retryUrl) {
    const modal = document.querySelector('#retryConfirmationModal')
    if (modal) {
      const controller = modal.stimulus?.controller
      if (controller) {
        const form = modal.querySelector('form')
        if (form) {
          form.action = retryUrl
        }
        controller.show()
      }
    }
  }

  // Action to hide the modal
  hide() {
    this.modal.hide()
  }

  // Handle form submission results
  handleSubmitEnd(event) {
    const { success } = event.detail

    // If the form submission was successful, hide the modal
    if (success) {
      this.hide()

      // Reset the form for next use
      if (this.hasFormTarget) {
        this.formTarget.reset()
      }
    }
  }

  // Handle modal show event - update form action based on trigger button
  handleModalShow(event) {
    const triggerButton = event.relatedTarget // Button that triggered the modal
    if (triggerButton && triggerButton.dataset.retryUrl) {
      const retryUrl = triggerButton.dataset.retryUrl

      // Update the form action if we have a form
      if (this.hasFormTarget) {
        this.formTarget.action = retryUrl
      }
    }
  }

  // Action to reset modal state (useful for cleanup)
  reset() {
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
  }
}
