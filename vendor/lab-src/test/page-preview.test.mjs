// The web page workbench's checks and preview, on a real DOM (jsdom).
import { test } from "node:test"
import assert from "node:assert/strict"
import { JSDOM } from "jsdom"
import { judgePage, previewDocument, styleCall, showValue, PagePreview } from "../../../app/javascript/lib/page_preview.js"
import { evaluateChecks } from "../../../app/javascript/lib/checks.js"

const Parser = new JSDOM("").window.DOMParser
globalThis.DOMParser = Parser // the browser has one; the preview uses it when it draws
// Draw a page the way the classroom does, and hand back its document and window.
function page(code) {
  const dom = new JSDOM(previewDocument(code, Parser))
  return [dom.window.document, dom.window]
}
const judge = (code, ...checks) => judgePage(...page(code), checks)

const PAGE = `<!DOCTYPE html>
<html>
  <head>
    <title>Made up</title>
    <style>
      h1 { color: #B87333; font-size: 2em; }
      .note { text-align: center; background-color: rgb(245, 243, 239); }
    </style>
  </head>
  <body>
    <h1>  Made   up
      page </h1>
    <p class="note">One</p>
    <ul><li>a</li><li>b</li></ul>
    <a href="https://example.com/">out</a>
  </body>
</html>`

test("page_has counts what the student's page has", () => {
  assert.deepEqual(judge(PAGE, { type: "page_has", call: "ul li", expected: "2" }), [{ ok: true, plain: true }])
  assert.deepEqual(judge(PAGE, { type: "page_has", call: "p.note", expected: "" }), [{ ok: true, plain: true }])
  assert.deepEqual(judge(PAGE, { type: "page_has", call: "ul li", expected: "3" }), [{ ok: false, plain: true, actual: "The page has 2 of these. It needs 3." }])
  assert.deepEqual(judge(PAGE, { type: "page_has", call: "table", expected: "" }), [{ ok: false, plain: true, actual: "The page doesn't have this yet." }])
  assert.deepEqual(judge(PAGE, { type: "page_has", call: "h2", expected: "1" }), [{ ok: false, plain: true, actual: "The page doesn't have this yet." }])
  assert.deepEqual(judge(PAGE, { type: "page_has", call: "a[href^='https://']", expected: "1" }), [{ ok: true, plain: true }])
  // A selector the browser can't read is the lesson's mistake, said plainly.
  assert.match(judge(PAGE, { type: "page_has", call: "ul >", expected: "" })[0].actual, /couldn't be read/)
})

test("the classroom's own additions never count as the student's", () => {
  // The preview adds one meta tag for safety; a page with no meta of its own has none.
  assert.equal(judge(PAGE, { type: "page_has", call: "meta", expected: "" })[0].ok, false)
  assert.equal(judge(PAGE.replace("<title>", '<meta charset="utf-8"><title>'), { type: "page_has", call: "meta", expected: "1" })[0].ok, true)
})

test("text_is reads the first match and ignores extra spacing", () => {
  assert.equal(judge(PAGE, { type: "text_is", call: "h1", expected: "Made up page" })[0].ok, true)
  assert.deepEqual(judge(PAGE, { type: "text_is", call: "h1", expected: "Other" }), [{ ok: false, plain: true, actual: "Right now it says “Made up page”." }])
  assert.deepEqual(judge(PAGE, { type: "text_is", call: "h3", expected: "x" }), [{ ok: false, plain: true, actual: "That isn't on the page yet." }])
  assert.equal(judge("<p></p>", { type: "text_is", call: "p", expected: "x" })[0].actual, "It's empty right now.")
  assert.equal(judge(`<p>${"long ".repeat(40)}</p>`, { type: "text_is", call: "p", expected: "x" })[0].actual.length, "Right now it says “”.".length + 78)
})

test("style_is compares what the browser worked out, however the value was written", () => {
  const style = (call, expected) => judge(PAGE, { type: "style_is", call, expected })[0]
  assert.equal(style("h1 { color }", "#B87333").ok, true)
  assert.equal(style("h1 { color }", "#b87333").ok, true)
  assert.equal(style("h1 { color }", "rgb(184, 115, 51)").ok, true)
  assert.equal(style(".note { text-align }", "center").ok, true)
  assert.equal(style(".note { background-color }", "#F5F3EF").ok, true)
  assert.deepEqual(style("h1 { color }", "#0F1E3D"), { ok: false, plain: true, actual: "Right now its color is #b87333." })
  assert.deepEqual(style(".note { text-align }", "right"), { ok: false, plain: true, actual: "Right now its text-align is center." })
  assert.deepEqual(style("h2 { color }", "red"), { ok: false, plain: true, actual: "That isn't on the page yet." })
  assert.match(style("h1 color", "red").actual, /couldn't be read/)
  // Nothing is left behind on the page by a check.
  const [doc, view] = page(PAGE)
  const before = doc.body.innerHTML
  judgePage(doc, view, [{ type: "style_is", call: "h1 { color }", expected: "red" }, { type: "style_is", call: ".note { text-align }", expected: "center" }])
  assert.equal(doc.body.innerHTML, before)
})

test("styleCall and showValue read and write values the way a student would", () => {
  assert.deepEqual(styleCall("h1 { color }"), { selector: "h1", property: "color" })
  assert.deepEqual(styleCall("ul li.done{Text-Align}"), { selector: "ul li.done", property: "text-align" })
  assert.equal(styleCall("h1"), null)
  assert.equal(showValue("rgb(184, 115, 51)"), "#b87333")
  assert.equal(showValue("rgba(0, 0, 0, 0)"), "transparent")
  assert.equal(showValue("rgba(0, 0, 0, 0.5)"), "rgba(0, 0, 0, 0.5)")
  assert.equal(showValue("1px solid rgb(0, 0, 0)"), "1px solid #000000")
  assert.equal(showValue("center"), "center")
})

test("the preview keeps the page as a browser reads it and shuts out scripts and outside files", () => {
  const drawn = previewDocument(PAGE, Parser)
  assert.ok(drawn.startsWith("<!DOCTYPE html>\n<html>"))
  assert.match(drawn, /<head><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:" data-classroom-preview="">/)
  // No doctype typed, none added: the page behaves as it would in a real tab.
  assert.ok(previewDocument("<h1>Hi</h1>", Parser).startsWith("<html><head><meta "))
  assert.match(previewDocument("<h1>Hi</h1>", Parser), /<body><h1>Hi<\/h1><\/body>/)
  assert.match(previewDocument("", Parser), /<body><\/body>/)
  // The policy comes before anything the student wrote in the head.
  const scripted = previewDocument('<head><script src="https://example.com/x.js"></script></head>', Parser)
  assert.ok(scripted.indexOf("Content-Security-Policy") < scripted.indexOf("<script"))
})

test("page checks reach the chips through the classroom's checker, with their sentences as written", async () => {
  const checks = [{ type: "page_has", call: "ul li", expected: "3" }, { type: "source_matches", expected: "(?i)<!doctype html>" }, { type: "style_is", call: "h1 { color }", expected: "#B87333" }]
  const outcomes = await evaluateChecks(checks, { code: PAGE, result: { stdout: "", error: null, checks: judge(PAGE, ...checks) } })
  assert.deepEqual(outcomes, [{ ok: false, actual: "The page has 2 of these. It needs 3." }, { ok: true }, { ok: true, actual: null }])
})

// A stand-in for the preview frame: setting srcdoc loads that page a moment later.
function fakeFrame() {
  const listeners = new Set()
  return {
    loads: 0,
    addEventListener(_, fn) { listeners.add(fn) }, removeEventListener(_, fn) { listeners.delete(fn) },
    set srcdoc(html) {
      setTimeout(() => {
        const dom = new JSDOM(html)
        this.contentDocument = dom.window.document; this.contentWindow = dom.window; this.loads += 1
        ;[...listeners].forEach(fn => fn())
      }, 5)
    }
  }
}

test("the preview answers a run with the page's checks, and a newer draw replaces an older one", async () => {
  const frame = fakeFrame()
  let links = 0
  const preview = new PagePreview({ frame, onLink: () => { links += 1 } })
  await preview.warm()
  const result = await preview.run(PAGE, [{ type: "text_is", call: "h1", expected: "Made up page" }, { type: "source_includes", expected: "x" }])
  assert.deepEqual(result, { stdout: "", error: null, checks: [{ ok: true, plain: true }, null] })

  // A link in the preview doesn't take the page away.
  const link = frame.contentDocument.querySelector("a")
  const click = new frame.contentWindow.MouseEvent("click", { bubbles: true, cancelable: true })
  link.dispatchEvent(click)
  assert.equal(click.defaultPrevented, true)
  assert.equal(links, 1)

  const first = preview.show("<p>old</p>")
  const second = preview.show("<p>new</p>")
  assert.equal(await first, null)
  assert.equal((await second).querySelector("p").textContent, "new")
})
