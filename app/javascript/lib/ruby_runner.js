// Talks to the Ruby worker (public/lab/ruby-worker.js) for the classroom.
// run() uses a fresh Ruby each time. The console keeps one Ruby alive so
// variables last between lines; if a line runs away, the worker is stopped
// and the earlier lines are replayed so nothing the student set is lost.
const TIMEOUT_MS = 6000

export class RubyRunner {
  constructor({ workerUrl, wasmUrl, onStatus = () => {} }) {
    this.workerUrl = workerUrl
    this.wasmUrl = wasmUrl
    this.onStatus = onStatus
    this.id = 0
    this.queue = Promise.resolve()
    this.history = []   // console lines that ran without an error
    this.loaded = false
    this.start()
  }

  start() {
    this.worker?.terminate()
    this.worker = new Worker(this.workerUrl, { type: "module" })
    this.worker.onmessage = ({ data }) => {
      if (data.ready) return
      if (data.id === this.id && this.pending) { const done = this.pending; this.pending = null; done(data) }
    }
    this.worker.onerror = () => this.onStatus("Ruby didn't load. Refresh to try again.", "bad")
  }

  // Compile Ruby in the background so the first line is quick.
  warm() {
    if (this.warming) return this.warming
    this.onStatus("Loading Ruby…", "busy")
    this.warming = this.send({ code: "nil", checks: [] }, 90000)
      .then(() => { this.loaded = true; this.onStatus("Ready", "ok") })
      .catch(e => { this.warming = null; this.onStatus(e.message === "timeout" ? "Ruby is slow to load. Try again." : e.message, "bad") })
    return this.warming
  }

  // One message at a time; each waits for the one before it.
  send(message, limit) {
    const job = this.queue.then(() => new Promise((resolve, reject) => {
      const id = ++this.id
      const timer = setTimeout(() => {
        if (id !== this.id) return
        this.pending = null
        this.start()
        reject(new Error("timeout"))
      }, limit ?? (this.loaded ? TIMEOUT_MS : 90000))
      this.pending = data => { clearTimeout(timer); this.loaded = true; data.ok ? resolve(data.result) : reject(new Error(data.error)) }
      this.worker.postMessage({ id, wasmUrl: this.wasmUrl, ...message })
    }))
    this.queue = job.catch(() => {})
    return job
  }

  // Runs a whole program: { stdout, error, checks }.
  run(code, checks = []) {
    return this.send({ code, checks }).catch(e => this.afterCrash(e))
  }

  // Runs one console entry: { stdout, value, error, incomplete }.
  async line(text) {
    try {
      const result = await this.send({ console: true, op: "eval", line: text })
      if (!result.error) this.remember(text)
      return result
    } catch (e) {
      return this.afterCrash(e)
    }
  }

  // Looks up values for value_is checks: [{ ok, expected, actual }].
  async values(checks) {
    if (!checks.length) return []
    try {
      return (await this.send({ console: true, op: "values", checks })).checks
    } catch (_) {
      return checks.map(() => ({ ok: false, actual: "not set yet" }))
    }
  }

  remember(text) {
    this.history.push(text)
    if (this.history.length > 200) this.history.shift()
  }

  // Put earlier console lines back (after a reload or a stopped run).
  async restore(lines) {
    this.history = []
    for (const text of lines || []) {
      try {
        const result = await this.send({ console: true, op: "eval", line: text }, 20000)
        if (!result.error) this.history.push(text)
      } catch (_) { break }
    }
  }

  async resetConsole() {
    this.history = []
    try { await this.send({ console: true, op: "reset" }) } catch (_) { /* a fresh worker is already clean */ }
  }

  async afterCrash(error) {
    if (error.message !== "timeout") return { stdout: "", error: { friendly: error.message, raw: "" } }
    const lines = this.history.slice()
    this.onStatus("Stopped", "bad")
    this.restore(lines).then(() => this.onStatus("Ready", "ok"))
    return { stdout: "", stopped: true, error: {
      friendly: "That ran for more than 6 seconds, so it was stopped. Look for a loop that never ends.", raw: "" } }
  }

  dispose() { this.worker?.terminate() }
}
