import { Controller } from "@hotwired/stimulus"

// The badge celebration overlay: close on the button, Escape or a backdrop click.
export default class extends Controller {
  connect() {
    this.onKey = e => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
    this.element.addEventListener("click", e => { if (e.target === this.element) this.close() })
    this.element.querySelector("button")?.focus()
  }

  disconnect() { document.removeEventListener("keydown", this.onKey) }

  close() {
    this.element.classList.add("is-leaving")
    setTimeout(() => this.element.remove(), 200)
  }
}
