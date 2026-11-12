import { Controller } from "@hotwired/stimulus"

// A "Details" link that opens the box it controls instead of leaving the page.
// Without JavaScript the link still works: it goes to the full page.
export default class extends Controller {
  toggle(event) {
    const toggle = event.currentTarget
    const box = document.getElementById(toggle.getAttribute("aria-controls"))
    if (!box) return
    event.preventDefault()
    const open = toggle.getAttribute("aria-expanded") !== "true"
    toggle.setAttribute("aria-expanded", open)
    box.hidden = !open
  }

  // A link with role=button answers the space bar as a button does.
  key(event) {
    if (event.key === " ") this.toggle(event)
  }
}
