// Counts time the student is actually here: the page is showing and they have
// typed, clicked, tapped or scrolled recently. A tab left open, or a walk to
// the kitchen, doesn't count.
export class ActivityClock {
  constructor({ now = () => Date.now(), idleAfterMs = 120000, maxGapMs = 5000 } = {}) {
    this.now = now
    this.idleAfterMs = idleAfterMs
    this.maxGapMs = maxGapMs // a longer gap between ticks means the tab was asleep
    this.visible = true
    this.activeMs = 0
    this.lastTick = now()
    this.lastActivity = now()
  }

  // The student did something.
  touch() {
    this.tick()
    this.lastActivity = this.now()
  }

  setVisible(visible) {
    this.tick()
    this.visible = visible
    if (visible) this.lastTick = this.now()
  }

  get idle() { return this.now() - this.lastActivity > this.idleAfterMs }

  // Call about once a second. Adds the time since the last tick if it counts.
  tick() {
    const now = this.now()
    const gap = now - this.lastTick
    this.lastTick = now
    if (!this.visible || gap <= 0 || gap > this.maxGapMs) return
    if (now - this.lastActivity > this.idleAfterMs) return
    this.activeMs += gap
  }

  // Whole seconds counted since the last take; the remainder carries over.
  take() {
    this.tick()
    const seconds = Math.floor(this.activeMs / 1000)
    this.activeMs -= seconds * 1000
    return seconds
  }
}
