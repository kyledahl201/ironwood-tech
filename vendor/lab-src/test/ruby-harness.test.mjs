// Runs the lab's Ruby harness in real Ruby (ruby.wasm) under Node.
import { test, before } from "node:test"
import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/node"
import { HARNESS, CONSOLE_SETUP } from "../ruby-harness.js"

let module
before(async () => {
  const wasm = new URL("../../../public/lab/ruby.wasm", import.meta.url)
  module = await WebAssembly.compile(await readFile(wasm))
})

async function console_() {
  const { vm } = await DefaultRubyVM(module, { consolePrint: false })
  vm.eval(CONSOLE_SETUP)
  const call = payload => { globalThis.__iwPayload = JSON.stringify(payload); return JSON.parse(vm.eval("__iw_console").toString()) }
  return {
    line: text => call({ op: "eval", line: text, checks: [] }),
    values: checks => call({ op: "values", line: "", checks }).checks
  }
}

async function program(code, checks = []) {
  const { vm } = await DefaultRubyVM(module, { consolePrint: false })
  globalThis.__iwPayload = JSON.stringify({ code, checks })
  return JSON.parse(vm.eval(HARNESS).toString())
}

test("the console gives each line's value and keeps variables", async () => {
  const irb = await console_()
  assert.deepEqual(irb.line("40 + 2"), { stdout: "", value: "42", incomplete: false, error: null })
  assert.equal(irb.line("hours = 8").value, "8")
  assert.equal(irb.line("hours * 25").value, "200")
  assert.equal(irb.line('"Ironwood".class').value, "String")
})

test("puts prints and gives back nil, so x = puts \"hi\" leaves x nil", async () => {
  const irb = await console_()
  const result = irb.line('x = puts "hi"')
  assert.equal(result.stdout, "hi\n")
  assert.equal(result.value, "nil")
  assert.deepEqual(irb.values([{ type: "value_is", call: "x", expected: "nil" }]).map(c => c.ok), [true])
})

test("an unfinished def, block, string or bracket waits for the rest", async () => {
  const irb = await console_()
  for (const start of ["def twice(n)", "def twice(n)\n  n * 2", "[1, 2].each do |n|", "if true", 'name = "unfinished', "list = [1, 2,", "total = (1 +"]) {
    const result = irb.line(start)
    assert.equal(result.incomplete, true, `${JSON.stringify(start)} should wait for more`)
  }
  const done = irb.line("def twice(n)\n  n * 2\nend")
  assert.equal(done.incomplete, false)
  assert.equal(done.value, ":twice")
  assert.equal(irb.line("twice(4)").value, "8")
})

test("a real mistake is an error, not a wait, and reads in plain words", async () => {
  const irb = await console_()
  const typo = irb.line("nope")
  assert.equal(typo.incomplete, false)
  assert.match(typo.error.friendly, /Ruby doesn't know what nope is/)
  assert.match(typo.error.raw, /^NameError/)
  const syntax = irb.line("1 +* 2 )")
  assert.equal(syntax.incomplete, false)
  assert.match(syntax.error.friendly, /Ruby couldn't read your code/)
  assert.match(irb.line("1 / 0").error.friendly, /divided by zero/)
})

test("value checks in the console pass, fail, and cope with a name that isn't set", async () => {
  const irb = await console_()
  irb.line("rate = 25")
  irb.line("def greet = puts('hi')")
  const [right, wrong, unset, quiet, noisy] = irb.values([
    { type: "value_is", call: "rate", expected: "25" },
    { type: "value_is", call: "rate", expected: "30" },
    { type: "value_is", call: "missing", expected: "1" },
    { type: "method_stdout_empty", call: "rate" },
    { type: "method_stdout_empty", call: "greet" }
  ])
  assert.equal(right.ok, true)
  assert.deepEqual([wrong.ok, wrong.actual], [false, "25"])
  assert.deepEqual([unset.ok, unset.actual], [false, "not there yet"])
  assert.equal(quiet.ok, true)
  assert.equal(noisy.ok, false)
})

test("a program's output, errors and method checks", async () => {
  const good = await program('def double(n) = n * 2\nputs "hi"\n', [
    { type: "method_returns", call: "double(2)", expected: "4" },
    { type: "method_returns", call: "double(2)", expected: "5" },
    { type: "method_stdout_empty", call: "double(2)" },
    { type: "stdout", call: "", expected: "hi\n" },
    { type: "method_returns", call: "double(2)", expected: "not ruby at all (" }
  ])
  assert.equal(good.stdout, "hi\n")
  assert.equal(good.error, null)
  assert.deepEqual(good.checks.map(c => c && c.ok), [true, false, true, null, false])

  const noisy = await program("def shout(n)\n  puts n\nend\n", [{ type: "method_returns", call: "shout(1)", expected: "1" }, { type: "method_stdout_empty", call: "shout(1)" }])
  assert.deepEqual(noisy.checks.map(c => c.ok), [false, false])

  const broken = await program("puts 1\nputs oops\n")
  assert.equal(broken.stdout, "1\n")
  assert.match(broken.error.friendly, /Ruby doesn't know what oops is on line 2/)
})
