import { test } from "node:test"
import assert from "node:assert/strict"
import { buildTutorNote } from "../../app/javascript/lib/tutor_note.js"

test("an editor task copies the task, the student's code, the output and the checks", () => {
  const note = buildTutorNote({
    about: "AI 360 · Lesson 1 · Made-up title", place: "Step 3 of 9", task: "Write double(n).", tool: "Python editor", language: "python",
    code: "def double(n):\n    return n\n\n", output: "4\n",
    checks: [{ label: "double(2) returns 4", ok: false, detail: "gave 2" }, { label: "Doesn't use print(", ok: true, detail: "ignored" }], hints: 1
  })
  assert.equal(note, [
    "Ironwood Tech classroom: AI 360 · Lesson 1 · Made-up title", "Step 3 of 9", "The task:\nWrite double(n).",
    "My code (Python editor):\n```python\ndef double(n):\n    return n\n```", "What it printed:\n```\n4\n```",
    "The portal's checks:\n- Not yet: double(2) returns 4 (gave 2)\n- Pass: Doesn't use print(", "Hints I've opened on this task: 1", "My question: "
  ].join("\n\n"))
})

test("a console task copies what was typed, and a lesson step copies only where the student is", () => {
  const typed = buildTutorNote({ about: "A", place: "Step 1 of 2", task: "Set x.", tool: "Python console", transcript: ">>> x = 1\n>>> x\n1\n", checks: [{ label: "x is 1", ok: true }], hints: 0 })
  assert.match(typed, /What I typed and what came back \(Python console\):\n```\n>>> x = 1\n>>> x\n1\n```/)
  assert.doesNotMatch(typed, /My code/)
  assert.equal(buildTutorNote({ about: "A", place: "Step 2 of 2", task: "Read this." }), "Ironwood Tech classroom: A\n\nStep 2 of 2\n\nThe task:\nRead this.\n\nMy question: ")
})

test("very long work is cut so the paste stays a sensible size", () => {
  const note = buildTutorNote({ about: "A", place: "P", tool: "Ruby editor", language: "ruby", code: "x".repeat(7000) })
  assert.match(note, /… \(cut here: 1000 more characters\)/)
  assert.ok(note.length < 6300)
})
