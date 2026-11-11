import { Controller } from "@hotwired/stimulus"
import { toast, celebrate, postJSON, pick } from "lib/ui"

// The code lab (Prof. Hale's rules, Prof. Duarte's layout).
// Ruby runs in a Web Worker with ruby.wasm; a run that takes too long is stopped
// by terminating the worker. Source and output checks run here, method checks
// run inside the worker. The server only records pass or fail.
const TIMEOUT_MS = 6000

export default class extends Controller {
  static targets = ["editor", "chips", "hints", "hintList", "hintButton", "status", "timer",
                    "output", "diff", "runButton", "checkButton", "logButton", "next"]
  static values = { slug: String, checks: Array, hints: Array, starter: String, workerUrl: String,
                    wasmUrl: String, attemptsUrl: String, logUrl: String, course: String, passed: Boolean,
                    passLines: Array, firstTryLines: String, failLines: Array }

  async connect() {
    this.hintsShown = 0
    this.failures = 0
    this.runId = 0
    this.started = Date.now()
    this.draftKey = `iw-lab-${this.slugValue}`
    this.tick = setInterval(() => this.updateTimer(), 1000)
    this.startWorker()
    await this.mountEditor()
  }

  disconnect() {
    clearInterval(this.tick)
    this.worker?.terminate()
  }

  // Editor ------------------------------------------------------------------

  async mountEditor() {
    const fallback = this.editorTarget.querySelector("textarea")
    const doc = this.loadDraft() ?? this.starterValue
    try {
      const { createEditor } = await import("lab/editor")
      this.editorTarget.innerHTML = ""
      this.editor = createEditor(this.editorTarget, {
        doc,
        onRun: () => this.check(),
        onChange: text => this.saveDraft(text)
      })
      // Shift+Enter runs without checking.
      this.editorTarget.addEventListener("keydown", e => {
        if (e.key === "Enter" && e.shiftKey && !e.metaKey && !e.ctrlKey) { e.preventDefault(); e.stopPropagation(); this.run() }
      }, true)
    } catch (e) {
      // Plain textarea if the editor bundle can't load.
      fallback.value = doc
      fallback.addEventListener("input", () => this.saveDraft(fallback.value))
      this.editor = { get value() { return fallback.value }, set value(v) { fallback.value = v }, focus() { fallback.focus() } }
    }
  }

  get code() { return this.editor ? this.editor.value : this.starterValue }

  loadDraft() {
    try { return localStorage.getItem(this.draftKey) } catch (_) { return null }
  }

  saveDraft(text) {
    try { localStorage.setItem(this.draftKey, text) } catch (_) { /* private mode */ }
  }

  reset() {
    if (this.code !== this.starterValue && !confirm("Replace your code with the starter code?")) return
    this.editor.value = this.starterValue
    this.saveDraft(this.starterValue)
    this.editor.focus()
  }

  // Worker ------------------------------------------------------------------

  startWorker() {
    const restarting = !!this.worker
    this.worker?.terminate()
    this.ready = false
    this.warmed = false
    this.firstRunDone = false
    if (!restarting) this.setStatus("Loading Ruby…", "busy")
    this.worker = new Worker(this.workerUrlValue, { type: "module" })
    this.worker.onmessage = ({ data }) => {
      if (data.ready) {
        this.ready = true
        if (!restarting) this.setStatus("Ready", "ok")
        this.warm()
        return
      }
      if (data.id === this.runId && this.pending) { this.pending(data); this.pending = null }
    }
    this.worker.onerror = () => this.setStatus("Ruby didn't load. Refresh to try again.", "bad")
  }

  // Compile the wasm in the background so the first Run is quick.
  warm() {
    if (this.warmed) return
    this.warmed = true
    this.execute("nil", [], { quiet: true }).catch(() => {})
  }

  execute(code, checks, { quiet = false } = {}) {
    // A new run replaces any run still waiting (such as the warm-up).
    clearTimeout(this.runTimer)
    const id = ++this.runId
    if (!quiet) this.busy(true)
    return new Promise((resolve, reject) => {
      const limit = quiet ? 60000 : TIMEOUT_MS + (this.firstRunDone ? 0 : 20000)
      this.runTimer = setTimeout(() => {
        if (id !== this.runId) return
        this.pending = null
        this.startWorker()
        reject(new Error("timeout"))
      }, limit)
      this.pending = data => {
        clearTimeout(this.runTimer)
        this.firstRunDone = true
        data.ok ? resolve(data.result) : reject(new Error(data.error))
      }
      this.worker.postMessage({ id, code, checks, wasmUrl: this.wasmUrlValue })
    }).finally(() => { if (!quiet) this.busy(false) })
  }

  busy(on) {
    this.runButtonTarget.disabled = on
    this.checkButtonTarget.disabled = on
    if (on) this.setStatus("Running…", "busy")
  }

  setStatus(text, tone) {
    this.statusTarget.textContent = text
    this.statusTarget.dataset.tone = tone
  }

  // Run and Check -------------------------------------------------------------

  async run() {
    this.diffTarget.hidden = true
    try {
      const result = await this.execute(this.code, [])
      this.showOutput(result)
      this.setStatus(result.error ? "Error" : "Ran", result.error ? "bad" : "ok")
    } catch (e) {
      this.showFailure(e)
    }
  }

  async check() {
    const checks = this.checksValue
    let result
    try {
      result = await this.execute(this.code, checks.map(c => ({ type: c.type, call: c.call, expected: c.expected })))
    } catch (e) {
      this.showFailure(e)
      this.markChecks(checks.map(() => ({ ok: false })))
      this.recordFailure()
      return
    }
    this.showOutput(result)

    const outcomes = checks.map((c, i) => this.evaluate(c, result, result.checks[i]))
    this.markChecks(outcomes)
    const passedCount = outcomes.filter(o => o.ok).length
    const passed = passedCount === checks.length && !result.error
    this.showDiff(checks, outcomes)

    if (passed) {
      this.setStatus("All checks pass", "ok")
      toast(this.failures === 0 && this.hintsShown === 0 ? this.firstTryLinesValue : pick(this.passLinesValue), { tone: "pass" })
      this.element.classList.add("is-passed")
    } else {
      this.setStatus(`${passedCount} of ${checks.length} checks pass`, "bad")
      this.recordFailure()
    }
    this.logButtonTarget.hidden = false
    this.updateTimer()
    this.save(passed, passedCount)
  }

  evaluate(check, result, workerCheck) {
    const src = this.code
    switch (check.type) {
      case "stdout": {
        const want = String(check.expected || "")
        const got = result.stdout || ""
        return { ok: !result.error && this.normalize(got) === this.normalize(want), expected: want, actual: got }
      }
      case "source_includes":
        return { ok: src.includes(check.expected), expected: `uses ${check.expected}` }
      case "source_excludes":
        return { ok: !src.includes(check.expected), expected: `doesn't use ${check.expected}` }
      case "source_matches": {
        let ok = false
        try { ok = new RegExp(check.expected).test(src) } catch (_) { ok = false }
        return { ok, expected: check.label }
      }
      default:
        return workerCheck ? { ok: !!workerCheck.ok, expected: workerCheck.expected, actual: workerCheck.actual } : { ok: false }
    }
  }

  // Trailing spaces and the final newline don't count; everything else does.
  normalize(text) {
    return String(text).replace(/\r\n/g, "\n").split("\n").map(l => l.replace(/\s+$/, "")).join("\n").replace(/\n+$/, "")
  }

  markChecks(outcomes) {
    this.chipsTarget.querySelectorAll(".chip").forEach((chip, i) => {
      const ok = outcomes[i]?.ok
      chip.classList.toggle("is-pass", !!ok)
      chip.classList.toggle("is-fail", !ok)
      chip.querySelector(".chip-dot").textContent = ok ? "✓" : "✗"
      chip.title = ok ? "Pass" : "Not yet"
    })
  }

  showOutput(result) {
    const out = this.outputTarget
    out.textContent = ""
    out.classList.remove("has-error")
    if (result.stdout) out.append(document.createTextNode(result.stdout))
    if (result.error) {
      out.classList.add("has-error")
      const err = document.createElement("span")
      err.className = "console-error"
      err.textContent = (result.stdout ? "\n" : "") + result.error.friendly
      const raw = document.createElement("span")
      raw.className = "console-raw"
      raw.textContent = `\n${result.error.raw}`
      out.append(err, raw)
    }
    if (!result.stdout && !result.error) {
      const none = document.createElement("span")
      none.className = "console-muted"
      none.textContent = "(Your code ran and printed nothing.)"
      out.append(none)
    }
  }

  showFailure(e) {
    this.outputTarget.classList.add("has-error")
    if (String(e.message) === "timeout") {
      this.outputTarget.textContent = "Your code ran for too long, so the lab stopped it. Is there a loop that never ends?"
      this.setStatus("Stopped", "bad")
    } else {
      this.outputTarget.textContent = `The lab couldn't run that: ${e.message}`
      this.setStatus("Error", "bad")
    }
  }

  // Line-by-line comparison for output checks and expected vs got for method checks.
  showDiff(checks, outcomes) {
    const box = this.diffTarget
    box.innerHTML = ""
    const failed = checks.map((c, i) => [c, outcomes[i]]).filter(([, o]) => !o.ok)
    if (!failed.length) { box.hidden = true; return }
    failed.forEach(([check, o]) => {
      const item = document.createElement("div")
      item.className = "diff-item"
      const title = document.createElement("p")
      title.className = "diff-title"
      title.textContent = check.label
      item.append(title)
      if (check.type === "stdout") {
        item.append(this.lineDiff(o.expected || "", o.actual || ""))
      } else if (o.actual !== undefined) {
        const t = document.createElement("dl")
        t.className = "diff-pair"
        t.innerHTML = "<dt>Expected</dt><dd></dd><dt>Got</dt><dd></dd>"
        const dds = t.querySelectorAll("dd")
        dds[0].textContent = o.expected
        dds[1].textContent = o.actual
        item.append(t)
      }
      box.append(item)
    })
    box.hidden = false
  }

  lineDiff(expected, actual) {
    const want = this.normalize(expected).split("\n")
    const got = actual === "" ? [] : this.normalize(actual).split("\n")
    const table = document.createElement("table")
    table.className = "diff-table"
    table.innerHTML = "<thead><tr><th>#</th><th>Expected</th><th>Your output</th></tr></thead>"
    const body = document.createElement("tbody")
    for (let i = 0; i < Math.max(want.length, got.length); i++) {
      const tr = document.createElement("tr")
      const same = want[i] === got[i]
      tr.className = same ? "same" : "differs"
      ;[String(i + 1), want[i] ?? "(nothing)", got[i] ?? "(nothing)"].forEach(text => {
        const td = document.createElement("td")
        td.textContent = text === "" ? "(blank line)" : text
        tr.append(td)
      })
      body.append(tr)
    }
    table.append(body)
    return table
  }

  // Hints: one at a time, only after a failed check ---------------------------

  recordFailure() {
    this.failures += 1
    if (this.hintsValue.length) {
      this.hintsTarget.hidden = false
      this.updateHintButton()
    }
    toast(pick(this.failLinesValue), { tone: "fail" })
  }

  nextHint() {
    if (this.hintsShown >= this.hintsValue.length || this.failures === 0) return
    const li = document.createElement("li")
    // `code` spans in hints become <code>; everything else stays plain text.
    this.hintsValue[this.hintsShown].split("`").forEach((part, i) => {
      if (i % 2) { const c = document.createElement("code"); c.textContent = part; li.append(c) } else li.append(part)
    })
    this.hintListTarget.append(li)
    this.hintsShown += 1
    this.updateHintButton()
  }

  updateHintButton() {
    const left = this.hintsValue.length - this.hintsShown
    this.hintButtonTarget.hidden = left === 0
    this.hintButtonTarget.textContent = this.hintsShown === 0 ? "Show a hint" : `Show another hint (${left} left)`
  }

  // Saving --------------------------------------------------------------------

  async save(passed, checksPassed) {
    try {
      const data = await postJSON(this.attemptsUrlValue, { code: this.code, passed, checks_passed: checksPassed, hints_used: this.hintsShown })
      celebrate(data.badges)
      if (passed) this.showNext(data)
    } catch (_) {
      this.setStatus("Checked, but not saved. Are you still signed in?", "bad")
    }
  }

  showNext(data) {
    const box = this.nextTarget
    box.innerHTML = ""
    const p = document.createElement("p")
    if (data.next_url) {
      p.textContent = "Next up: "
      const a = document.createElement("a")
      a.href = data.next_url
      a.textContent = data.next_title
      a.className = "btn btn-copper"
      box.append(p, a)
    } else {
      p.textContent = "That's every open exercise. New ones open as lessons are taught."
      box.append(p)
    }
    box.hidden = false
  }

  // Time ----------------------------------------------------------------------

  get minutes() { return Math.max(1, Math.round((Date.now() - this.started) / 60000)) }

  updateTimer() {
    const s = Math.floor((Date.now() - this.started) / 1000)
    this.timerTarget.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
    if (!this.logButtonTarget.hidden) this.logButtonTarget.textContent = `Log ${this.minutes} min`
  }

  async logTime() {
    const minutes = this.minutes
    try {
      const data = await postJSON(this.logUrlValue, { study_session: { minutes, course_code: this.courseValue, note: "Code lab" } })
      if (!data.ok) throw new Error((data.errors || []).join(", "))
      toast(`Logged ${minutes} minutes.`, { tone: "pass", sentry: false })
      celebrate(data.badges)
      this.started = Date.now()
      this.logButtonTarget.hidden = true
    } catch (e) {
      toast(`Couldn't log that: ${e.message}`, { tone: "fail", sentry: false })
    }
  }
}
