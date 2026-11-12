import { Controller } from "@hotwired/stimulus"
import { postJSON, csrfToken, celebrate } from "lib/ui"
import { ActivityClock } from "lib/activity_clock"

// Logs study time by itself. While the page is showing and the student is
// active, it sends the seconds that passed every half minute. The server adds
// them to today's record for this course and activity.
const SEND_EVERY_MS = 30000
const EVENTS = ["keydown", "pointerdown", "pointermove", "wheel", "touchstart", "scroll"]

export default class extends Controller {
  static targets = ["today"]
  static values = { url: String, course: String, activity: String }

  connect() {
    this.clock = new ActivityClock()
    this.onActivity = () => this.clock.touch()
    this.onVisibility = () => {
      this.clock.setVisible(document.visibilityState === "visible")
      if (document.visibilityState !== "visible") this.send({ leaving: true })
    }
    this.onLeave = () => this.send({ leaving: true })
    EVENTS.forEach(name => window.addEventListener(name, this.onActivity, { passive: true, capture: true }))
    document.addEventListener("visibilitychange", this.onVisibility)
    window.addEventListener("pagehide", this.onLeave)
    this.ticker = setInterval(() => this.clock.tick(), 1000)
    this.sender = setInterval(() => this.send(), SEND_EVERY_MS)
  }

  disconnect() {
    EVENTS.forEach(name => window.removeEventListener(name, this.onActivity, { capture: true }))
    document.removeEventListener("visibilitychange", this.onVisibility)
    window.removeEventListener("pagehide", this.onLeave)
    clearInterval(this.ticker)
    clearInterval(this.sender)
    this.send({ leaving: true })
  }

  async send({ leaving = false } = {}) {
    const seconds = this.clock.take()
    if (seconds <= 0) return
    const body = { seconds, course_code: this.courseValue, activity: this.activityValue }
    if (leaving) {
      // The page is going away, so this request must outlive it.
      fetch(this.urlValue, { method: "POST", keepalive: true, credentials: "same-origin",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": csrfToken() }, body: JSON.stringify(body) }).catch(() => {})
      return
    }
    try {
      const data = await postJSON(this.urlValue, body)
      if (this.hasTodayTarget && data.today_label) this.todayTarget.textContent = data.today_label
      celebrate(data.badges)
    } catch (_) { /* offline or signed out: the next send tries again */ }
  }
}
