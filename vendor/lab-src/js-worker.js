// Runs a student's JavaScript in a Web Worker, so a loop that never ends can
// be stopped by terminating the worker, and so the code has no page to touch.
// It speaks the same messages as the Ruby, Python and SQL workers. There is
// nothing to download: the browser is the JavaScript runtime.
import { JsBench } from "./js-harness.js"

let bench = null

self.onmessage = async ({ data }) => {
  try {
    // Indirect eval runs in the worker's global scope, so the console's names last between entries.
    bench ||= new JsBench({ evaluate: code => (0, eval)(code), Function, global: self })
    const result = data.console
      ? await bench.console_({ op: data.op, line: data.line || "", checks: data.checks || [] })
      : await bench.run({ code: data.code || "", checks: data.checks || [] })
    self.postMessage({ id: data.id, ok: true, result })
  } catch (e) {
    self.postMessage({ id: data.id, ok: false, error: String(e && e.message || e) })
  }
}
self.postMessage({ ready: true })
