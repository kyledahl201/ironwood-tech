import { test } from "node:test"
import assert from "node:assert/strict"
import { evaluateChecks, toRegex, normalize } from "../../app/javascript/lib/checks.js"
import { TerminalSim } from "../../app/javascript/lib/terminal_sim.js"

const ok = async (check, context) => (await evaluateChecks([check], context))[0].ok

test("patterns written the Ruby way work in the browser", () => {
  assert.ok(toRegex("^pwd$").test("first\npwd"))
  assert.ok(toRegex("(?i)already INSTALLED").test("Already installed"))
  assert.ok(!toRegex("already INSTALLED").test("Already installed"))
  assert.ok(toRegex("\\Aone").test("one\ntwo"))
  assert.ok(!toRegex("\\Atwo").test("one\ntwo"))
  assert.equal(toRegex("(unclosed"), null)
  assert.equal(normalize("a  \r\nb\n\n"), "a\nb")
})

test("command_matches passes when any line typed in the step matches", async () => {
  const check = { type: "command_matches", expected: "^ls$" }
  assert.equal(await ok(check, { commands: ["pwd", "ls"] }), true)
  assert.equal(await ok(check, { commands: ["ls -la"] }), false)
  assert.equal(await ok({ type: "command_matches", expected: "(bad" }, { commands: ["(bad"] }), false)
})

test("output_matches reads console output, pasted Mac output, or the program's output", async () => {
  const check = { type: "output_matches", expected: "^Ready to install$" }
  assert.equal(await ok(check, { outputs: ["nope", "Ready to install"] }), true)
  assert.equal(await ok(check, { outputs: ["Ready to install!"] }), false)
  const mac = { type: "output_matches", expected: "Homebrew \\d+\\.\\d+" }
  assert.equal(await ok(mac, { pasted: "Homebrew 4.4.2\r\n" }), true)
  assert.equal(await ok(mac, { pasted: "zsh: command not found: brew" }), false)
  assert.equal(await ok(check, { result: { stdout: "Ready to install\n" } }), true)
  assert.equal(await ok(check, { result: { stdout: "" } }), false)
})

test("folder and file checks look at the practice computer", async () => {
  const sim = new TerminalSim({ user: "sam" })
  const context = { sim }
  assert.equal(await ok({ type: "dir_exists", expected: "~/code" }, context), false)
  assert.equal(await ok({ type: "cwd_is", expected: "~/code" }, context), false)
  assert.equal(await ok({ type: "file_exists", expected: "~/code/hello.rb" }, context), false)
  assert.equal(await ok({ type: "file_contains", call: "~/code/hello.rb", expected: "puts" }, context), false)
  await sim.exec("mkdir code"); await sim.exec("cd code"); await sim.exec("echo 'puts 1' > hello.rb")
  assert.equal(await ok({ type: "dir_exists", expected: "~/code" }, context), true)
  assert.equal(await ok({ type: "cwd_is", expected: "~/code" }, context), true)
  assert.equal(await ok({ type: "file_exists", expected: "~/code/hello.rb" }, context), true)
  assert.equal(await ok({ type: "file_exists", expected: "~/code" }, context), false) // a folder is not a file
  assert.equal(await ok({ type: "file_contains", call: "~/code/hello.rb", expected: "puts" }, context), true)
  assert.equal(await ok({ type: "file_contains", call: "~/code/hello.rb", expected: "print" }, context), false)
})

test("stdout compares the program's output, forgiving only trailing space", async () => {
  const check = { type: "stdout", expected: "Ab initio\n" }
  assert.equal(await ok(check, { result: { stdout: "Ab initio  \n\n" } }), true)
  assert.equal(await ok(check, { result: { stdout: "ab initio\n" } }), false)
  assert.equal(await ok(check, { result: { stdout: "Ab initio\n", error: { friendly: "boom" } } }), false)
  assert.equal(await ok(check, { outputs: ["Ab initio"] }), true)
  assert.equal(await ok(check, { outputs: ["other"] }), false)
})

test("source checks read the editor's code, or what was typed in a console", async () => {
  assert.equal(await ok({ type: "source_includes", expected: ".each" }, { code: "list.each { }", result: {} }), true)
  assert.equal(await ok({ type: "source_includes", expected: ".each" }, { code: "for x in list", result: {} }), false)
  assert.equal(await ok({ type: "source_excludes", expected: "for " }, { code: "list.each { }", result: {} }), true)
  assert.equal(await ok({ type: "source_excludes", expected: "for " }, { code: "for x in list", result: {} }), false)
  assert.equal(await ok({ type: "source_excludes", expected: "for " }, { code: "  ", result: {} }), false) // nothing written yet
  assert.equal(await ok({ type: "source_matches", expected: "def\\s+double" }, { code: "def double(n)", result: {} }), true)
  assert.equal(await ok({ type: "source_matches", expected: "def\\s+double" }, { commands: ["x = 1"] }), false)
})

test("in the editor, Ruby's answers for method checks come from the worker", async () => {
  const checks = [{ type: "method_returns", call: "double(2)", expected: "4" }, { type: "method_stdout_empty", call: "double(2)" }]
  const pass = await evaluateChecks(checks, { code: "", result: { stdout: "", checks: [{ ok: true, actual: "4" }, { ok: true }] } })
  assert.deepEqual(pass.map(o => o.ok), [true, true])
  const fail = await evaluateChecks(checks, { code: "", result: { stdout: "", checks: [{ ok: false, actual: "nil" }, null] } })
  assert.deepEqual(fail.map(o => o.ok), [false, false])
  assert.equal(fail[0].actual, "gave nil")
})

test("in the console, value_is asks the live Ruby and reports what the value is now", async () => {
  const asked = []
  const runner = { values: async checks => { asked.push(...checks); return [{ ok: false, actual: "8" }, { ok: true, actual: "25" }, { ok: false, actual: "not there yet" }] } }
  const checks = [{ type: "value_is", call: "hours", expected: "10" }, { type: "command_matches", expected: "rate" },
                  { type: "value_is", call: "rate", expected: "25" }, { type: "value_is", call: "name", expected: '"Sam"' }]
  const outcomes = await evaluateChecks(checks, { commands: ["rate = 25"], runner })
  assert.deepEqual(outcomes.map(o => o.ok), [false, true, true, false])
  assert.equal(outcomes[0].actual, "now 8")
  assert.equal(outcomes[3].actual, "not set yet")
  assert.deepEqual(asked.map(c => c.call), ["hours", "rate", "name"])
  assert.equal(await ok(checks[0], { commands: [] }), false) // no Ruby loaded
})
