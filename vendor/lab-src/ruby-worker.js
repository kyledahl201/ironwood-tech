// Runs a student's Ruby in a Web Worker with ruby.wasm, so a runaway loop can
// be stopped by terminating the worker. A fresh VM per run keeps old method
// definitions from leaking between runs.
import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/browser"

let modulePromise = null

const HARNESS = String.raw`
require "json"
require "stringio"
require "js"

payload = JSON.parse(JS.global[:__iwPayload].to_s)

def __iw_capture
  old = $stdout
  buf = StringIO.new
  $stdout = buf
  begin
    [buf.string, yield, nil]
  rescue Exception => e
    [buf.string, nil, e]
  ensure
    $stdout = old
  end
end

def __iw_line(e)
  (e.backtrace || []).each { |l| return $1.to_i if l =~ /main\.rb:(\d+)/ }
  e.message[/main\.rb:(\d+)/, 1]&.to_i
end

def __iw_friendly(e)
  line = __iw_line(e)
  at = line ? " on line #{line}" : ""
  case e
  when SyntaxError then "Ruby couldn't read your code#{at}. Look for a missing end, quote or bracket."
  when NoMethodError
    if (e.receiver.nil? rescue false)
      "Something#{at} is nil, so it has no method called #{e.name}. Did a method print with puts instead of returning a value?"
    else
      "Ruby couldn't find a method called #{e.name}#{at}." + (e.respond_to?(:corrections) && e.corrections.any? ? " Did you mean #{e.corrections.first}?" : "")
    end
  when NameError then "Ruby doesn't know what #{e.name} is#{at}. Is it spelled right, and was it set before this line?"
  when ArgumentError then "A method got the wrong number or kind of arguments#{at}: #{e.message}"
  when ZeroDivisionError then "Your code divided by zero#{at}."
  else "#{e.class}#{at}: #{e.message}"
  end
end

out, _value, err = __iw_capture { eval(payload["code"], TOPLEVEL_BINDING, "main.rb", 1) }
result = { "stdout" => out, "error" => err && { "friendly" => __iw_friendly(err), "raw" => "#{err.class}: #{err.message}" }, "checks" => [] }

payload["checks"].each do |check|
  case check["type"]
  when "method_returns"
    o, v, e = __iw_capture { eval(check["call"], TOPLEVEL_BINDING, "check.rb") }
    expected = eval(check["expected"], TOPLEVEL_BINDING) rescue check["expected"]
    result["checks"] << { "ok" => e.nil? && v == expected, "expected" => expected.inspect, "actual" => e ? __iw_friendly(e) : v.inspect }
  when "method_stdout_empty"
    o, _v, e = __iw_capture { eval(check["call"], TOPLEVEL_BINDING, "check.rb") }
    result["checks"] << { "ok" => e.nil? && o.empty?, "expected" => "(prints nothing)", "actual" => e ? __iw_friendly(e) : (o.empty? ? "(prints nothing)" : o) }
  else
    result["checks"] << nil
  end
end

JSON.generate(result)
`

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
    modulePromise ||= loadVerified(data.wasmUrl)
    const module = await modulePromise
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
