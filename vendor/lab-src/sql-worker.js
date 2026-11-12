// Runs a student's SQL in a Web Worker with SQLite (sql.js), so a query that
// never ends can be stopped by terminating the worker. It speaks the same
// messages as the Ruby and Python workers. The SQLite binary is served by this
// site only (public/lab/sqlite, fetched by bin/fetch-sqlite) and only runs if
// its SHA-256 matches; there is no CDN fallback.
import initSqlJs from "sql.js/dist/sql-wasm-browser.js"
import { SqlBench } from "./sql-harness.js"

const WASM_SHA256 = "38c14f6e379210bc942bdc4ebca44e7bfdb4318ecc1c72ca666a28fdce96670a"

let ready = null

async function load(runtimeUrl) {
  const base = runtimeUrl.endsWith("/") ? runtimeUrl : `${runtimeUrl}/`
  const response = await fetch(`${base}sql-wasm.wasm`)
  if (!response.ok) throw new Error(`SQL didn't download (HTTP ${response.status})`)
  const bytes = await response.arrayBuffer()
  const digest = await crypto.subtle.digest("SHA-256", bytes)
  const hex = [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, "0")).join("")
  if (hex !== WASM_SHA256) throw new Error("The SQL download didn't match its checksum, so the classroom won't run it.")
  return new SqlBench(await initSqlJs({ wasmBinary: bytes }))
}

self.onmessage = async ({ data }) => {
  try {
    ready ||= load(data.runtimeUrl)
    const bench = await ready
    const result = data.console
      ? bench.console({ op: data.op, line: data.line || "", checks: data.checks || [] })
      : bench.run({ code: data.code || "", checks: data.checks || [] })
    self.postMessage({ id: data.id, ok: true, result })
  } catch (e) {
    if (!(await ready?.catch(() => null))) ready = null // let the next run retry the download
    self.postMessage({ id: data.id, ok: false, error: String(e && e.message || e) })
  }
}
self.postMessage({ ready: true })
