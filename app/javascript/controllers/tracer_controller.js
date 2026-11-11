import { Controller } from "@hotwired/stimulus"

// Loop tracer: steps through a small .each program and shows the line Ruby is on,
// the variables, the array position and the output. The example is deliberately
// not one of the lab exercises, so it never shows an exercise's answer.
const LINES = [
  'words = __WORDS__',
  'count = 0',
  'words.each do |word|',
  '  if word.length > __LIMIT__',
  '    count = count + 1',
  '  end',
  'end',
  'puts count'
]

export default class extends Controller {
  static targets = ["words", "limit", "code", "array", "vars", "output", "note", "counter", "backButton", "stepButton", "playButton"]

  connect() { this.rebuild() }
  disconnect() { this.stop() }

  rebuild(event) {
    event?.preventDefault()
    this.stop()
    this.words = this.wordsTarget.value.split(",").map(w => w.trim().replace(/[^\w-]/g, "")).filter(Boolean).slice(0, 8)
    if (!this.words.length) this.words = ["oak"]
    this.limit = Math.max(0, Math.min(20, parseInt(this.limitTarget.value, 10) || 0))
    this.steps = this.trace()
    this.index = 0
    this.renderCode()
    this.render()
  }

  trace() {
    const steps = []
    const w = this.words, limit = this.limit
    const lit = `[${w.map(x => `"${x}"`).join(", ")}]`
    let count
    const snap = (line, note, extra = {}) => steps.push({ line, note, words: w, count, output: extra.output || "", word: extra.word, at: extra.at, test: extra.test })
    snap(0, `Ruby makes an array of ${w.length} word${w.length === 1 ? "" : "s"} and calls it words.`)
    count = 0
    snap(1, "count starts at 0. It will go up by one for each long word.")
    w.forEach((word, i) => {
      snap(2, `.each hands the next item to the block. word is now "${word}".`, { word, at: i })
      const long = word.length > limit
      snap(3, `"${word}".length is ${word.length}. Is ${word.length} > ${limit}? ${long ? "Yes" : "No"}.`, { word, at: i, test: long })
      if (long) {
        count += 1
        snap(4, `count = count + 1, so count goes from ${count - 1} to ${count}.`, { word, at: i, test: long })
      }
      snap(5, long ? "End of the if." : "The test was false, so Ruby skipped the line inside the if.", { word, at: i })
      snap(6, i < w.length - 1 ? "End of the block. Back to the top for the next word." : "That was the last word, so .each is done.", { word, at: i })
    })
    snap(7, `puts prints count: ${count}.`, { output: `${count}\n` })
    this.literal = lit
    return steps
  }

  renderCode() {
    this.codeTarget.innerHTML = ""
    LINES.forEach(text => {
      const li = document.createElement("li")
      const code = document.createElement("code")
      code.textContent = text.replace("__WORDS__", this.literal).replace("__LIMIT__", this.limit)
      li.append(code)
      this.codeTarget.append(li)
    })
  }

  render() {
    const s = this.steps[this.index]
    this.codeTarget.querySelectorAll("li").forEach((li, i) => {
      li.classList.toggle("is-current", i === s.line)
      li.toggleAttribute("aria-current", i === s.line)
    })
    this.arrayTarget.innerHTML = ""
    s.words.forEach((word, i) => {
      const li = document.createElement("li")
      li.className = "array-box" + (i === s.at ? " is-current" : "") + (s.at !== undefined && i < s.at ? " is-done" : "")
      li.innerHTML = `<span class="array-index">${i}</span><span class="array-value"></span>`
      li.querySelector(".array-value").textContent = `"${word}"`
      this.arrayTarget.append(li)
    })
    const vars = [["words", `${s.words.length} items`], ["count", s.count === undefined ? "(not set yet)" : String(s.count)]]
    if (s.word !== undefined) vars.push(["word", `"${s.word}"`])
    this.varsTarget.innerHTML = ""
    vars.forEach(([k, v]) => {
      const dt = document.createElement("dt"); dt.textContent = k
      const dd = document.createElement("dd"); dd.textContent = v
      this.varsTarget.append(dt, dd)
    })
    this.outputTarget.textContent = s.output || ""
    this.noteTarget.textContent = s.note
    this.counterTarget.textContent = `Step ${this.index + 1} of ${this.steps.length}`
    this.backButtonTarget.disabled = this.index === 0
    this.stepButtonTarget.disabled = this.index === this.steps.length - 1
  }

  step() {
    if (this.index < this.steps.length - 1) { this.index += 1; this.render() } else this.stop()
  }

  back() {
    if (this.index > 0) { this.index -= 1; this.render() }
  }

  reset() { this.stop(); this.index = 0; this.render() }

  play() {
    if (this.timer) return this.stop()
    if (this.index >= this.steps.length - 1) this.index = 0
    this.playButtonTarget.textContent = "Pause"
    const delay = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 2200 : 1100
    this.timer = setInterval(() => this.step(), delay)
  }

  stop() {
    clearInterval(this.timer)
    this.timer = null
    if (this.hasPlayButtonTarget) this.playButtonTarget.textContent = "Play"
  }
}
