// The classroom's runner (lib/code_runner.js) driving real Python (Pyodide):
// multi-line console entries, a runaway loop, and the replay that brings the
// student's variables and functions back afterwards.
import { test, before } from "node:test"
import assert from "node:assert/strict"
import { loadPyodide } from "pyodide"
import { PY_SETUP } from "../python-harness.js"
import { CodeRunner } from "../../../app/javascript/lib/code_runner.js"

let run, cons
before(async () => {
  const pyodide = await loadPyodide()
  pyodide.runPython(PY_SETUP)
  run = pyodide.globals.get("__iw_run")
  cons = pyodide.globals.get("__iw_console")
})

// Stands in for the browser's Worker. It answers with the real Python harness,
// except that the finished `while True` loop never comes back (in the browser the
// worker would be busy forever), and a new worker starts with a clean Python,
// which is what stopping and restarting the real worker gives.
const log = { started: 0, stopped: 0 }
class PythonWorker {
  constructor() { log.started += 1; cons(JSON.stringify({ op: "reset" })) }
  postMessage(message) {
    if (message.console && message.line === "while True:\n    pass\n") return
    const json = message.console
      ? cons(JSON.stringify({ op: message.op, line: message.line || "", checks: message.checks || [] }))
      : run(JSON.stringify({ code: message.code, checks: message.checks || [] }))
    queueMicrotask(() => this.onmessage({ data: { id: message.id, ok: true, result: JSON.parse(json) } }))
  }
  terminate() { log.stopped += 1 }
}

test("a stopped loop keeps the student's variables, functions and loops, typed the way a student types them", async () => {
  const status = []
  const runner = new CodeRunner({ name: "Python", workerUrl: "x", runtimeUrl: "y", megabytes: 13, timeoutMs: 40, WorkerClass: PythonWorker, onStatus: text => status.push(text) })
  await runner.warm()
  assert.equal(status[0], "Loading Python (first time only, about 13 MB)…")

  // Each call is one line and one press of Enter.
  const typed = []
  const type = async text => { const result = await runner.type(text); typed.push(result.incomplete ? "..." : ">>>"); return result }
  await type("x = 2")
  await type("def double(n):")
  await type("    return n * 2")
  assert.equal(runner.partial, "def double(n):\n    return n * 2\n")
  const defined = await type("")                    // the blank line ends the block
  assert.equal(defined.error, null)
  assert.equal(runner.partial, "")
  await type("total = 0")
  await type("for i in range(3):")
  await type("    total += double(i)")
  await type("")
  assert.equal((await type("total")).value, "6")
  assert.deepEqual(typed, [">>>", "...", "...", ">>>", ">>>", "...", "...", ">>>", ">>>"])
  assert.deepEqual(runner.history, ["x = 2", "def double(n):\n    return n * 2\n", "total = 0", "for i in range(3):\n    total += double(i)\n", "total"])

  await type("while True:")
  await type("    pass")
  const stopped = await type("")
  assert.equal(stopped.stopped, true)
  assert.match(stopped.error.friendly, /stopped\. Look for a loop that never ends\. Python was restarted and your earlier lines were run again/)
  assert.equal(runner.partial, "")
  await runner.restoring
  assert.equal(log.started, 2)                       // a clean Python…

  // …with everything back: nothing was swallowed into a block during the replay.
  assert.equal((await type("double(x)")).value, "4")
  assert.equal((await type("total")).value, "6")
  assert.equal((await runner.values([{ type: "value_is", call: "double(21)", expected: "42" }]))[0].ok, true)
  assert.ok(!runner.history.some(line => line.includes("while True")))

  // Ctrl+C drops a half-typed block, and the next line stands on its own.
  await type("def broken(:")
  await type("if x:")
  assert.notEqual(runner.partial, "")
  runner.cancel()
  assert.equal((await type("x + 1")).value, "3")
  runner.dispose()
})
