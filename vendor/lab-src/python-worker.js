// Runs a student's Python in a Web Worker with Pyodide, so a runaway loop can
// be stopped by terminating the worker. It speaks the same messages as the
// Ruby worker. Pyodide is served by this site only (public/lab/pyodide,
// fetched and checksummed by bin/fetch-pyodide); there is no CDN fallback.
import { PY_SETUP } from "./python-harness.js"

let ready = null

async function load(runtimeUrl) {
  const base = runtimeUrl.endsWith("/") ? runtimeUrl : `${runtimeUrl}/`
  const { loadPyodide } = await import(/* @vite-ignore */ `${base}pyodide.mjs`)
  const pyodide = await loadPyodide({ indexURL: base })
  pyodide.runPython(PY_SETUP)
  return { run: pyodide.globals.get("__iw_run"), console: pyodide.globals.get("__iw_console") }
}

self.onmessage = async ({ data }) => {
  try {
    ready ||= load(data.runtimeUrl)
    const python = await ready
    const json = data.console
      ? python.console(JSON.stringify({ op: data.op, line: data.line || "", checks: data.checks || [] }))
      : python.run(JSON.stringify({ code: data.code, checks: data.checks || [] }))
    self.postMessage({ id: data.id, ok: true, result: JSON.parse(json) })
  } catch (e) {
    if (!(await ready?.catch(() => null))) ready = null // let the next run retry the download
    self.postMessage({ id: data.id, ok: false, error: String(e && e.message || e) })
  }
}
self.postMessage({ ready: true })
