import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: Number,
    autoDismiss: Boolean
  }

  connect() {
    // Initialize Bootstrap Toast
    this.toast = new bootstrap.Toast(this.element, {
      autohide: false
    })

    // Show the toast
    this.toast.show()

    // Auto-dismiss if enabled
    if (this.autoDismissValue) {
      const delay = this.delayValue || 3000 // Default 3 seconds
      this.timeoutId = setTimeout(() => {
        this.dismiss()
      }, delay)
    }
  }

  disconnect() {
    // Clean up timeout when controller is removed
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  dismiss() {
    // Hide the toast
    if (this.toast) {
      this.toast.hide()
    }

    // Clear timeout if it exists
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  // Action for manual dismiss (close button)
  close() {
    this.dismiss()
  }
}
