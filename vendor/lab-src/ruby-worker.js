// Runs a student's Ruby in a Web Worker with ruby.wasm, so a runaway loop can
// be stopped by terminating the worker. A fresh VM per run keeps old method
// definitions from leaking between runs.
import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/browser"
import { HARNESS, CONSOLE_SETUP } from "./ruby-harness.js"

let modulePromise = null

let consoleVm = null

async function consoleCall(module, data) {
  if (data.op === "reset") { consoleVm = null; return {} }
  if (!consoleVm) {
    consoleVm = (await DefaultRubyVM(module, { consolePrint: false })).vm
    consoleVm.eval(CONSOLE_SETUP)
  }
  self.__iwPayload = JSON.stringify({ op: data.op, line: data.line || "", checks: data.checks || [] })
  return JSON.parse(consoleVm.eval("__iw_console").toString())
}

// The Ruby binary is pinned: whether it comes from this site or the CDN
// fallback, it only runs if its SHA-256 matches (bin/fetch-ruby-wasm pins the same one).
const WASM_SHA256 = "4b814fc9d13505ea5b4c1f3bd3a7cc7ccca137f551196b9b21f0a7caf9cc5878"

async function loadVerified(url) {
  const response = await fetch(url)
  if (!response.ok) throw new Error(`Ruby didn't download (HTTP ${response.status})`)
  const bytes = await response.arrayBuffer()
  const digest = await crypto.subtle.digest("SHA-256", bytes)
  const hex = [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, "0")).join("")
  if (hex !== WASM_SHA256) throw new Error("The Ruby download didn't match its checksum, so the lab won't run it.")
  return WebAssembly.compile(bytes)
}

self.onmessage = async ({ data }) => {
  try {
    modulePromise ||= loadVerified(data.runtimeUrl || data.wasmUrl)
    const module = await modulePromise
    if (data.console) {
      self.postMessage({ id: data.id, ok: true, result: await consoleCall(module, data) })
      return
    }
    const { vm } = await DefaultRubyVM(module, { consolePrint: false })
    self.__iwPayload = JSON.stringify({ code: data.code, checks: data.checks || [] })
    const json = vm.eval(HARNESS).toString()
    self.postMessage({ id: data.id, ok: true, result: JSON.parse(json) })
  } catch (e) {
    if (!(await modulePromise?.catch(() => null))) modulePromise = null // let the next run retry the download
    self.postMessage({ id: data.id, ok: false, error: String(e && e.message || e) })
  }
}
self.postMessage({ ready: true })
