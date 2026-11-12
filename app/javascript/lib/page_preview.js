// The web page workbench: the preview and its checks. The checks look at the page the student's HTML
// and CSS made (the preview's document), and only ever say pass or not yet,
// with a plain sentence about what the page has now. No solutions live here.

const MARK = "data-classroom-preview" // on elements the classroom added, which never count

// "h1 { color }" names an element and one of its CSS properties.
export function styleCall(call) {
  const found = String(call ?? "").match(/^\s*(.+?)\s*\{\s*([a-zA-Z-]+)\s*\}\s*$/)
  return found ? { selector: found[1], property: found[2].toLowerCase() } : null
}

const squash = text => String(text ?? "").replace(/\s+/g, " ").trim()
const clip = text => text.length > 80 ? `${text.slice(0, 77)}…` : text

// Browsers report colours as rgb(...). Students write #B87333, so show that.
export function showValue(value) {
  return String(value).replace(/rgba?\(\s*(\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\s*\)/g, (all, r, g, b, a) => {
    if (a !== undefined && Number(a) === 0) return "transparent"
    if (a !== undefined && Number(a) !== 1) return all
    return `#${[r, g, b].map(n => Number(n).toString(16).padStart(2, "0")).join("")}`
  })
}

function all(doc, selector) {
  try { return [...doc.querySelectorAll(selector)].filter(el => !el.hasAttribute(MARK)) } catch (_) { return null }
}

const unreadable = { ok: false, plain: true, actual: "This check couldn't be read. Tell your professor." }
const missing = { ok: false, plain: true, actual: "That isn't on the page yet." }

// What the browser makes of a value: the same element kind, in the same
// place, with the value set directly on it. So #B87333 and rgb(184, 115, 51)
// compare equal, and 2em means what it means for that element.
function resolved(doc, view, el, property, value) {
  const probe = doc.createElement(el.tagName)
  probe.setAttribute(MARK, "")
  probe.style.setProperty(property, value)
  if (!probe.style.getPropertyValue(property)) return null // not a value CSS knows
  el.parentNode.insertBefore(probe, el.nextSibling)
  try { return view.getComputedStyle(probe).getPropertyValue(property) } finally { probe.remove() }
}

function judge(doc, view, check) {
  switch (check.type) {
    case "page_has": {
      const found = all(doc, check.call)
      if (!found) return unreadable
      const wanted = /^\d+$/.test(String(check.expected ?? "").trim()) ? Number(check.expected) : null
      const ok = wanted === null ? found.length > 0 : found.length === wanted
      if (ok) return { ok: true, plain: true }
      return { ok: false, plain: true, actual: found.length === 0 ? "The page doesn't have this yet." : `The page has ${found.length} of these. It needs ${wanted}.` }
    }
    case "text_is": {
      const found = all(doc, check.call)
      if (!found) return unreadable
      if (!found.length) return missing
      const text = squash(found[0].textContent)
      if (text === squash(check.expected)) return { ok: true, plain: true }
      return { ok: false, plain: true, actual: text === "" ? "It's empty right now." : `Right now it says “${clip(text)}”.` }
    }
    case "style_is": {
      const call = styleCall(check.call)
      const found = call && all(doc, call.selector)
      if (!found) return unreadable
      if (!found.length) return missing
      const now = view.getComputedStyle(found[0]).getPropertyValue(call.property)
      const wanted = resolved(doc, view, found[0], call.property, check.expected)
      if (wanted === null) return unreadable
      if (now === wanted) return { ok: true, plain: true }
      return { ok: false, plain: true, actual: now ? `Right now its ${call.property} is ${showValue(now)}.` : `It has no ${call.property} yet.` }
    }
    default: return null // the classroom judges the other kinds itself
  }
}

export function judgePage(doc, view, checks = []) {
  return checks.map(check => judge(doc, view, check))
}

// The student's HTML, made safe to show: nothing outside the page is fetched
// and no script runs (the preview frame is sandboxed too). The page is parsed
// and written back the way a browser reads it, so a missing doctype or body
// behaves here as it would in a real tab.
const POLICY = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:"
export function previewDocument(code, Parser = globalThis.DOMParser, turn = "") {
  const doc = new (Parser || globalThis.DOMParser)().parseFromString(String(code ?? ""), "text/html")
  const meta = doc.createElement("meta")
  meta.setAttribute("http-equiv", "Content-Security-Policy")
  meta.setAttribute("content", POLICY)
  meta.setAttribute(MARK, turn) // which draw this is, so a late one is never mistaken for the newest
  doc.head.prepend(meta)
  return `${doc.doctype ? "<!DOCTYPE html>\n" : ""}${doc.documentElement.outerHTML}`
}

// Shows the student's HTML and CSS in the preview frame and answers the page
// checks. It stands where a language's runner stands for the other editors,
// so it answers the same calls (warm, run, dispose).
export class PagePreview {
  constructor({ frame, onStatus = () => {}, onLink = () => {} }) {
    this.frame = frame
    this.onStatus = onStatus
    this.onLink = onLink
    this.history = []
    this.turn = 0
  }

  warm() { this.onStatus("Ready", "ok"); return Promise.resolve() }
  dispose() { this.giveUp?.() }

  // Draws the page. Resolves with its document once the frame has loaded it,
  // or with null if a newer draw took its place.
  show(code) {
    const turn = String(++this.turn)
    this.giveUp?.()
    return new Promise(resolve => {
      const finish = doc => {
        this.frame.removeEventListener("load", loaded)
        clearTimeout(timer)
        if (this.giveUp === replaced) this.giveUp = null
        resolve(doc)
      }
      const replaced = () => finish(null)
      const loaded = () => {
        const doc = this.frame.contentDocument
        if (doc?.querySelector(`meta[${MARK}]`)?.getAttribute(MARK) !== turn) return // an older page arriving late
        // A link in the preview would swap the page for another site. Keep the student's page.
        doc.addEventListener("click", event => {
          if (event.target.closest?.("a[href]")) { event.preventDefault(); this.onLink() }
        })
        finish(doc)
      }
      const timer = setTimeout(replaced, 3000)
      this.giveUp = replaced
      this.frame.addEventListener("load", loaded)
      this.frame.srcdoc = previewDocument(code, undefined, turn)
    })
  }

  async run(code, checks = []) {
    const doc = await this.show(code)
    if (!doc) return { stdout: "", error: null, checks: checks.map(() => null) }
    return { stdout: "", error: null, checks: judgePage(doc, this.frame.contentWindow, checks) }
  }

  // What the browser quietly fixed or skipped in this page.
  notes(code) {
    const css = this.frame.contentWindow?.CSS || globalThis.CSS
    return pageNotes(code, css?.supports ? (property, value) => css.supports(property, value) : undefined)
  }
}

// Notes on mistakes a browser fixes or skips without a word ----------------------
// A browser never complains about HTML or CSS: it drops a rule it can't read
// and rebuilds tags that don't match. These notes say, in plain words and with
// line numbers, what it quietly did. They are information, not failed checks,
// and they describe what is there, never what to type instead.

const VOID = new Set("area base br col embed hr img input link meta source track wbr".split(" "))
const MAY_STAY_OPEN = new Set("html head body p li dt dd option tr td th thead tbody tfoot colgroup caption".split(" "))
const NEVER_INSIDE_ITSELF = new Set("h1 h2 h3 h4 h5 h6 title a button label textarea select".split(" "))

export function pageNotes(code, supports = () => true) {
  const source = String(code ?? "")
  const notes = []
  const lineAt = index => source.slice(0, index).split("\n").length
  const note = (index, text) => notes.push({ line: lineAt(index), text })
  const sheets = []
  const open = [] // { name, at }

  for (let i = 0; i < source.length; i++) {
    if (source[i] !== "<") continue
    if (source.startsWith("<!--", i)) {
      const end = source.indexOf("-->", i + 4)
      if (end < 0) { note(i, "A comment starts here and is never closed with -->, so the browser treats everything after it as part of the comment."); break }
      i = end + 2
      continue
    }
    if (source[i + 1] === "!") { const end = source.indexOf(">", i); i = end < 0 ? source.length : end; continue }
    const closing = source[i + 1] === "/"
    const named = source.slice(i + (closing ? 2 : 1)).match(/^[a-zA-Z][a-zA-Z0-9-]*/)
    if (!named) continue // a bare < in the text
    const name = named[0].toLowerCase()

    // Find where the tag ends, minding quotes around attribute values.
    let at = i + (closing ? 2 : 1) + name.length, end = -1
    while (at < source.length) {
      const ch = source[at]
      if (ch === ">") { end = at; break }
      if (ch === "<") { note(i, `This ${closing ? "closing " : ""}<${closing ? "/" : ""}${name}> tag has no > to finish it, so the browser read what follows as part of the tag.`); end = at - 1; break }
      if (ch === '"' || ch === "'") {
        let close = at + 1
        while (close < source.length && source[close] !== ch && source[close] !== "\n" && source[close] !== "<") close += 1
        if (source[close] !== ch) {
          note(i, `A quote opens in this <${name}> tag and never closes, so the browser read the text after it as part of the tag.`)
          const stop = source.indexOf(">", at)
          end = stop < 0 ? source.length - 1 : stop
          break
        }
        at = close
      }
      at += 1
    }
    if (end < 0) { if (at >= source.length) note(i, `This <${closing ? "/" : ""}${name}> tag has no > to finish it.`); end = source.length - 1 }

    if (closing) {
      const found = open.map(o => o.name).lastIndexOf(name)
      if (found < 0) note(i, `There's a closing </${name}> here with no <${name}> open, so the browser ignored it.`)
      else {
        const between = open.slice(found + 1).filter(o => !MAY_STAY_OPEN.has(o.name))
        if (between.length) note(i, `</${name}> closes here while the <${between.at(-1).name}> from line ${lineAt(between.at(-1).at)} is still open, so the browser closed that one for you.`)
        open.length = found
      }
    } else if (!VOID.has(name) && source[end - 1] !== "/") {
      if (NEVER_INSIDE_ITSELF.has(name) && open.at(-1)?.name === name) {
        note(i, `A second <${name}> opens here before the one ${lineAt(open.at(-1).at) === lineAt(i) ? "earlier on this line" : `on line ${lineAt(open.at(-1).at)}`} was closed. The browser made two of them. A closing tag has a slash: </${name}>.`)
        open.pop() // read it as the close it was probably meant to be
      } else if (name === "style" || name === "script") {
        const stop = source.toLowerCase().indexOf(`</${name}`, end + 1)
        if (stop < 0) note(i, `<${name}> opens here and is never closed, so the browser read the rest of the page as part of it.`)
        if (name === "style" && stop >= 0) sheets.push({ from: end + 1, to: stop })
        if (stop < 0) break
        end = source.indexOf(">", stop); if (end < 0) end = source.length - 1
      } else open.push({ name, at: i })
    }
    i = end
  }
  open.filter(o => !MAY_STAY_OPEN.has(o.name)).forEach(o => note(o.at, `<${o.name}> opens here and is never closed, so the browser closed it for you at the end.`))

  sheets.forEach(({ from, to }) => styleNotes(source, from, to, supports, note))
  return notes.sort((a, b) => a.line - b.line)
}

// One style sheet: rules, and inside them one declaration per semicolon.
function styleNotes(source, from, to, supports, note) {
  // Blank out comments, keeping every character's place so line numbers hold.
  const text = source.slice(0, from).replace(/[^\n]/g, " ") + source.slice(from, to).replace(/\/\*[\s\S]*?(\*\/|$)/g, all => all.replace(/[^\n]/g, " "))
  const firstInk = (a, b) => { let i = a; while (i < b && /\s/.test(text[i])) i += 1; return i }
  const skipText = i => { const q = text[i]; let at = i + 1; while (at < text.length && text[at] !== q && text[at] !== "\n") at += text[at] === "\\" ? 2 : 1; return at }

  const declarations = (a, b) => {
    let start = a, depth = 0
    for (let i = a; i <= b; i++) {
      const ch = text[i]
      if (i < b && (ch === '"' || ch === "'")) { i = skipText(i); continue }
      if (ch === "(") depth += 1
      else if (ch === ")") depth = Math.max(0, depth - 1)
      if (i < b && (ch !== ";" || depth > 0)) continue
      const piece = text.slice(start, i), at = firstInk(start, i)
      start = i + 1
      if (!piece.trim() || /[{}]/.test(piece)) continue
      const parts = piece.match(/^([^:]*):([\s\S]*)$/)
      if (!parts) { note(at, `This line has no colon between a property and its value, so the browser skipped it: ${clip(squash(piece))}`); continue }
      const property = parts[1].trim().toLowerCase(), value = parts[2].trim().replace(/\s*!important$/i, "")
      if (property.startsWith("--")) continue
      if (!/^[a-z-]+$/.test(property)) { note(at, `The browser couldn't read “${clip(squash(parts[1]))}” as a property name, so it skipped this line.`); continue }
      if (value === "") { note(at, `${property} has no value after its colon, so the browser skipped it.`); continue }
      if (!supports(property, "initial")) note(at, `The browser doesn't know a property called ${property}, so it skipped this line.`)
      else if (!supports(property, value)) {
        if (/\n[^\n]*:/.test(value)) note(at, `There's no semicolon at the end of this line, so the browser read the next line as part of the value and skipped both.`)
        else note(at, `The browser doesn't accept “${clip(squash(value))}” as a value for ${property}, so it skipped this line.`)
      }
    }
  }

  const rules = (a, b) => {
    let start = a
    for (let i = a; i < b; i++) {
      const ch = text[i]
      if (ch === '"' || ch === "'") { i = skipText(i); continue }
      if (ch === "}") { note(i, "There's a } here with no rule open, so the browser skipped it."); start = i + 1; continue }
      if (ch !== "{") continue
      let depth = 1, close = i + 1
      while (close < b && depth > 0) { if (text[close] === "{") depth += 1; else if (text[close] === "}") depth -= 1; close += 1 }
      const closed = depth === 0, inner = closed ? close - 1 : b
      const selector = text.slice(start, i).trim()
      if (!closed) note(firstInk(start, i), "The rule that starts here is never closed with }, so the browser read everything after it as part of this rule.")
      if (selector === "") note(i, "This { has no selector in front of it, so the browser doesn't know what to style.")
      if (/^@(media|supports|layer|container)\b/.test(selector)) rules(i + 1, inner)
      else if (!selector.startsWith("@")) declarations(i + 1, inner)
      i = close - 1
      start = close
    }
    const left = firstInk(start, b)
    if (left < b) note(left, `This isn't inside a rule's curly brackets, so the browser skipped it: ${clip(squash(text.slice(left, b)))}`)
  }
  rules(from, to)
}
