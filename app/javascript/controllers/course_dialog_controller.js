import { Controller } from "@hotwired/stimulus"

// The full course list, drawn over the page. The link that opens it goes to
// the same list as a page when JavaScript is off.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    if (!this.hasDialogTarget || !this.dialogTarget.showModal) return
    event.preventDefault()
    this.opener = event.currentTarget
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
    this.opener?.focus()
  }

  // A click on the dimmed page around the list closes it.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  // Turbo keeps a copy of the page for the Back button; an open list shouldn't be in it.
  disconnect() {
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
  }
}
