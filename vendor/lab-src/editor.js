// Code editor for the lab: CodeMirror 6 with the Ironwood "Night" theme
// (Prof. Duarte's code-lab spec).
import { EditorState } from "@codemirror/state"
import { EditorView, keymap, lineNumbers, highlightActiveLine, drawSelection, highlightActiveLineGutter } from "@codemirror/view"
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands"
import { StreamLanguage, HighlightStyle, syntaxHighlighting, indentOnInput, bracketMatching, indentUnit } from "@codemirror/language"
import { ruby } from "@codemirror/legacy-modes/mode/ruby"
import { python } from "@codemirror/lang-python"
import { tags as t } from "@lezer/highlight"

const LINEN = "#F5F3EF", COPPER = "#B87333"

const theme = EditorView.theme({
  "&": { color: LINEN, backgroundColor: "#0B1222", fontSize: "15px", height: "100%" },
  ".cm-scroller": { fontFamily: "'IBM Plex Mono', ui-monospace, Menlo, monospace", lineHeight: "1.6", overflow: "auto" },
  ".cm-content": { caretColor: COPPER, padding: "12px 0" },
  ".cm-gutters": { backgroundColor: "#0B1222", color: "rgba(245,243,239,.35)", border: "none", paddingTop: "0" },
  ".cm-cursor, .cm-dropCursor": { borderLeftColor: COPPER, borderLeftWidth: "2px" },
  "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection": { backgroundColor: "rgba(184,115,51,.28)" },
  ".cm-activeLine": { backgroundColor: "rgba(245,243,239,.04)" },
  ".cm-activeLineGutter": { backgroundColor: "transparent", color: "rgba(245,243,239,.7)" },
  ".cm-matchingBracket": { outline: "1px solid rgba(184,115,51,.6)", backgroundColor: "transparent" },
  "&.cm-focused": { outline: "none" }
}, { dark: true })

const highlight = HighlightStyle.define([
  { tag: [t.keyword, t.controlKeyword, t.definitionKeyword, t.moduleKeyword, t.operatorKeyword], color: COPPER },
  { tag: [t.string, t.special(t.string), t.regexp], color: "#8FB3D9" },
  { tag: [t.number, t.bool, t.atom, t.null], color: "#A6C08F" },
  { tag: t.comment, color: "rgba(245,243,239,.5)", fontStyle: "italic" },
  { tag: [t.variableName, t.propertyName, t.name], color: LINEN },
  { tag: [t.function(t.variableName), t.definition(t.variableName)], color: LINEN, fontWeight: "600" }
])

export function createEditor(parent, { doc = "", language = "ruby", onRun = () => {}, onChange = () => {} } = {}) {
  const lang = language === "python" ? python() : StreamLanguage.define(ruby)
  const runKeys = [
    { key: "Mod-Enter", run: () => { onRun(); return true } },
    { key: "Shift-Enter", run: () => { onRun(); return true } }
  ]
  const view = new EditorView({
    parent,
    state: EditorState.create({
      doc,
      extensions: [
        lineNumbers(), highlightActiveLineGutter(), highlightActiveLine(), drawSelection(), history(),
        indentOnInput(), bracketMatching(), indentUnit.of("  "), EditorState.tabSize.of(2),
        keymap.of([ ...runKeys, indentWithTab, ...defaultKeymap, ...historyKeymap ]),
        lang, syntaxHighlighting(highlight), theme,
        EditorView.contentAttributes.of({ "aria-label": "Code editor" }),
        EditorView.updateListener.of(u => { if (u.docChanged) onChange(u.state.doc.toString()) })
      ]
    })
  })
  // Re-measure once the web font arrives, so the line numbers stay lined up.
  document.fonts?.ready.then(() => view.requestMeasure())
  return {
    view,
    get value() { return view.state.doc.toString() },
    set value(text) { view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: text } }) },
    focus() { view.focus() }
  }
}
