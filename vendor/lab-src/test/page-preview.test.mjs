// The web page workbench's checks and preview, on a real DOM (jsdom).
import { test } from "node:test"
import assert from "node:assert/strict"
import { JSDOM } from "jsdom"
import { judgePage, previewDocument, styleCall, showValue, pageNotes, PagePreview } from "../../../app/javascript/lib/page_preview.js"
import { evaluateChecks } from "../../../app/javascript/lib/checks.js"
import { buildTutorNote } from "../../../app/javascript/lib/tutor_note.js"

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

// What a browser's CSS.supports says, for the handful of properties these tests use.
const VALUES = { color: /^(#[0-9a-f]{3,8}|red|gray|rgb\(.*\))$/i, "text-align": /^(left|right|center|justify)$/, "font-size": /^\d+(px|em|rem)$/, "background-color": /^(#[0-9a-f]{3,8}|linen|rgb\(.*\))$/i, margin: /^[\d a-z]+$/ }
const supports = (property, value) => property in VALUES && (value === "initial" || VALUES[property].test(value))
const notes = code => pageNotes(code, supports).map(n => `${n.line}: ${n.text}`)

test("a page with nothing wrong gets no notes", () => {
  assert.deepEqual(notes(PAGE), [])
  // Tags that may stay open, tags that never close, a bare < in the text, and newer CSS all pass quietly.
  assert.deepEqual(notes(`<!DOCTYPE html>
<html><head><style>
  /* a comment with a } and a stray: colon */
  h1 { color: red; text-align: center }
  @media (max-width: 600px) { h1 { font-size: 20px; } }
  :root { --brand: #B87333; }
</style></head>
<body><p>One<br>two
<ul><li>a<li>b</ul>
<img src="data:x" alt=""><input type="text"><br/>
<p>3 < 4 and 5 > 4</p>
<a href="#top" title='say "hi"'>up</a>`), [])
  assert.deepEqual(notes(""), [])
})

test("CSS the browser skips is named, with its line", () => {
  assert.deepEqual(notes("<style>\n.note { text-algin: center; }\n</style>"), ["2: The browser doesn't know a property called text-algin, so it skipped this line."])
  assert.deepEqual(notes("<style>\nh1 {\n  color: red;\n  text-align: centre;\n}\n</style>"), ["4: The browser doesn't accept “centre” as a value for text-align, so it skipped this line."])
  assert.deepEqual(notes("<style>\np { color red; }\n</style>"), ["2: This line has no colon between a property and its value, so the browser skipped it: color red"])
  assert.deepEqual(notes("<style>\nli {\n  color: red\n  font-size: 2em;\n}\n</style>"), ["3: There's no semicolon at the end of this line, so the browser read the next line as part of the value and skipped both."])
  assert.deepEqual(notes("<style>\nh1 { color: ; }\n</style>"), ["2: color has no value after its colon, so the browser skipped it."])
  assert.deepEqual(notes("<style>\nh1 { color: red;\np { color: gray; }\n</style>"), ["2: The rule that starts here is never closed with }, so the browser read everything after it as part of this rule."])
  assert.deepEqual(notes("<style>\nh1 { color: red; }\n}\n</style>"), ["3: There's a } here with no rule open, so the browser skipped it."])
  assert.deepEqual(notes("<style>\nh1 color: red;\n</style>"), ["2: This isn't inside a rule's curly brackets, so the browser skipped it: h1 color: red;"])
  assert.deepEqual(notes("<style>\n{ color: red; }\n</style>"), ["2: This { has no selector in front of it, so the browser doesn't know what to style."])
  // A mistake inside a media rule is found too, and a note never says what to type instead.
  assert.deepEqual(notes("<style>\n@media (max-width: 600px) {\n  h1 { colour: red; }\n}\n</style>"), ["3: The browser doesn't know a property called colour, so it skipped this line."])
  assert.ok(notes("<style>h1 { text-align: centre; colour: red }</style>").every(n => !/center|color:/.test(n)))
})

test("tags the browser rebuilds are named, with their lines", () => {
  assert.deepEqual(notes("<h1>Title<h1>\n<p>ok</p>"), ["1: A second <h1> opens here before the one earlier on this line was closed. The browser made two of them. A closing tag has a slash: </h1>."])
  assert.match(notes("<h2>One\n<h2>")[0], /^2: A second <h2> opens here before the one on line 1 was closed\./)
  assert.deepEqual(notes("<ul>\n  <li>a</li>\n<p>after</p>"), ["1: <ul> opens here and is never closed, so the browser closed it for you at the end."])
  assert.deepEqual(notes("<p>text</p>\n</div>"), ["2: There's a closing </div> here with no <div> open, so the browser ignored it."])
  assert.deepEqual(notes("<p>\n<b>bold <i>both</b>\n it</i></p>"), [
    "2: </b> closes here while the <i> from line 2 is still open, so the browser closed that one for you.",
    "3: There's a closing </i> here with no <i> open, so the browser ignored it."
  ])
  assert.deepEqual(notes('<p>x</p>\n<a href="https://example.com>link</a>'), ["2: A quote opens in this <a> tag and never closes, so the browser read the text after it as part of the tag."])
  assert.deepEqual(notes("<p class='note>text</p>"), ["1: A quote opens in this <p> tag and never closes, so the browser read the text after it as part of the tag."])
  assert.deepEqual(notes("<h1 Hello</h1>"), ["1: This <h1> tag has no > to finish it, so the browser read what follows as part of the tag."])
  assert.deepEqual(notes("<p>a</p>\n<!-- note\n<p>b</p>"), ["2: A comment starts here and is never closed with -->, so the browser treats everything after it as part of the comment."])
  assert.deepEqual(notes("<style>\nh1 { color: red; }\n<h1>Hi</h1>"), ["1: <style> opens here and is never closed, so the browser read the rest of the page as part of it."])
  // Notes come in page order, HTML and CSS together.
  assert.deepEqual(pageNotes("<style>\nh1 { colour: red }\n</style>\n<h2>a<h2>\n</em>", supports).map(n => n.line), [2, 4, 5])
})

test("the preview asks the real browser what CSS it accepts, and the notes go to the tutor", () => {
  const asked = []
  const preview = new PagePreview({ frame: { contentWindow: { CSS: { supports: (p, v) => { asked.push([p, v]); return p === "color" } } } } })
  assert.deepEqual(preview.notes("<style>h1 { color: red; text-algin: center }</style>").map(n => n.text), ["The browser doesn't know a property called text-algin, so it skipped this line."])
  assert.deepEqual(asked, [["color", "initial"], ["color", "red"], ["text-algin", "initial"]])
  // Where there is no CSS.supports to ask, CSS is left alone rather than guessed at.
  assert.deepEqual(new PagePreview({ frame: {} }).notes("<style>h1 { text-algin: center }</style><em>x"), [{ line: 1, text: "<em> opens here and is never closed, so the browser closed it for you at the end." }])

  const copied = buildTutorNote({ about: "TOUR", place: "Step 2 of 9", tool: "Web page (HTML and CSS)", language: "html", code: "<h1>x<h1>", notes: ["Line 1 A second <h1> opens here."] })
  assert.match(copied, /What the browser fixed or skipped in my page:\n- Line 1 A second <h1> opens here\./)
  assert.doesNotMatch(buildTutorNote({ about: "TOUR", place: "Step 2", code: "x" }), /fixed or skipped/)
})
