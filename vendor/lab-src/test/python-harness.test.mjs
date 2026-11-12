// Runs the classroom's Python harness in real Python (Pyodide) under Node.
import { test, before } from "node:test"
import assert from "node:assert/strict"
import { loadPyodide } from "pyodide"
import { PY_SETUP } from "../python-harness.js"

let run, cons
before(async () => {
  const pyodide = await loadPyodide()
  pyodide.runPython(PY_SETUP)
  const runPy = pyodide.globals.get("__iw_run"), consPy = pyodide.globals.get("__iw_console")
  run = (code, checks = []) => JSON.parse(runPy(JSON.stringify({ code, checks })))
  cons = payload => JSON.parse(consPy(JSON.stringify(payload)))
})

const line = text => cons({ op: "eval", line: text })
const values = checks => cons({ op: "values", checks }).checks
const reset = () => cons({ op: "reset" })

test("the console shows each line's value and keeps variables", () => {
  reset()
  assert.deepEqual(line("1 + 2"), { stdout: "", value: "3", incomplete: false, error: null })
  assert.equal(line('name = "Ada"').value, null) // an assignment shows nothing, as in Python
  assert.equal(line("name.upper()").value, "'ADA'")
  assert.deepEqual(line('print("hi")'), { stdout: "hi\n", value: null, incomplete: false, error: null })
  assert.equal(line("_").value, "'ADA'")
})

test("the console waits for the rest of a block, and a blank line ends it", () => {
  reset()
  assert.equal(line("def double(n):").incomplete, true)
  assert.equal(line("def double(n):\n    return n * 2").incomplete, true)
  const done = line("def double(n):\n    return n * 2\n")
  assert.equal(done.incomplete, false)
  assert.equal(done.error, null)
  assert.equal(line("double(21)").value, "42")
  assert.equal(line("total = (1 +").incomplete, true)
  assert.equal(line("total = (1 +\n2)").incomplete, false)
  assert.equal(line("for i in range(2):\n    print(i)\n").stdout, "0\n1\n")
})

test("console errors are explained in plain words, with Python's own message kept", () => {
  reset()
  const unknown = line("nmae")
  assert.match(unknown.error.friendly, /^Python doesn't know what nmae is\. Is it spelled right/)
  assert.match(unknown.error.raw, /^NameError: name 'nmae' is not defined/)
  assert.equal(unknown.incomplete, false)
  assert.match(line("1 / 0").error.friendly, /divided by zero/)
  assert.match(line("x = = 3").error.friendly, /couldn't read your code/)
  assert.match(line('{"a": 1}["b"]').error.friendly, /no key 'b'/)
  assert.match(line('input("name? ")').error.friendly, /input\(\) doesn't work in the browser/)
  assert.equal(line("2 + 2").value, "4") // the console still works after an error
})

test("value checks compare against a Python literal and never reveal one", () => {
  reset()
  line('city = "Tulsa"'); line("count = 3"); line('row = {"id": 7, "tags": ["a", "b"]}'); line("flag = True")
  const checks = values([
    { type: "value_is", call: "city", expected: '"Tulsa"' },
    { type: "value_is", call: "count", expected: "3" },
    { type: "value_is", call: 'row["tags"]', expected: '["a", "b"]' },
    { type: "value_is", call: "missing", expected: "1" },
    { type: "value_is", call: "flag", expected: "1" },          // True is not 1 for a check
    { type: "value_is", call: "count", expected: "3.0" },       // but 3 and 3.0 are the same number
    { type: "value_is", call: "city", expected: "Tulsa" },      // not a literal: compared as text
    { type: "value_is", call: "city * 2", expected: '"Tulsa" * 2' } // a small expression is worked out
  ])
  assert.deepEqual(checks.map(c => c.ok), [true, true, true, false, false, true, true, true])
  assert.equal(checks[3].actual, "not there yet")
  reset()
  assert.equal(values([{ type: "value_is", call: "city", expected: '"Tulsa"' }])[0].ok, false) // reset clears variables
})

test("a program's output is captured and its functions are checked", () => {
  const result = run('def clean(text):\n    return text.strip().lower()\n\nprint(clean("  HI "))\n', [
    { type: "stdout", expected: "hi\n" },
    { type: "method_returns", call: 'clean(" Ada ")', expected: '"ada"' },
    { type: "method_returns", call: 'clean("X")', expected: '"X"' },
    { type: "method_stdout_empty", call: 'clean("a")', expected: "" }
  ])
  assert.equal(result.stdout, "hi\n")
  assert.equal(result.error, null)
  assert.deepEqual(result.checks.map(c => c && c.ok), [null, true, false, true])
  assert.equal(result.checks[2].actual, "'x'")
})

test("each program run starts clean", () => {
  run("leftover = 1")
  const result = run("print(leftover)")
  assert.match(result.error.friendly, /doesn't know what leftover is on line 1/)
})

test("program errors name the line, and output before the error is kept", () => {
  const result = run('print("start")\nitems = [1, 2]\nprint(items[5])\n')
  assert.equal(result.stdout, "start\n")
  assert.match(result.error.friendly, /past the end of the list or string on line 3/)
  assert.match(result.error.raw, /^IndexError/)
  assert.match(run("def f():\nreturn 1\n").error.friendly, /spaces at the start of the line/)
  assert.match(run("if True\n    pass\n").error.friendly, /couldn't read your code on line 1/)
  assert.match(run("def f():\n    print('x')\n\nf().upper()\n").error.friendly, /is None, so it has nothing called upper/)
  assert.equal(run('print("a".uper())\n').error.friendly, "Text has nothing called uper on line 1. Did you mean upper?")
  assert.equal(run("import sys\nprint('a')\nsys.exit()\n").stdout, "a\n") // exit() doesn't break the harness
})

test("the standard library the lessons use is there", () => {
  const result = run('import json, random, re, math, collections\nrandom.seed(1)\nprint(json.dumps({"a": [1, 2]}), math.floor(2.5), re.sub(r"\\s+", " ", "a   b"))\n')
  assert.equal(result.error, null)
  assert.equal(result.stdout, '{"a": [1, 2]} 2 a b\n')
})
