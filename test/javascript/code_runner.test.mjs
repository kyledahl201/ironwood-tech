import { test } from "node:test"
import assert from "node:assert/strict"
import { CodeRunner } from "../../app/javascript/lib/code_runner.js"

// A stand-in for the Ruby worker. It answers every line except one containing
// "loop", which never comes back, like `loop {}` in real Ruby.
function fakeWorker(log) {
  return class {
    constructor() { log.started += 1; this.vars = [] ; log.workers.push(this) }
    postMessage(message) {
      if (message.console && message.op === "eval") {
        if (message.line.includes("loop")) return // hangs
        this.vars.push(message.line)
        queueMicrotask(() => this.onmessage({ data: { id: message.id, ok: true, result: { stdout: "", value: "1" } } }))
      } else queueMicrotask(() => this.onmessage({ data: { id: message.id, ok: true, result: { stdout: "", checks: [] } } }))
    }
    terminate() { log.terminated += 1 }
  }
}

const settle = () => new Promise(resolve => setTimeout(resolve, 20))

test("a runaway loop is stopped, Ruby restarts, and earlier lines are replayed", async () => {
  const log = { started: 0, terminated: 0, workers: [] }
  const status = []
  const runner = new CodeRunner({ workerUrl: "x", runtimeUrl: "y", timeoutMs: 30, WorkerClass: fakeWorker(log), onStatus: (text, tone) => status.push(`${tone}:${text}`) })
  await runner.warm()
  await runner.line("a = 1")
  await runner.line("b = 2")
  assert.deepEqual(runner.history, ["a = 1", "b = 2"])

  const result = await runner.line("loop {}")
  assert.equal(result.stopped, true)
  assert.match(result.error.friendly, /was stopped\. Look for a loop that never ends\./)
  assert.match(result.error.friendly, /earlier lines were run again, so your variables are back/)
  await runner.restoring
  await settle()

  assert.equal(log.started, 2)                              // a fresh Ruby
  assert.equal(log.terminated, 1)                           // the stuck one was stopped
  assert.deepEqual(log.workers[1].vars, ["a = 1", "b = 2"]) // variables put back
  assert.deepEqual(runner.history, ["a = 1", "b = 2"])      // the loop itself is not replayed
  assert.ok(status.includes("bad:Stopped"))
  assert.equal(status.at(-1), "ok:Ready")

  const after = await runner.line("c = 3")                   // and the console still works
  assert.equal(after.value, "1")
})

test("with nothing to replay, the student is told the console is empty", async () => {
  const log = { started: 0, terminated: 0, workers: [] }
  const runner = new CodeRunner({ workerUrl: "x", runtimeUrl: "y", timeoutMs: 30, WorkerClass: fakeWorker(log) })
  await runner.warm()
  const result = await runner.line("loop {}")
  assert.match(result.error.friendly, /anything set in the console is gone/)
})

test("lines that raise an error are not remembered for replay", async () => {
  const Worker = class {
    postMessage(message) {
      const result = message.line === "nope" ? { stdout: "", error: { friendly: "?", raw: "NameError" } } : { stdout: "", value: "1" }
      queueMicrotask(() => this.onmessage({ data: { id: message.id, ok: true, result } }))
    }
    terminate() {}
  }
  const runner = new CodeRunner({ workerUrl: "x", runtimeUrl: "y", WorkerClass: Worker })
  await runner.line("x = 1")
  await runner.line("nope")
  assert.deepEqual(runner.history, ["x = 1"])
  await runner.resetConsole()
  assert.deepEqual(runner.history, [])
})

test("messages name the language the runner was made for", async () => {
  const log = { started: 0, terminated: 0, workers: [] }
  const status = []
  const runner = new CodeRunner({ name: "Python", workerUrl: "x", runtimeUrl: "y", timeoutMs: 30, WorkerClass: fakeWorker(log), onStatus: text => status.push(text) })
  await runner.warm()
  assert.equal(status[0], "Loading Python…")
  const stopped = await runner.line("while True: loop")
  assert.match(stopped.error.friendly, /Python was restarted, so anything set in the console is gone\./)
  runner.dispose()
})
