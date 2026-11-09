import { Controller } from "@hotwired/stimulus"

// Clears the tutor box after a send and keeps the chat scrolled to the newest message.
export default class extends Controller {
  connect() {
    this.log = document.getElementById("tutor-log")
    if (!this.log) return
    this.scroll()
    this.observer = new MutationObserver(() => this.scroll())
    this.observer.observe(this.log, { childList: true, subtree: true })
  }

  disconnect() { this.observer?.disconnect() }

  reset(event) {
    if (event.detail.success) this.element.reset()
  }

  scroll() { this.log.scrollTop = this.log.scrollHeight }
}
