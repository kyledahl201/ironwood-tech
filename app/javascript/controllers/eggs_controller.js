import { Controller } from "@hotwired/stimulus"
import { toast, celebrate, postJSON, pick } from "lib/ui"

// Easter eggs (Office of Communications, 04-sentry-easter-eggs.md).
// The Konami code earns a hidden badge; seven quick clicks on the crest wake Sentry.
const KONAMI = ["ArrowUp", "ArrowUp", "ArrowDown", "ArrowDown", "ArrowLeft", "ArrowRight", "ArrowLeft", "ArrowRight", "b", "a"]

export default class extends Controller {
  static values = { url: String, lines: Array, sentry: String }

  connect() {
    this.keys = []
    this.onKey = this.key.bind(this)
    document.addEventListener("keydown", this.onKey)
    if (!window.__iwHello) {
      window.__iwHello = true
      console.log("%cSentry is watching. 🦉", "font: 600 14px system-ui; color: #B87333")
      console.log("Curious how this works? Good. Curiosity is the whole curriculum.")
    }
  }

  disconnect() { document.removeEventListener("keydown", this.onKey) }

  key(event) {
    if (event.target.closest?.("input, textarea, [contenteditable], .cm-editor")) return
    this.keys.push(event.key.length === 1 ? event.key.toLowerCase() : event.key)
    this.keys = this.keys.slice(-KONAMI.length)
    if (this.keys.join() === KONAMI.join()) {
      this.keys = []
      this.konami()
    }
  }

  async konami() {
    document.body.classList.add("is-konami")
    setTimeout(() => document.body.classList.remove("is-konami"), 2400)
    toast("Up, up, down, down... you've done this before.", { tone: "egg" })
    if (!this.urlValue) return
    try {
      const data = await postJSON(this.urlValue, {})
      celebrate(data.badges)
    } catch (_) { /* not signed in or offline: the toast is enough */ }
  }

  crestClick(event) {
    const now = Date.now()
    // Kept on window: each click on the crest is a Turbo visit that swaps <body>.
    const clicks = (window.__iwCrestClicks || []).filter(t => now - t < 4000)
    clicks.push(now)
    window.__iwCrestClicks = clicks
    if (clicks.length >= 2) event.preventDefault()
    if (clicks.length >= 7) {
      window.__iwCrestClicks = []
      toast(pick(this.linesValue), { tone: "egg" })
    }
  }
}
