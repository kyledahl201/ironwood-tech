import { Controller } from "@hotwired/stimulus"
import { toast, clearToasts, celebrate, postJSON, pick } from "lib/ui"
import { CodeRunner } from "lib/code_runner"
import { TerminalSim } from "lib/terminal_sim"
import { evaluateChecks } from "lib/checks"
import { buildTutorNote } from "lib/tutor_note"
import { PagePreview } from "lib/page_preview"

// The classroom. The professor's steps play in the board on top; the student
// works in the bench underneath (practice Terminal, and a console and an editor
// each for Ruby, Python, JavaScript and SQL, and a web page editor with a live preview).
// A step with a task opens the next one when its checks pass. Checks run in
// the browser, so they are self-checked practice; the server keeps the place.
const TOOLS = {
  terminal: { kind: "terminal", note: "Practice computer. Nothing here touches your Mac." },
  irb: { kind: "console", language: "ruby", name: "Ruby", prompt: "irb>", more: "..>", arrow: "=> ",
         note: "Ruby runs in your browser. Variables last until you reset." },
  pyrepl: { kind: "console", language: "python", name: "Python", prompt: ">>>", more: "...", arrow: "",
            note: "Python runs in your browser. Variables last until you reset." },
  ruby: { kind: "editor", language: "ruby", name: "Ruby", note: "Ruby runs in your browser." },
  python: { kind: "editor", language: "python", name: "Python", note: "Python runs in your browser. Standard library only: no pip, files or internet." },
  jsrepl: { kind: "console", language: "javascript", name: "JavaScript", prompt: ">", more: "…", arrow: "",
            note: "JavaScript runs in your browser, away from this page. Names last until you reset." },
  js: { kind: "editor", language: "javascript", name: "JavaScript", note: "JavaScript runs in your browser, away from this page. No web page or files here: just the language." },
  sqlrepl: { kind: "console", language: "sql", name: "SQL", prompt: "sql>", more: "...>", arrow: "", thing: "changes", greeting: "SQL console. End each statement with a semicolon and press Enter. Type .tables to see the tables.",
             note: "A practice database in your browser: a small made-up library (books, members, loans). Changes last until you reset." },
  sql: { kind: "editor", language: "sql", name: "SQL", note: "A practice database in your browser (books, members, loans). Every run starts from a fresh copy." },
  web: { kind: "editor", language: "html", name: "HTML", page: true, note: "Your page shows in the preview as you type. Scripts, links and outside files are switched off here." }
}
// How a stopped run is described, for languages where "loop" and "variables" don't fit.
const WORDS = { sql: { runaway: "Look for a query that never ends, like a recursive one with nothing to stop it.",
                       kept: "your earlier statements were run again, so your changes are back", lost: "the practice database is back to how it started" } }
const CONSOLES = Object.keys(TOOLS).filter(mode => TOOLS[mode].kind === "console")
const isEditor = mode => TOOLS[mode]?.kind === "editor"

export default class extends Controller {
  static targets = ["board", "steps", "template", "finish", "meter", "counter", "divider", "bench", "mode", "status", "safe",
                    "pane", "termLines", "termPrompt", "termInput", "editor", "output", "runButton", "checkButton", "preview", "outputHead", "flipButton", "notes"]
  static values = { slug: String, steps: Array, index: Number, homework: Boolean, user: String, store: String,
                    progressUrl: String, quizUrl: String, runtimes: Object, about: String,
                    firstTryLine: String, passLines: Array }

  connect() {
    this.saved = this.load()
    this.steps = this.stepsValue // parsed once, so a step can be compared with itself later
    this.current = Math.min(this.indexValue, this.steps.length)
    this.attempt = this.freshAttempt()
    this.typed = { terminal: [] }  // what was typed, for the up arrow
    this.cursor = { terminal: 0 }
    CONSOLES.forEach(mode => { this.typed[mode] = []; this.cursor[mode] = 0 })
    this.hintsUsed = 0
    this.runners = {}              // one per language, made the first time it is needed
    this.statuses = {}

    this.sim = this.newSim()
    if (this.saved.sim) this.sim.restore(this.saved.sim)
    this.typed.terminal = this.sim.history.slice()
    this.cursor.terminal = this.typed.terminal.length

    this.print("terminal", "Practice terminal. Type help to see what it knows.", "term-note")
    CONSOLES.forEach(mode => this.print(mode, TOOLS[mode].greeting || `${TOOLS[mode].name} console. Type a line of ${TOOLS[mode].name} and press Enter.`, "term-note"))
    this.termPromptTarget.textContent = this.sim.prompt

    this.fit()
    requestAnimationFrame(() => this.settleIn())
    this.onResize = () => this.fit()
    this.onKey = e => this.pageKey(e)
    window.addEventListener("resize", this.onResize)
    document.addEventListener("keydown", this.onKey)

    // A language is a big download, so only fetch one early when this lesson uses it.
    for (const mode of CONSOLES) {
      const { language } = TOOLS[mode]
      const lines = this.saved[mode]
      if (this.steps.some(s => TOOLS[s.mode]?.language === language) || lines?.length) {
        this.runner(language).warm()?.then(() => lines?.length && this.runner(language).restore(lines))
      }
    }

    for (let i = 0; i < this.current; i++) this.showStep(i, { past: true })
    if (this.current >= this.steps.length) this.showFinish({ quiet: true })
    else this.showStep(this.current)
    this.updateMeter()
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    document.removeEventListener("keydown", this.onKey)
    clearInterval(this.typing)
    clearTimeout(this.drawing)
    clearTimeout(this.noting)
    Object.values(this.runners).forEach(runner => runner.dispose())
  }

  // The runner for a language ("ruby" or "python"), started on first use.
  runner(language) {
    if (language === "html" && !this.runners.html) {
      // A web page needs no language runtime: the preview frame draws it and answers the checks.
      this.runners.html = new PagePreview({ frame: this.previewTarget, onLink: () => toast("Links are switched off in the preview, so your page stays put.", { sentry: false }),
                                            onStatus: (text, tone) => { this.statuses.html = [text, tone] } })
    }
    if (!this.runners[language]) {
      const { name, worker, runtime, megabytes } = this.runtimesValue[language]
      this.runners[language] = new CodeRunner({ name, workerUrl: worker, runtimeUrl: runtime, megabytes, words: WORDS[language], onStatus: (text, tone) => {
        this.statuses[language] = [text, tone]
        if (TOOLS[this.mode]?.language === language) this.setStatus(text, tone)
      } })
    }
    return this.runners[language]
  }

  runnerFor(mode) { return TOOLS[mode]?.language ? this.runner(TOOLS[mode].language) : null }

  newSim() { return new TerminalSim({ user: this.userValue, runRuby: code => this.runner("ruby").run(code) }) }

  freshAttempt() { return { commands: [], outputs: [], misses: 0, hints: 0, passing: 0 } }

  // Saved on this computer: the practice computer's files, console lines, drafts.
  load() {
    try { return JSON.parse(localStorage.getItem(this.storeValue)) || {} } catch (_) { return {} }
  }

  save() {
    this.saved.sim = this.sim.serialize()
    CONSOLES.forEach(mode => { const made = this.runners[TOOLS[mode].language]; if (made) this.saved[mode] = made.history.slice(-100) })
    try { localStorage.setItem(this.storeValue, JSON.stringify(this.saved)) } catch (_) { /* private mode */ }
  }

  // Layout ----------------------------------------------------------------------

  fit() {
    let height = null
    try { height = parseInt(localStorage.getItem("iw-bench-height"), 10) } catch (_) { /* private mode */ }
    if (height) this.setBench(height)
  }

  // The classroom fills the window, so open the page scrolled to it.
  settleIn() {
    const top = this.element.getBoundingClientRect().top + window.scrollY
    window.scrollTo({ top, behavior: "auto" })
  }

  setBench(height) {
    const max = Math.max(200, this.element.clientHeight - 220)
    const clamped = Math.round(Math.min(Math.max(height, 150), max))
    this.element.style.setProperty("--bench-h", `${clamped}px`)
    return clamped
  }

  startResize(event) {
    event.preventDefault()
    const startY = event.clientY
    const startHeight = this.benchTarget.offsetHeight
    const move = e => { this.benchHeight = this.setBench(startHeight + (startY - e.clientY)) }
    const stop = () => {
      window.removeEventListener("pointermove", move)
      window.removeEventListener("pointerup", stop)
      try { if (this.benchHeight) localStorage.setItem("iw-bench-height", this.benchHeight) } catch (_) { /* private mode */ }
    }
    window.addEventListener("pointermove", move)
    window.addEventListener("pointerup", stop)
  }

  keyResize(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return
    event.preventDefault()
    const height = this.setBench(this.benchTarget.offsetHeight + (event.key === "ArrowUp" ? 40 : -40))
    try { localStorage.setItem("iw-bench-height", height) } catch (_) { /* private mode */ }
  }

  setStatus(text, tone) {
    this.statusTarget.textContent = text
    this.statusTarget.dataset.tone = tone
  }

  updateMeter() {
    const total = this.steps.length
    const at = Math.min(this.current, total)
    this.meterTarget.style.width = `${Math.round(at * 100 / total)}%`
    this.counterTarget.textContent = at >= total ? (this.homeworkValue ? "Handed in" : "Finished") : `${this.homeworkValue ? "Task" : "Step"} ${at + 1} of ${total}`
  }

  // The board ---------------------------------------------------------------------

  get step() { return this.steps[this.current] }
  get article() { return this.stepsTarget.querySelector(`.step[data-index="${this.current}"]`) }

  showStep(index, { past = false } = {}) {
    const article = this.templateTargets[index].content.firstElementChild.cloneNode(true)
    this.stepsTarget.append(article)
    if (past) return this.markDone(article)

    const step = this.steps[index]
    clearToasts() // praise for the last step shouldn't hang over this one
    this.attempt = this.freshAttempt()
    article.classList.add("is-live")
    if (step.kind === "try") this.setMode(step.mode, { starter: step.starter, index })
    this.checkButtonTarget.hidden = !(step.kind === "try" && isEditor(step.mode))
    this.board(article)
    this.typeOut(article, () => {
      article.classList.remove("is-typing")
      this.board(article) // the task and its buttons just appeared; bring the whole step up
      const go = article.querySelector("[data-role=continue]")
      if (go && !this.busyTyping()) go.focus({ preventScroll: true })
      if (step.kind === "try" && !isEditor(step.mode)) this.entry(step.mode)?.focus({ preventScroll: true })
    })
  }

  board(article) {
    requestAnimationFrame(() => this.boardTarget.scrollTo({ top: article.offsetTop - 12, behavior: this.calm ? "auto" : "smooth" }))
  }

  get calm() { return window.matchMedia("(prefers-reduced-motion: reduce)").matches }

  // Is the student in the middle of typing something of their own?
  busyTyping() {
    const el = document.activeElement
    return !!el && (el.tagName === "TEXTAREA" || el.isContentEditable || (el.tagName === "INPUT" && el.value !== ""))
  }

  // The professor "types" the step. A click or a key shows it all at once.
  typeOut(article, done) {
    const host = article.querySelector(".step-text")
    if (this.calm || !host) return done()
    const nodes = []
    const walker = document.createTreeWalker(host, NodeFilter.SHOW_TEXT)
    while (walker.nextNode()) nodes.push([walker.currentNode, walker.currentNode.textContent])
    nodes.forEach(([node]) => { node.textContent = "" })
    article.classList.add("is-typing")
    let at = 0, shown = 0
    const finish = () => {
      clearInterval(this.typing)
      this.finishTyping = null
      nodes.forEach(([node, text]) => { node.textContent = text })
      done()
    }
    this.finishTyping = finish
    this.typing = setInterval(() => {
      if (at >= nodes.length) return finish()
      const [node, text] = nodes[at]
      shown += 3
      node.textContent = text.slice(0, shown)
      if (shown >= text.length) { at += 1; shown = 0 }
    }, 16)
  }

  skipTyping() { this.finishTyping?.() }

  // A click on the step being typed shows the rest of it at once.
  boardClick(event) {
    if (this.finishTyping && event.target.closest(".step.is-typing")) this.skipTyping()
  }

  pageKey(event) {
    if (!this.finishTyping || event.metaKey || event.ctrlKey || event.altKey) return
    if (event.key === "Enter" || event.key === " ") {
      const tag = event.target.tagName
      if (tag === "INPUT" || tag === "TEXTAREA" || event.target.isContentEditable) return
      event.preventDefault()
      this.skipTyping()
    }
  }

  markDone(article) {
    article.classList.remove("is-live", "is-typing")
    article.classList.add("is-done")
    article.querySelectorAll("[data-role=continue], [data-role=hints], .mac-paste, [data-action='classroom#checkPaste'], [data-role=override]").forEach(el => { el.hidden = true })
    article.querySelectorAll(".quiz-option").forEach(b => { b.disabled = true })
    article.querySelectorAll(".chip").forEach(chip => this.paintChip(chip, true))
    const done = article.querySelector("[data-role=done]")
    if (done) done.hidden = false
  }

  next() {
    if (this.finishTyping) return this.skipTyping()
    this.completeStep()
  }

  completeStep() {
    const article = this.article
    if (!article || article.classList.contains("is-done")) return
    const work = this.work(article) // read before the next step clears the attempt
    this.markDone(article)
    this.current += 1
    this.updateMeter()
    this.save()
    this.report(this.current, work)
    if (this.current >= this.steps.length) this.showFinish()
    else this.showStep(this.current)
  }

  // What the student did on a task, kept with homework for the professor to read:
  // the editor's code on an editor task, otherwise the lines they typed.
  work(article) {
    const step = this.steps[Number(article.dataset.index)]
    if (step?.kind === "try" && isEditor(step.mode) && this.editor) return this.editor.value
    return this.attempt.commands.join("\n")
  }

  // Tell the server one step at a time, in order (it refuses to skip ahead).
  report(index, work) {
    if (this.practice) return
    this.reporting = (this.reporting || Promise.resolve()).then(async () => {
      try {
        const body = this.homeworkValue ? { task_index: index - 1, work } : { step_index: index, hints_used: this.hintsUsed }
        const data = await postJSON(this.progressUrlValue, body)
        celebrate(data.badges)
      } catch (_) {
        this.setStatus("Your place wasn't saved. Are you still signed in?", "bad")
      }
    })
  }

  showFinish({ quiet = false } = {}) {
    const card = this.finishTarget.content.firstElementChild.cloneNode(true)
    this.stepsTarget.append(card)
    this.checkButtonTarget.hidden = true
    if (!quiet) { this.board(card); toast(this.homeworkValue ? "Homework handed in." : "Class finished. Well done.", { tone: "pass" }) }
  }

  // Go through a finished lesson again. The saved place on the server stays.
  replay() {
    this.practice = true // nothing more is sent: the saved place and handed-in homework stay as they are
    this.stepsTarget.innerHTML = ""
    this.current = 0
    this.updateMeter()
    this.showStep(0)
  }

  // Checks ------------------------------------------------------------------------

  paintChip(chip, ok, detail) {
    chip.classList.toggle("is-pass", !!ok)
    chip.classList.toggle("is-fail", !ok)
    chip.querySelector(".chip-dot").textContent = ok ? "✓" : "✗"
    chip.querySelector(".chip-word").textContent = ok ? "Pass" : "Not yet"
    let note = chip.querySelector(".chip-detail")
    if (!ok && detail) {
      if (!note) { note = document.createElement("span"); note.className = "chip-detail"; chip.querySelector(".chip-label").after(note) }
      // A detail can carry a small table under its sentence (SQL shows the rows it found).
      const [sentence, ...rows] = String(detail).split("\n")
      note.textContent = sentence
      if (rows.length) { const table = document.createElement("pre"); table.className = "chip-table"; table.textContent = rows.join("\n"); note.append(table) }
      chip.classList.toggle("has-table", rows.length > 0)
    } else { note?.remove(); chip.classList.remove("has-table") }
  }

  // Marks the chips and moves on when everything passes.
  settle(outcomes) {
    const article = this.article
    if (!article || this.attempt.done) return false
    article.querySelectorAll("[data-role=chips] .chip").forEach((chip, i) => this.paintChip(chip, outcomes[i]?.ok, outcomes[i]?.actual))
    if (outcomes.every(o => o.ok)) {
      if (this.attempt.misses === 0 && this.attempt.hints === 0) toast(this.firstTryLineValue, { tone: "pass" })
      else toast(pick(this.passLinesValue), { tone: "pass" })
      this.attempt.done = true // a second entry while the chips animate must not finish the next step too
      setTimeout(() => this.completeStep(), this.calm ? 0 : 900)
      return true
    }
    // Progress on a task with several parts isn't a miss; a try that gets no
    // further is, and that is when hints are offered.
    const passing = outcomes.filter(o => o.ok).length
    const stalled = passing <= this.attempt.passing
    this.attempt.passing = Math.max(this.attempt.passing, passing)
    clearToasts()
    if (!stalled) return false
    this.attempt.misses += 1
    const hints = article.querySelector("[data-role=hints]")
    if (hints && (this.step.hints || []).length) { hints.hidden = false; this.updateHintButton(article) }
    if (this.step.kind === "mac" && this.attempt.misses >= 2) this.offerOverride(article)
    return false
  }

  // After each console entry on a "your turn" step, see whether the task is done.
  async judge() {
    const step = this.step
    if (!step || step.kind !== "try" || isEditor(step.mode) || this.judging) return
    if (this.article?.classList.contains("is-typing")) this.skipTyping()
    this.judging = true
    try {
      const outcomes = await evaluateChecks(step.checks, { ...this.attempt, sim: this.sim, runner: this.runnerFor(step.mode) })
      if (this.step === step) this.settle(outcomes)
    } finally { this.judging = false }
  }

  hint() {
    const article = this.article
    const hints = this.step.hints || []
    if (this.attempt.hints >= hints.length) return
    const li = document.createElement("li")
    // `code` and **bold** in hints become elements; everything else stays plain text.
    hints[this.attempt.hints].split("`").forEach((part, i) => {
      if (i % 2) { const c = document.createElement("code"); c.textContent = part; li.append(c); return }
      part.split("**").forEach((bit, j) => {
        if (j % 2) { const b = document.createElement("strong"); b.textContent = bit; li.append(b) } else li.append(bit)
      })
    })
    article.querySelector("[data-role=hint-list]").append(li)
    this.attempt.hints += 1
    this.hintsUsed += 1
    this.updateHintButton(article)
  }

  updateHintButton(article) {
    const button = article.querySelector("[data-role=hint-button]")
    const left = (this.step.hints || []).length - this.attempt.hints
    button.hidden = left === 0
    button.textContent = this.attempt.hints === 0 ? "Show a hint" : `Show another hint (${left} left)`
  }

  // Copies where the student is, the task, their work and the checks, to paste
  // into a chat with their professor (the Dean's thread, or their own Claude
  // project set up from a course's tutor kit).
  async copyForTutor(event) {
    const button = event.currentTarget
    const step = this.step
    const article = this.article
    const mode = this.mode
    const tool = TOOLS[mode]
    const task = step && !["teach", "show"].includes(step.kind)
    const select = this.modeTarget
    const note = buildTutorNote({
      about: this.aboutValue,
      place: step ? `${this.homeworkValue ? "Homework task" : "Step"} ${this.current + 1} of ${this.steps.length}` : (this.homeworkValue ? "Homework handed in" : "Class finished"),
      task: article?.querySelector(".step-text")?.innerText,
      tool: select.options[select.selectedIndex].text,
      language: tool.language || "",
      code: tool.kind === "editor" ? this.editor?.value : undefined,
      output: tool.kind === "editor" && !tool.page && this.ranOnce ? this.outputTarget.innerText : undefined,
      notes: tool.page && !this.notesTarget.hidden ? [...this.notesTarget.querySelectorAll("li")].map(li => li.textContent) : [],
      transcript: tool.kind === "editor" ? undefined : this.lines(mode).innerText,
      checks: task ? [...article.querySelectorAll("[data-role=chips] .chip")].map(chip => ({
        label: chip.querySelector(".chip-label").textContent, ok: chip.classList.contains("is-pass"), detail: chip.querySelector(".chip-detail")?.textContent })) : [],
      hints: this.attempt.hints
    })
    try {
      await navigator.clipboard.writeText(note)
      toast("Copied. Paste it into a chat with your professor and add your question.", { sentry: false })
    } catch (_) {
      // No clipboard access: show the text so it can be selected and copied by hand.
      this.outputTarget.textContent = note
      if (tool.kind !== "editor" || tool.page) this.setMode(Object.keys(TOOLS).find(m => isEditor(m) && !TOOLS[m].page && TOOLS[m].language === tool.language) || "ruby", {})
      toast("Copying isn't allowed here. The text is in the Output box: select it and copy it.", { sentry: false })
    }
    button.blur()
  }

  // "On your Mac" steps -------------------------------------------------------------

  async copy(event) {
    const button = event.currentTarget
    try {
      await navigator.clipboard.writeText(button.dataset.copy)
      button.textContent = "Copied"
    } catch (_) {
      button.textContent = "Select the line and copy it"
    }
    setTimeout(() => { button.textContent = "Copy" }, 1800)
  }

  async checkPaste() {
    const article = this.article
    const box = article.querySelector("[data-role=paste]")
    if (!box.value.trim()) { box.focus(); toast("Paste what your Terminal printed first.", { sentry: false }); return }
    this.settle(await evaluateChecks(this.step.checks, { pasted: box.value }))
  }

  // Real Terminals print different things on different Macs. After two tries
  // the student can move on and raise it with their professor.
  offerOverride(article) {
    if (article.querySelector("[data-role=override]")) return
    const button = document.createElement("button")
    button.type = "button"
    button.className = "link-button"
    button.dataset.role = "override"
    button.textContent = "My output looks different. Mark this done and I'll show my professor."
    button.addEventListener("click", () => {
      toast("Marked done. Show your professor what it printed.", { sentry: false })
      this.completeStep()
    })
    article.querySelector("[data-role=hints]").after(button)
  }

  // Quiz ---------------------------------------------------------------------------

  async answer(event) {
    const button = event.currentTarget
    const article = button.closest(".step")
    if (article !== this.article || button.disabled) return
    let data
    try {
      data = await postJSON(this.quizUrlValue, { step: this.current, choice: Number(button.dataset.choice) })
    } catch (_) {
      this.setStatus("That answer wasn't sent. Are you still signed in?", "bad")
      return
    }
    button.disabled = true
    button.classList.add(data.right ? "is-right" : "is-wrong")
    button.querySelector(".quiz-mark").textContent = data.right ? "✓" : "✗"
    button.querySelector(".quiz-word").textContent = data.right ? "Right" : "Not this one"
    const explain = article.querySelector("[data-role=explain]")
    if (!data.right) {
      clearToasts()
      explain.textContent = "Not this one. Look back at the step above and pick again."
      explain.hidden = false
      return
    }
    article.querySelectorAll(".quiz-option").forEach(b => { b.disabled = true })
    explain.innerHTML = data.explain || "Right."   // sanitized Markdown from the server
    explain.hidden = false
    const go = document.createElement("button")
    go.type = "button"
    go.className = "btn btn-copper"
    go.dataset.role = "continue"
    go.textContent = "Continue"
    go.addEventListener("click", () => this.completeStep())
    article.querySelector(".step-actions").prepend(go)
    go.focus({ preventScroll: true })
  }

  // The bench ----------------------------------------------------------------------

  get mode() { return this.modeTarget.value }

  pickMode() { this.setMode(this.mode, {}) }

  setMode(mode, { starter, index } = {}) {
    this.modeTarget.value = mode
    const tool = TOOLS[mode]
    this.paneTargets.forEach(pane => { pane.hidden = pane.dataset.mode !== (tool.kind === "editor" ? "editor" : mode) })
    this.safeTarget.textContent = tool.note
    if (tool.language) {
      this.runner(tool.language).warm()
      this.setStatus(...(this.statuses[tool.language] || ["Ready", "ok"]))
    } else this.setStatus("Ready", "ok")
    // The web page editor shows a live preview where the others show what was printed.
    this.previewTarget.hidden = !tool.page
    this.outputTarget.hidden = this.runButtonTarget.hidden = !!tool.page
    this.outputHeadTarget.textContent = tool.page ? "Preview" : "Output"
    this.flipButtonTarget.hidden = !tool.page
    if (!tool.page) this.notesTarget.hidden = true
    this.pane("editor").classList.toggle("is-page", !!tool.page)
    if (tool.kind === "editor") this.openEditor(`${index === undefined ? "scratch" : `step-${index}`}${tool.language === "ruby" ? "" : `-${tool.language}`}`, starter, tool.language)
  }

  pane(mode) { return this.paneTargets.find(pane => pane.dataset.mode === mode) }
  entry(mode) { return isEditor(mode) ? null : this.pane(mode)?.querySelector("input") }
  lines(mode) { return this.pane(mode).querySelector(".term-lines") }
  prompt(mode) { return this.pane(mode).querySelector(".term-prompt") }

  focusEntry(event) {
    if (window.getSelection()?.toString()) return // let the student select and copy text
    if (event.target.closest("button, a, input")) return
    this.entry(this.mode)?.focus({ preventScroll: true })
  }

  print(mode, text, className = "") {
    if (text === "" || text == null) return
    const host = this.lines(mode)
    const line = document.createElement("div")
    line.className = `term-line ${className}`.trim()
    line.textContent = text
    host.append(line)
    while (host.childElementCount > 400) host.firstElementChild.remove()
    const pane = host.parentElement
    pane.scrollTop = pane.scrollHeight
  }

  async enter(event) {
    event.preventDefault()
    const mode = event.currentTarget.closest(".tool").dataset.mode
    const input = this.entry(mode)
    if (this.running) return
    const text = input.value
    input.value = ""
    if (text.trim()) { this.typed[mode].push(text); this.cursor[mode] = this.typed[mode].length }
    this.running = true
    try {
      if (mode === "terminal") await this.runCommand(text)
      else await this.runLine(mode, text)
    } finally {
      this.running = false
    }
    this.save()
    if (text.trim()) await this.judge()
  }

  async runCommand(text) {
    this.print("terminal", `${this.sim.prompt} ${text}`, "term-typed")
    if (!text.trim()) return
    const result = await this.sim.exec(text)
    if (result.clear) this.termLinesTarget.innerHTML = ""
    this.print("terminal", result.output)
    this.termPromptTarget.textContent = this.sim.prompt
    this.attempt.commands.push(text.trim())
    this.attempt.outputs.push(result.output || "")
  }

  async runLine(mode, text) {
    const tool = TOOLS[mode]
    const runner = this.runnerFor(mode)
    this.print(mode, `${runner.partial ? tool.more : tool.prompt} ${text}`, "term-typed")
    const result = await runner.type(text)
    if (result.empty) return
    // While an entry is unfinished the prompt shows the language is waiting
    // for the rest (an end in Ruby; in Python, a blank line ends a block).
    this.prompt(mode).textContent = runner.partial ? tool.more : tool.prompt
    if (result.incomplete) return
    this.print(mode, (result.stdout || "").replace(/\n$/, ""), tool.language === "sql" ? "term-table" : "")
    if (result.error) {
      this.print(mode, result.error.friendly, "term-error")
      this.print(mode, result.error.raw, "term-raw")
    } else if (result.value != null) {
      this.print(mode, `${tool.arrow}${result.value}`, "term-value")
    }
    this.attempt.commands.push(result.source.trim())
    if (result.error) this.attempt.outputs.push(result.error.raw || "") // a lesson may ask the student to cause an error and read it
    else this.attempt.outputs.push(result.stdout || "", result.value || "", `${result.stdout || ""}${result.value || ""}`)
  }

  // Up and down recall earlier lines, Tab completes a file name, Ctrl+C gives up
  // on a half-typed line, Ctrl+L clears the screen.
  entryKey(event) {
    const mode = event.currentTarget.closest(".tool").dataset.mode
    const input = event.currentTarget
    const typed = this.typed[mode]
    if (event.key === "ArrowUp" || event.key === "ArrowDown") {
      event.preventDefault()
      const at = Math.min(Math.max(this.cursor[mode] + (event.key === "ArrowUp" ? -1 : 1), 0), typed.length)
      this.cursor[mode] = at
      input.value = typed[at] ?? ""
    } else if (event.key === "Tab" && mode === "terminal" && input.value) {
      event.preventDefault()
      input.value = this.sim.complete(input.value)
    } else if (event.ctrlKey && event.key.toLowerCase() === "c") {
      input.value = ""
      if (TOOLS[mode].kind === "console") { this.runnerFor(mode).cancel(); this.prompt(mode).textContent = TOOLS[mode].prompt }
    } else if (event.ctrlKey && event.key.toLowerCase() === "l") {
      event.preventDefault()
      this.lines(mode).innerHTML = ""
    }
  }

  async resetTool() {
    const mode = this.mode
    if (mode === "terminal") {
      if (!confirm("Start the practice computer over? Folders and files you made in it will be gone.")) return
      this.sim = this.newSim()
      this.termLinesTarget.innerHTML = ""
      this.print("terminal", "A fresh practice computer.", "term-note")
      this.termPromptTarget.textContent = this.sim.prompt
    } else if (TOOLS[mode].kind === "console") {
      const { name, prompt, thing = "variables" } = TOOLS[mode]
      if (!confirm(`Start the ${name} console over? Its ${thing} will be gone.`)) return
      await this.runnerFor(mode).resetConsole()
      this.prompt(mode).textContent = prompt
      this.lines(mode).innerHTML = ""
      this.print(mode, `A fresh ${name} console.`, "term-note")
    } else {
      const starter = this.editorStarter || ""
      if (this.editor && this.editor.value !== starter && !confirm("Replace your code with the starting code?")) return
      if (this.editor) this.editor.value = starter
    }
    this.save()
  }

  // The editor (Ruby or Python) ------------------------------------------------------

  async openEditor(key, starter, language) {
    // A step with starting code opens with it. A step without any carries on
    // from the code already in the editor, so "now add a line" steps work
    // (unless the editor last held the other language).
    const carried = () => this.editorLanguage === language ? this.editor?.value : undefined
    const draft = () => this.saved.drafts?.[key] ?? starter ?? carried() ?? (language === "ruby" ? this.saved.code : undefined) ?? ""
    const doc = draft()
    this.editorKey = key
    this.editorStarter = starter ?? ""
    if (this.mounting) await this.mounting
    if (this.editor && this.editorLanguage === language) { this.editor.value = doc; this.draw(0); return }
    const remember = text => { (this.saved.drafts ||= {})[this.editorKey] = text; if (this.editorLanguage === "ruby") this.saved.code = text; this.save(); this.draw() }
    this.editorLanguage = language
    this.mounting = (async () => {
      try {
        const { createEditor } = await import("lab/editor")
        this.editor?.view?.destroy()
        this.editorTarget.innerHTML = ""
        this.editor = createEditor(this.editorTarget, { doc, language, onRun: () => this.checkEditor(), onChange: remember })
        if (!this.editorKeys) {
          this.editorKeys = true
          this.editorTarget.addEventListener("keydown", e => {
            if (e.key === "Enter" && e.shiftKey && !e.metaKey && !e.ctrlKey) { e.preventDefault(); e.stopPropagation(); this.runEditor() }
          }, true)
        }
      } catch (_) {
        // Plain textarea if the editor bundle can't load.
        const fallback = this.editorTarget.querySelector("textarea")
        if (!fallback) return
        fallback.value = doc
        if (!this.editor) fallback.addEventListener("input", () => remember(fallback.value))
        this.editor = { get value() { return fallback.value }, set value(v) { fallback.value = v }, focus() { fallback.focus() } }
      }
    })()
    await this.mounting
    this.mounting = null
    this.draw(0)
  }

  // On a narrow screen the web page editor shows the code or the preview, one at a time.
  flipPreview() {
    const showing = this.pane("editor").classList.toggle("show-preview")
    this.flipButtonTarget.textContent = showing ? "Show code" : "Show preview"
    this.flipButtonTarget.setAttribute("aria-pressed", String(showing))
  }

  // Redraws the web page preview shortly after the student stops typing.
  draw(wait = 250) {
    clearTimeout(this.drawing)
    if (this.editorLanguage !== "html" || !this.editor) return
    this.drawing = setTimeout(() => { if (this.editorLanguage === "html" && !this.running) this.runner("html").show(this.editor.value) }, wait)
    // The notes wait a little longer, so they don't flicker at a tag that is only half typed.
    clearTimeout(this.noting)
    this.noting = setTimeout(() => this.showNotes(), wait === 0 ? 0 : 1200)
  }

  // Says what the browser quietly fixed or skipped in the student's page, with line numbers.
  showNotes() {
    clearTimeout(this.noting)
    if (this.editorLanguage !== "html" || !this.editor || !TOOLS[this.mode]?.page) return
    const notes = this.runner("html").notes(this.editor.value)
    const list = this.notesTarget.querySelector("ul")
    list.textContent = ""
    notes.slice(0, 5).forEach(({ line, text }) => {
      const item = document.createElement("li"), where = document.createElement("strong")
      where.textContent = `Line ${line}`
      item.append(where, ` ${text}`)
      list.append(item)
    })
    if (notes.length > 5) { const more = document.createElement("li"); more.textContent = `And ${notes.length - 5} more. Fix the first ones and the rest often go away.`; list.append(more) }
    this.notesTarget.hidden = notes.length === 0
    this.editor.view?.requestMeasure() // the notes take room from the editor on a narrow screen
  }

  showOutput(result) {
    const out = this.outputTarget
    out.textContent = ""
    out.classList.toggle("is-table", TOOLS[this.mode]?.language === "sql")
    if (result.stdout) out.append(document.createTextNode(result.stdout))
    if (result.error) {
      const err = document.createElement("span")
      err.className = "console-error"
      err.textContent = (result.stdout ? "\n" : "") + result.error.friendly
      const raw = document.createElement("span")
      raw.className = "console-raw"
      raw.textContent = result.error.raw ? `\n${result.error.raw}` : ""
      out.append(err, raw)
    }
    if (!result.stdout && !result.error) {
      const none = document.createElement("span")
      none.className = "console-muted"
      none.textContent = TOOLS[this.mode]?.language === "sql" ? "(nothing to show. Add a SELECT to see rows)" : "(your code printed nothing)"
      out.append(none)
    }
  }

  async execute(checks) {
    if (!this.editor || this.running) return null
    this.running = true
    this.runButtonTarget.disabled = this.checkButtonTarget.disabled = true
    const page = TOOLS[this.mode].page
    clearTimeout(this.drawing)
    this.setStatus(page ? "Checking…" : "Running…", "busy")
    try {
      const result = await this.runnerFor(this.mode).run(this.editor.value, checks)
      if (page) { this.showNotes(); this.setStatus("Ready", "ok"); return result }
      this.ranOnce = true
      this.showOutput(result)
      this.setStatus(result.error ? "Error" : "Ran", result.error ? "bad" : "ok")
      return result
    } finally {
      this.running = false
      this.runButtonTarget.disabled = this.checkButtonTarget.disabled = false
    }
  }

  runEditor() { return this.execute([]) }

  async checkEditor() {
    const step = this.step
    if (!step || step.kind !== "try" || !isEditor(step.mode) || step.mode !== this.mode) return this.runEditor()
    if (this.article?.classList.contains("is-typing")) this.skipTyping()
    const result = await this.execute(step.checks.map(c => ({ type: c.type, call: c.call, expected: c.expected })))
    if (!result) return
    const outcomes = await evaluateChecks(step.checks, { code: this.editor.value, result, runner: this.runnerFor(step.mode) })
    this.settle(result.error ? outcomes.map(o => ({ ...o, ok: false })) : outcomes)
  }
}
