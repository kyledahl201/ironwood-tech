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
}
