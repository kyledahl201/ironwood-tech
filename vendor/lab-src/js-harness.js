// The classroom's JavaScript bench. The browser already runs JavaScript, so
// there is nothing to download: the student's code runs in a Web Worker (no
// page to touch), with console.log captured. The editor runs a whole program
// in a scope of its own; the console keeps names alive between entries.
// It answers in the same shapes as the Ruby, Python and SQL harnesses.

// Shows a value the way a JavaScript console does: 'text' in quotes, [ 1, 2 ], { a: 1 }.
export function inspect(value, depth = 0, seen = []) {
  if (typeof value === "string") return `'${value.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\n/g, "\\n")}'`
  if (typeof value === "number") return Object.is(value, -0) ? "-0" : String(value)
  if (typeof value === "bigint") return `${value}n`
  if (typeof value === "symbol") return value.toString()
  if (typeof value === "function") return /^class\b/.test(Function.prototype.toString.call(value)) ? `[class ${value.name || "(anonymous)"}]` : `[Function: ${value.name || "(anonymous)"}]`
  if (value === null || typeof value !== "object") return String(value)
  if (seen.includes(value)) return "[Circular]"
  const tag = Object.prototype.toString.call(value).slice(8, -1)
  if (tag === "Error") return `${value.name}: ${value.message}`
  if (tag === "Date") return isNaN(value) ? "Invalid Date" : value.toISOString()
  if (tag === "RegExp") return String(value)
  const inside = seen.concat([value])
  const show = v => inspect(v, depth + 1, inside)
  if (Array.isArray(value)) {
    if (!value.length) return "[]"
    if (depth > 2) return "[Array]"
    const items = []
    for (let i = 0; i < Math.min(value.length, 100); i++) items.push(i in value ? show(value[i]) : "<empty>")
    if (value.length > 100) items.push(`... ${value.length - 100} more`)
    return `[ ${items.join(", ")} ]`
  }
  if (tag === "Map") return value.size ? `Map(${value.size}) { ${[...value].map(([k, v]) => `${show(k)} => ${show(v)}`).join(", ")} }` : "Map(0) {}"
  if (tag === "Set") return value.size ? `Set(${value.size}) { ${[...value].map(show).join(", ")} }` : "Set(0) {}"
  if (tag === "Promise") return "Promise"
  const proto = Object.getPrototypeOf(value)
  const name = proto && proto.constructor && proto.constructor.name !== "Object" ? `${proto.constructor.name} ` : ""
  const keys = Object.keys(value)
  if (!keys.length) return `${name}{}`
  if (depth > 2) return "[Object]"
  const key = k => /^[A-Za-z_$][\w$]*$/.test(k) ? k : inspect(k)
  return `${name}{ ${keys.map(k => `${key(k)}: ${show(value[k])}`).join(", ")} }`
}

// What console.log prints: text as it is, everything else as inspect shows it.
const logged = args => args.map(a => typeof a === "string" ? a : inspect(a)).join(" ")

// Walks the code once, skipping strings, templates and comments. Returns the
// brackets left open (with their lines), the first bracket that closes
// nothing, and whether a string, template or comment is left unfinished.
export function scan(code) {
  const source = String(code ?? "")
  const open = []
  const pairs = { ")": "(", "]": "[", "}": "{" }
  let line = 1, stray = null, unfinished = null
  const templates = [] // open-bracket depth at each `${` we are inside
  for (let i = 0; i < source.length; i++) {
    const ch = source[i], two = source.slice(i, i + 2)
    if (ch === "\n") { line += 1; continue }
    if (two === "//") { const end = source.indexOf("\n", i); if (end < 0) break; i = end - 1; continue }
    if (two === "/*") {
      const end = source.indexOf("*/", i + 2)
      if (end < 0) { unfinished = { what: "comment", line }; break }
      line += source.slice(i, end).split("\n").length - 1
      i = end + 1
      continue
    }
    if (ch === "'" || ch === '"') {
      const start = line
      let at = i + 1
      while (at < source.length && source[at] !== ch && source[at] !== "\n") at += source[at] === "\\" ? 2 : 1
      if (source[at] !== ch) { unfinished = { what: "string", line: start, sameLine: true }; break }
      i = at
      continue
    }
    if (ch === "`" || (ch === "}" && templates.length && templates[templates.length - 1] === open.length)) {
      // Entering a template, or coming back into one after a ${ ... } part.
      if (ch === "}") templates.pop()
      const start = line
      let at = i + 1, closed = false
      while (at < source.length) {
        if (source[at] === "\\") { at += 2; continue }
        if (source[at] === "\n") line += 1
        if (source[at] === "`") { closed = true; break }
        if (source[at] === "$" && source[at + 1] === "{") { templates.push(open.length); at += 1; closed = true; break }
        at += 1
      }
      if (!closed) { unfinished = { what: "template", line: start }; break }
      i = at
      continue
    }
    if (ch === "(" || ch === "[" || ch === "{") open.push({ ch, line })
    else if (pairs[ch]) {
      if (open.length && open[open.length - 1].ch === pairs[ch]) open.pop()
      else if (!stray) stray = { ch, line, wanted: open.length ? open[open.length - 1] : null }
    }
  }
  if (templates.length && !unfinished) unfinished = { what: "template", line }
  return { open, stray, unfinished }
}

// A console entry is finished when every bracket, template and comment is closed.
export function complete(code) {
  const { open, stray, unfinished } = scan(code)
  if (stray) return true // it's wrong, not unfinished: let JavaScript say so
  if (unfinished) return !!unfinished.sameLine
  return open.length === 0
}

// In the console, names must outlast the entry that made them. let, const and
// class at the top of an entry are scoped to that entry alone, so they are
// turned into var (and class X into var X = class X) before it runs.
export function keepNames(code) {
  const source = String(code)
  let out = "", depth = 0, start = true
  for (let i = 0; i < source.length; i++) {
    const ch = source[i], two = source.slice(i, i + 2)
    if (two === "//") { const end = source.indexOf("\n", i); const stop = end < 0 ? source.length : end; out += source.slice(i, stop); i = stop - 1; continue }
    if (two === "/*") { const end = source.indexOf("*/", i + 2); const stop = end < 0 ? source.length : end + 2; out += source.slice(i, stop); i = stop - 1; continue }
    if (ch === "'" || ch === '"' || ch === "`") {
      let at = i + 1
      while (at < source.length && source[at] !== ch) at += source[at] === "\\" ? 2 : 1
      out += source.slice(i, at + 1)
      i = at
      start = false
      continue
    }
    if (depth === 0 && start) {
      const word = source.slice(i).match(/^(let|const)(?=\s)|^class\s+([A-Za-z_$][\w$]*)/)
      if (word) {
        out += word[2] ? `var ${word[2]} = class ${word[2]}` : "var"
        i += word[0].length - 1
        start = false
        continue
      }
    }
    if ("([{".includes(ch)) depth += 1
    else if (")]}".includes(ch)) depth = Math.max(0, depth - 1)
    if (ch === ";" || ch === "\n" || (ch === "}" && depth === 0)) start = true
    else if (!/\s/.test(ch)) start = false
    out += ch
  }
  return out
}

const DECLARES = /^\s*(let|const|var|function|class|if|for|while|do|switch|try|import|export)\b/

// What JavaScript said, in plainer words. Browsers word errors differently
// (Chrome's "x is not defined" is Safari's "Can't find variable: x"), so each
// case reads both. The raw message is always shown as well.
export function friendly(name, message, code = "") {
  const text = String(message || "")
  let m
  if (name === "ReferenceError") {
    if ((m = text.match(/^Cannot access '(.+?)' before initialization|^Cannot access uninitialized variable/))) return `${m[1] ? `${m[1]} is` : "A name is"} used before the line that declares it. Move the let or const line above where it's used.`
    if ((m = text.match(/^(.+?) is not defined|^Can't find variable: (.+)/))) return `JavaScript doesn't know the name ${m[1] || m[2]}. Check the spelling, or declare it first with let or const. If it's meant to be text, put it in quotes.`
  }
  if (name === "TypeError") {
    if ((m = text.match(/^(.+?) is not a function/))) return `${m[1]} isn't a function, so it can't be called with ( ). Check the spelling and capitals of the name.`
    if ((m = text.match(/^Cannot read propert(?:y|ies) of (undefined|null) \(reading '(.+?)'\)/))) return `You asked for .${m[2]} on something that is ${m[1]}. Look at what's just before the dot: it has no value yet.`
    if ((m = text.match(/^(undefined|null) is not an object \(evaluating '(.+?)'\)/))) return `You asked for a property on something that is ${m[1]}, in ${m[2]}. Look at what's just before the dot: it has no value yet.`
    if (/^Assignment to constant variable|^Attempted to assign to readonly property/.test(text)) return "A const can't be given a new value. Use let for a name whose value changes."
    if ((m = text.match(/^Cannot set propert(?:y|ies) of (undefined|null)/))) return `You tried to set a property on something that is ${m[1]}. Look at what's just before the dot.`
    if ((m = text.match(/^(.+?) is not iterable/))) return `${m[1]} can't be looped over with for...of. That works on arrays and text.`
  }
  if (name === "RangeError" && /call stack|recursion/i.test(text)) return "A function kept calling itself and never stopped. Check the case where it should stop."
  if (name === "SyntaxError") {
    if ((m = text.match(/^Identifier '(.+?)' has already been declared|^Cannot declare a (?:let|const) variable twice: '(.+?)'/))) return `${m[1] || m[2]} is declared twice. Declare a name once; after that, change it without let or const.`
    const { open, stray, unfinished } = scan(code)
    if (unfinished?.what === "string") return `The text that starts on line ${unfinished.line} is missing its closing quote.`
    if (unfinished?.what === "template") return `The backtick text that starts on line ${unfinished.line} is never closed.`
    if (unfinished?.what === "comment") return `The /* comment that starts on line ${unfinished.line} is never closed with */.`
    if (stray) return stray.wanted ? `The ${stray.ch} on line ${stray.line} doesn't match the ${stray.wanted.ch} opened on line ${stray.wanted.line}.` : `The ${stray.ch} on line ${stray.line} closes something that was never opened.`
    if (open.length) return `The ${open[open.length - 1].ch} opened on line ${open[open.length - 1].line} is never closed.`
    if (/^Missing initializer in const declaration|^const declared variable .* must have an initializer|^Unexpected token '?;'?\. const declared/.test(text)) return "A const needs its value on the same line: const name = value."
    return "JavaScript couldn't read that. Look for a missing comma, a missing operator, or a misspelled keyword."
  }
  return "JavaScript stopped with an error."
}

// offset: lines the wrapper adds above the student's first line.
function report(error, code, offset = 0) {
  if (!error || typeof error.message !== "string") {
    return { friendly: "Your code threw a value that isn't an Error.", raw: `Uncaught ${inspect(error)}` }
  }
  const name = error.name || "Error"
  const lines = String(code).split("\n").length
  let line = null
  // Chrome ends a frame with "<anonymous>:3:5)", Firefox with "> Function:3:5" or "> eval:3:5". Safari gives no line.
  for (const m of String(error.stack || "").matchAll(/<anonymous>:(\d+):\d+\)?$|> (?:Function|eval):(\d+):\d+$/gm)) {
    const n = Number(m[1] || m[2]) - offset
    if (n >= 1 && n <= lines) { line = n; break }
  }
  if (name === "SyntaxError" || lines === 1) line = null // browsers don't say where a syntax error is (the plain-words message looks for it), and a one-line entry needs no line number
  return { friendly: friendly(name, error.message, code), raw: `${name}: ${error.message}${line ? ` (line ${line})` : ""}` }
}

// realm: where the student's code runs. In the browser that is the worker's
// own global scope; the tests pass a separate one.
//   evaluate(code): runs code in the realm's global scope, returns its value
//   Function: the realm's Function constructor
//   global: the realm's global object
export class JsBench {
  constructor(realm) {
    this.realm = realm
    this.out = []
    this.builtin = new Set(Object.getOwnPropertyNames(realm.global))
    const write = (...args) => { this.out.push(`${logged(args)}\n`) }
    this.console = { log: write, info: write, warn: write, error: write, debug: write,
                     table: value => write(value), clear() {}, assert: (ok, ...args) => { if (!ok) write("Assertion failed:", ...args) } }
    realm.global.console = this.console
  }

  take() { const text = this.out.join(""); this.out = []; return text.length > 100000 ? `${text.slice(0, 100000)}\n… (output cut short)\n` : text }

  expected(text) {
    try { return { value: this.realm.evaluate(`(${text}\n)`) } } catch (_) { return { value: String(text) } }
  }

  same(a, b) {
    if (typeof a === "number" && typeof b === "number") return a === b || (a !== a && b !== b) || Math.abs(a - b) < 1e-9
    if (a === null || b === null || typeof a !== "object" || typeof b !== "object") return a === b
    if (Array.isArray(a) !== Array.isArray(b)) return false
    const keys = Object.keys(a)
    return keys.length === Object.keys(b).length && keys.every(k => Object.prototype.hasOwnProperty.call(b, k) && this.same(a[k], b[k]))
  }

  // The editor: the whole program, in a scope of its own. Async so that
  // promises and zero-delay timers get to print before the output is read.
  async run({ code = "", checks = [] }) {
    this.take()
    const { Function: Fn } = this.realm
    let look
    try {
      new Fn("console", code) // read it on its own first, so a mistake is reported as the student's
      look = new Fn("console", `${code}\n;return __iw => eval(__iw)`)(this.console)
      await new Promise(resolve => setTimeout(resolve, 0))
    } catch (e) {
      return { stdout: this.take(), error: report(e, code, 2), checks: checks.map(() => null) }
    }
    const stdout = this.take()
    const results = checks.map(check => {
      if (check.type !== "method_returns" && check.type !== "method_stdout_empty" && check.type !== "value_is") return null
      let value, error = null
      try { value = look(`(${check.call}\n)`) } catch (e) { error = report(e, check.call).friendly }
      const printed = this.take()
      if (check.type === "method_stdout_empty") return { ok: !error && printed === "", expected: "(prints nothing)", actual: error || (printed === "" ? "(prints nothing)" : printed) }
      const want = this.expected(check.expected).value
      return { ok: !error && this.same(value, want), expected: inspect(want), actual: error || inspect(value) }
    })
    return { stdout, error: null, checks: results }
  }

  // The console: { op: "eval" | "values" | "reset" }.
  console_({ op, line = "", checks = [] }) {
    const { evaluate, global } = this.realm
    if (op === "reset") {
      for (const name of Object.getOwnPropertyNames(global)) if (!this.builtin.has(name)) { try { delete global[name] } catch (_) { global[name] = undefined } }
      global.console = this.console
      this.take()
      return {}
    }
    if (op === "values") {
      return { checks: checks.map(check => {
        let value
        try { value = evaluate(`(${check.call}\n)`) } catch (_) { this.take(); return { ok: false, actual: "not there yet" } }
        const printed = this.take()
        if (check.type === "method_stdout_empty") return { ok: printed === "", expected: "(prints nothing)", actual: printed === "" ? "(prints nothing)" : printed }
        const want = this.expected(check.expected).value
        return { ok: this.same(value, want), expected: inspect(want), actual: inspect(value) }
      }) }
    }
    if (!complete(line)) return { stdout: "", value: null, incomplete: true, error: null }
    this.take()
    const source = keepNames(line)
    let value
    try {
      // An entry that is just { ... } is an object to show, not a block to run.
      if (/^\s*\{[\s\S]*\}\s*;?\s*$/.test(source)) { try { value = evaluate(`(${source.replace(/;\s*$/, "")}\n)`) } catch (_) { value = evaluate(source) } }
      else value = evaluate(source)
    } catch (e) {
      return { stdout: this.take(), value: null, incomplete: false, error: report(e, line) }
    }
    const stdout = this.take()
    // A statement (let, a loop) or a line that printed has nothing more to show.
    const quiet = value === undefined && (DECLARES.test(line) || stdout !== "")
    if (!quiet) { try { global._ = value } catch (_) { /* fine */ } }
    return { stdout, value: quiet ? null : inspect(value), incomplete: false, error: null }
  }
}
