// Runs a student's Ruby in a Web Worker with ruby.wasm, so a runaway loop can
// be stopped by terminating the worker. A fresh VM per run keeps old method
// definitions from leaking between runs.
import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/browser"

let modulePromise = null

const HELPERS = String.raw`
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

# A check's expected value is written as Ruby ("auto", 12, nil). If it isn't
# valid Ruby, it is compared as plain text.
def __iw_expected(text)
  eval(text.to_s, TOPLEVEL_BINDING)
rescue Exception
  text
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
`

const HARNESS = HELPERS + String.raw`
require "json"
require "stringio"
require "js"

payload = JSON.parse(JS.global[:__iwPayload].to_s)

out, _value, err = __iw_capture { eval(payload["code"], TOPLEVEL_BINDING, "main.rb", 1) }
result = { "stdout" => out, "error" => err && { "friendly" => __iw_friendly(err), "raw" => "#{err.class}: #{err.message}" }, "checks" => [] }

payload["checks"].each do |check|
  case check["type"]
  when "method_returns", "value_is"
    o, v, e = __iw_capture { eval(check["call"], TOPLEVEL_BINDING, "check.rb") }
    expected = __iw_expected(check["expected"])
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

// The Ruby console keeps one VM alive so variables last between lines.
// Each call evaluates one entry, or looks up values for value_is checks.
const CONSOLE_SETUP = HELPERS + String.raw`
require "json"
require "stringio"
require "js"

def __iw_console
  payload = JSON.parse(JS.global[:__iwPayload].to_s)
  if payload["op"] == "values"
    checks = payload["checks"].map do |check|
      out, v, e = __iw_capture { eval(check["call"], TOPLEVEL_BINDING, "check.rb") }
      if check["type"] == "method_stdout_empty"
        { "ok" => e.nil? && out.empty?, "expected" => "(prints nothing)", "actual" => e ? __iw_friendly(e) : (out.empty? ? "(prints nothing)" : out) }
      else
        expected = __iw_expected(check["expected"])
        { "ok" => e.nil? && v == expected, "expected" => expected.inspect, "actual" => e ? "not there yet" : v.inspect }
      end
    end
    return JSON.generate("checks" => checks)
  end
  out, value, err = __iw_capture { eval(payload["line"], TOPLEVEL_BINDING, "main.rb", 1) }
  incomplete = err.is_a?(SyntaxError) && err.message.match?(/end-of-input|unterminated|expected an? .end.|unexpected end of input/i)
  shown = err ? nil : (value.inspect rescue "(a value that can't be shown)")
  JSON.generate("stdout" => out, "value" => shown, "incomplete" => incomplete,
                "error" => err && { "friendly" => __iw_friendly(err).sub(" on line 1", ""), "raw" => "#{err.class}: #{err.message}" })
end
`

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
    modulePromise ||= loadVerified(data.wasmUrl)
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
