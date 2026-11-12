// Talks to a language worker for the classroom: Ruby (public/lab/ruby-worker.js)
// or Python (public/lab/python-worker.js). Both speak the same messages.
// run() starts clean each time. The console keeps one interpreter alive so
// variables last between lines; if a line runs away, the worker is stopped
// and the earlier lines are replayed so nothing the student set is lost.
const TIMEOUT_MS = 6000

export class CodeRunner {
  constructor({ name = "Ruby", workerUrl, runtimeUrl, megabytes = null, onStatus = () => {}, timeoutMs = TIMEOUT_MS, WorkerClass = globalThis.Worker }) {
    this.timeoutMs = timeoutMs
    this.WorkerClass = WorkerClass
    this.workerUrl = workerUrl
    this.name = name            // "Ruby" or "Python", for messages
    this.runtimeUrl = runtimeUrl // where the worker loads the language from
    this.onStatus = onStatus
    this.id = 0
    this.queue = Promise.resolve()
    this.megabytes = megabytes   // download size, for the first-load message
    this.history = []   // console entries that ran without an error
    this.partial = ""   // lines of a console entry that isn't finished yet
    this.loaded = false
    this.start()
  }

  start() {
    this.worker?.terminate()
    this.worker = new this.WorkerClass(this.workerUrl, { type: "module" })
    this.worker.onmessage = ({ data }) => {
      if (data.ready) return
      if (data.id === this.id && this.pending) { const done = this.pending; this.pending = null; done(data) }
    }
    this.worker.onerror = () => this.onStatus(`${this.name} didn't load. Refresh to try again.`, "bad")
  }

  // Load the language in the background so the first line is quick.
  warm() {
    if (this.warming) return this.warming
    this.onStatus(`Loading ${this.name}${this.megabytes ? ` (first time only, about ${this.megabytes} MB)` : ""}…`, "busy")
    this.warming = this.send({ code: "", checks: [] }, 90000)
      .then(() => { this.loaded = true; this.onStatus("Ready", "ok") })
      .catch(e => { this.warming = null; this.onStatus(e.message === "timeout" ? `${this.name} is slow to load. Try again.` : e.message, "bad") })
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
      }, limit ?? (this.loaded ? this.timeoutMs : 90000))
      this.pending = data => { clearTimeout(timer); this.loaded = true; data.ok ? resolve(data.result) : reject(new Error(data.error)) }
      this.worker.postMessage({ id, runtimeUrl: this.runtimeUrl, ...message })
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
      if (!result.error && !result.incomplete) this.remember(text) // only whole entries that ran are replayed later
      return result
    } catch (e) {
      return this.afterCrash(e)
    }
  }

  // One line typed at the console. An entry can take several lines (a method,
  // a loop, an open bracket): they are kept until the language says the entry
  // is complete, then it runs as one. In Python a blank line ends a block, so
  // the finished entry keeps its line breaks, and a replay runs it the same way.
  async type(text) {
    const source = this.partial + text
    if (!source.trim()) return { empty: true }
    const result = await this.line(source)
    this.partial = result.incomplete ? `${source}\n` : ""
    return { ...result, source }
  }

  // Give up on a half-typed entry (Ctrl+C).
  cancel() { this.partial = "" }

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
        if (!result.error && !result.incomplete) this.history.push(text)
      } catch (_) { break }
    }
  }

  async resetConsole() {
    this.history = []
    this.partial = ""
    try { await this.send({ console: true, op: "reset" }) } catch (_) { /* a fresh worker is already clean */ }
  }

  async afterCrash(error) {
    if (error.message !== "timeout") return { stdout: "", error: { friendly: error.message, raw: "" } }
    const lines = this.history.slice()
    this.onStatus("Stopped", "bad")
    this.restoring = this.restore(lines).then(() => this.onStatus("Ready", "ok"))
    const seconds = Math.round(this.timeoutMs / 1000)
    const kept = lines.length
      ? ` ${this.name} was restarted and your earlier lines were run again, so your variables are back.`
      : ` ${this.name} was restarted, so anything set in the console is gone.`
    return { stdout: "", stopped: true, error: {
      friendly: `That ran for more than ${seconds} seconds, so it was stopped. Look for a loop that never ends.${kept}`, raw: "" } }
  }

  dispose() { this.worker?.terminate() }
}
