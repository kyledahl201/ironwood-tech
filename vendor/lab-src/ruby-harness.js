// The Ruby that runs inside ruby.wasm for the code lab and the classroom.
// Kept apart from the worker so it can be tested with real Ruby in Node
// (vendor/lab-src/test).
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

export const HARNESS = HELPERS + String.raw`
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
export const CONSOLE_SETUP = HELPERS + String.raw`
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
  # Ruby ran out of input before the code was finished (an open def, block,
  # string or bracket): the console should wait for more. "expecting
  # end-of-input" is the opposite case, a finished line with something extra.
  incomplete = err.is_a?(SyntaxError) && err.message.match?(/unexpected end-of-input|unterminated|meets end of file/i)
  shown = err ? nil : (value.inspect rescue "(a value that can't be shown)")
  JSON.generate("stdout" => out, "value" => shown, "incomplete" => incomplete,
                "error" => err && { "friendly" => __iw_friendly(err).sub(" on line 1", ""), "raw" => "#{err.class}: #{err.message}" })
end
`
