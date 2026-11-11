import { Controller } from "@hotwired/stimulus"

// Step-through visualizers in one frame: step, back, play. Each program builds
// its code lines and a list of steps; a step names the line Ruby is on, a
// plain-English note and the panels to draw (array, hash, call stack, variables,
// output). The examples are deliberately not lab exercises.

const word = text => String(text).trim().replace(/[^\w-]/g, "").slice(0, 12)
const int = (text, max = 99) => Math.max(0, Math.min(max, parseInt(text, 10) || 0))
const q = text => `"${text}"`

const PROGRAMS = {
  // Count the words longer than a limit with .each.
  loop(inputs) {
    let words = inputs.words.split(",").map(word).filter(Boolean).slice(0, 8)
    if (!words.length) words = ["oak"]
    const limit = int(inputs.limit, 20)
    const lines = [
      `words = [${words.map(q).join(", ")}]`, "count = 0", "words.each do |word|",
      `  if word.length > ${limit}`, "    count = count + 1", "  end", "end", "puts count"
    ]
    const steps = []
    let count
    const snap = (line, note, { at, current, output = "" } = {}) => steps.push({
      line, note, panels: [
        { kind: "boxes", title: "The array", items: words.map((w, i) => ({ top: i, value: q(w) })), at },
        { kind: "vars", title: "Variables", rows: [["words", `${words.length} items`], ["count", count === undefined ? "(not set yet)" : count], ...(current === undefined ? [] : [["word", q(current)]])] },
        { kind: "output", text: output }
      ]
    })
    snap(0, `Ruby makes an array of ${words.length} word${words.length === 1 ? "" : "s"} and calls it words.`)
    count = 0
    snap(1, "count starts at 0. It will go up by one for each long word.")
    words.forEach((w, i) => {
      const here = { at: i, current: w }
      snap(2, `.each hands the next item to the block. word is now ${q(w)}.`, here)
      const long = w.length > limit
      snap(3, `${q(w)}.length is ${w.length}. Is ${w.length} > ${limit}? ${long ? "Yes" : "No"}.`, here)
      if (long) { count += 1; snap(4, `count = count + 1, so count goes from ${count - 1} to ${count}.`, here) }
      snap(5, long ? "End of the if." : "The test was false, so Ruby skipped the line inside the if.", here)
      snap(6, i < words.length - 1 ? "End of the block. Back to the top for the next word." : "That was the last word, so .each is done.", here)
    })
    snap(7, `puts prints count: ${count}.`, { output: `${count}\n` })
    return { lines, steps }
  },

  // Build a hash, add a pair, look a key up.
  hash(inputs) {
    let pairs = inputs.pairs.split(",").map(p => p.split(":")).map(([k, v]) => [word(k || ""), int(v)]).filter(([k]) => k).slice(0, 5)
    pairs = [...new Map(pairs)] // a hash keeps one value per key
    if (!pairs.length) pairs = [["oak", 4]]
    const key = word(inputs.key) || "owl"
    const lines = [
      `prices = { ${pairs.map(([k, v]) => `${q(k)} => ${v}`).join(", ")} }`, `prices["pine"] = 6`, `item = ${q(key)}`,
      "if prices.key?(item)", "  puts prices[item]", "else", '  puts "No price for #{item}"', "end"
    ]
    const steps = []
    let table = pairs.map(p => [...p])
    let item
    const snap = (line, note, { at, miss = false, output = "" } = {}) => steps.push({
      line, note, panels: [
        { kind: "pairs", title: "The hash: key → value", rows: table.map(([k, v]) => [q(k), v]), at, miss },
        { kind: "vars", title: "Variables", rows: [["prices", `${table.length} pairs`], ...(item === undefined ? [] : [["item", q(item)]])] },
        { kind: "output", text: output }
      ]
    })
    snap(0, `Ruby builds a hash with ${table.length} pair${table.length === 1 ? "" : "s"}. Each key points to one value.`)
    const existing = table.findIndex(([k]) => k === "pine")
    if (existing >= 0) table[existing][1] = 6; else table = [...table, ["pine", 6]]
    snap(1, existing >= 0 ? `"pine" is already a key, so its value is replaced with 6. A key never appears twice.` : `"pine" isn't a key yet, so Ruby adds a new pair: "pine" → 6.`, { at: existing >= 0 ? existing : table.length - 1 })
    item = key
    snap(2, `item is now ${q(key)}. That's the key we'll look for.`)
    const found = table.findIndex(([k]) => k === key)
    if (found >= 0) {
      snap(3, `Does prices have the key ${q(key)}? Yes. Ruby doesn't read the pairs one by one: it uses the key to jump straight to its pair.`, { at: found })
      snap(4, `prices[item] hands back the value for ${q(key)}: ${table[found][1]}. puts prints it.`, { at: found, output: `${table[found][1]}\n` })
      snap(7, "End of the if. The else branch never ran.", { output: `${table[found][1]}\n` })
    } else {
      snap(3, `Does prices have the key ${q(key)}? No. Asking for prices[${q(key)}] here would give nil, which is why the code checks first.`, { miss: true })
      snap(5, "The test was false, so Ruby jumps to the else branch.", { miss: true })
      snap(6, `puts prints the message with item filled in.`, { miss: true, output: `No price for ${key}\n` })
      snap(7, "End of the if.", { output: `No price for ${key}\n` })
    }
    return { lines, steps }
  },

  // One method calling another: frames stack up, return values travel back down.
  stack(inputs) {
    const a = int(inputs.a), b = int(inputs.b)
    const lines = [
      "def square(n)", "  n * n", "end", "", "def sum_of_squares(a, b)", "  square(a) + square(b)", "end", "", `puts sum_of_squares(${a}, ${b})`
    ]
    const steps = []
    const main = { name: "main program", vars: [] }
    const snap = (line, note, frames, { output = "", returning } = {}) => steps.push({
      line, note, panels: [
        { kind: "stack", title: "Call stack (newest on top)", frames: frames.map(f => ({ ...f, vars: [...f.vars] })), returning },
        { kind: "output", text: output }
      ]
    })
    const sa = a * a, sb = b * b, total = sa + sb
    snap(0, "Ruby reads the definition of square and remembers it. Nothing runs yet.", [main])
    snap(4, "Same for sum_of_squares: defined, not run.", [main])
    snap(8, `Now something runs. To print anything, Ruby first has to work out sum_of_squares(${a}, ${b}), so it calls the method.`, [main])
    const outer = { name: "sum_of_squares", vars: [["a", a], ["b", b]] }
    snap(4, `A new frame goes on the stack for sum_of_squares, with a = ${a} and b = ${b}. The main program waits underneath.`, [main, outer])
    snap(5, `This line needs square(a) first, so sum_of_squares pauses and calls square(${a}).`, [main, outer])
    snap(0, `Another frame on top: square, with n = ${a}. Each call gets its own n.`, [main, outer, { name: "square", vars: [["n", a]] }])
    snap(1, `n * n is ${a} * ${a} = ${sa}. The last value in a method is what it returns.`, [main, outer, { name: "square", vars: [["n", a]] }], { returning: sa })
    outer.vars.push(["square(a)", sa])
    snap(5, `square's frame is gone, and ${sa} came back to exactly where the call was. Now the same line needs square(b).`, [main, outer])
    snap(0, `A fresh square frame, this time with n = ${b}. The earlier n is long gone.`, [main, outer, { name: "square", vars: [["n", b]] }])
    snap(1, `n * n is ${b} * ${b} = ${sb}.`, [main, outer, { name: "square", vars: [["n", b]] }], { returning: sb })
    outer.vars.push(["square(b)", sb])
    snap(5, `Back again with ${sb}. Now the line can finish: ${sa} + ${sb} = ${total}.`, [main, outer], { returning: total })
    snap(8, `sum_of_squares returns ${total} and its frame comes off the stack. Only the main program is left.`, [main])
    snap(8, `puts prints ${total}. Notice that neither method printed anything: they returned values, and the main program did the printing.`, [main], { output: `${total}\n` })
    return { lines, steps }
  }
}

export default class extends Controller {
  static targets = ["input", "code", "state", "note", "counter", "backButton", "stepButton", "playButton"]
  static values = { program: String }

  connect() { this.rebuild() }
  disconnect() { this.stop() }

  rebuild(event) {
    event?.preventDefault()
    this.stop()
    const inputs = Object.fromEntries(this.inputTargets.map(i => [i.name, i.value]))
    const { lines, steps } = PROGRAMS[this.programValue](inputs)
    this.steps = steps
    this.index = 0
    this.codeTarget.innerHTML = ""
    lines.forEach(text => {
      const li = document.createElement("li")
      const code = document.createElement("code")
      code.textContent = text || " "
      li.append(code)
      this.codeTarget.append(li)
    })
    this.render()
  }

  render() {
    const step = this.steps[this.index]
    this.codeTarget.querySelectorAll("li").forEach((li, i) => {
      li.classList.toggle("is-current", i === step.line)
      li.toggleAttribute("aria-current", i === step.line)
    })
    this.stateTarget.innerHTML = ""
    step.panels.forEach(panel => this.stateTarget.append(...this.draw(panel)))
    this.noteTarget.textContent = step.note
    this.counterTarget.textContent = `Step ${this.index + 1} of ${this.steps.length}`
    this.backButtonTarget.disabled = this.index === 0
    this.stepButtonTarget.disabled = this.index === this.steps.length - 1
  }

  draw(panel) {
    const title = this.el("h2", "lab-sub", panel.title || "Output")
    switch (panel.kind) {
      case "boxes": {
        const list = this.el("ol", "array-boxes")
        panel.items.forEach((item, i) => {
          const li = this.el("li", "array-box" + (i === panel.at ? " is-current" : "") + (panel.at !== undefined && i < panel.at ? " is-done" : ""))
          li.append(this.el("span", "array-index", item.top), this.el("span", "array-value", item.value))
          list.append(li)
        })
        return [title, list]
      }
      case "pairs": {
        const list = this.el("ol", "pair-rows" + (panel.miss ? " is-miss" : ""))
        panel.rows.forEach(([k, v], i) => {
          const li = this.el("li", "pair-row" + (i === panel.at ? " is-current" : ""))
          li.append(this.el("span", "pair-key", k), this.el("span", "pair-arrow", "→"), this.el("span", "pair-value", v))
          list.append(li)
        })
        if (panel.miss) list.append(this.el("li", "pair-row pair-missing", "No pair has that key."))
        return [title, list]
      }
      case "stack": {
        const list = this.el("ol", "stack-frames")
        const frames = [...panel.frames].reverse()
        frames.forEach((frame, i) => {
          const li = this.el("li", "stack-frame" + (i === 0 ? " is-top" : ""))
          li.append(this.el("strong", "stack-name", frame.name))
          const vars = this.el("span", "stack-vars", frame.vars.length ? frame.vars.map(([k, v]) => `${k} = ${v}`).join("   ") : (i === 0 ? "running" : "waiting"))
          li.append(vars)
          if (i === 0 && panel.returning !== undefined) li.append(this.el("span", "stack-return", `returns ${panel.returning}`))
          list.append(li)
        })
        return [title, list]
      }
      case "vars": {
        const dl = this.el("dl", "vars")
        panel.rows.forEach(([k, v]) => dl.append(this.el("dt", "", k), this.el("dd", "", v)))
        return [title, dl]
      }
      default:
        return [title, this.el("pre", "console-body small-console", panel.text || "")]
    }
  }

  el(tag, className, text) {
    const node = document.createElement(tag)
    if (className) node.className = className
    if (text !== undefined) node.textContent = String(text)
    return node
  }

  step() {
    if (this.index < this.steps.length - 1) { this.index += 1; this.render() }
    if (this.index >= this.steps.length - 1) this.stop()
  }

  back() {
    if (this.index > 0) { this.index -= 1; this.render() }
  }

  reset() { this.stop(); this.index = 0; this.render() }

  play() {
    if (this.timer) return this.stop()
    if (this.index >= this.steps.length - 1) this.index = 0
    this.render()
    this.playButtonTarget.textContent = "Pause"
    const delay = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 2400 : 1300
    this.timer = setInterval(() => this.step(), delay)
  }

  stop() {
    clearInterval(this.timer)
    this.timer = null
    if (this.hasPlayButtonTarget) this.playButtonTarget.textContent = "Play"
  }
}
