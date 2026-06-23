import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="info-banner"
export default class extends Controller {
  static values = {
    storageKey: String,
    autoShow: Boolean
  }

  connect() {
    if (this.autoShowValue && !this.isDismissed()) {
      this.show()
    }
  }

  show() {
    this.element.style.display = 'block'
  }

  hide() {
    this.element.style.display = 'none'
  }

  dismiss() {
    this.markAsDismissed()
    this.hide()
  }

  isDismissed() {
    return localStorage.getItem(this.storageKeyValue) === 'true'
  }

  markAsDismissed() {
    localStorage.setItem(this.storageKeyValue, 'true')
  }
}
