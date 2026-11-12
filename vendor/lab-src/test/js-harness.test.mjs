// Runs the classroom's JavaScript bench under Node, in a scope of its own
// (node:vm) so the student's names never touch the test's, and the
// classroom's runner (lib/code_runner.js) on top of it.
import { test } from "node:test"
import assert from "node:assert/strict"
import vm from "node:vm"
import { JsBench, inspect, complete, keepNames, lastStatement, patternEnd, scan, friendly } from "../js-harness.js"
import { CodeRunner } from "../../../app/javascript/lib/code_runner.js"

// A fresh realm, shaped like the worker's: code runs through indirect eval in its global scope.
function realm() {
  const context = vm.createContext({ setTimeout })
  const indirect = vm.runInContext("(0, eval)", context)
  return { evaluate: code => indirect(code), Function: vm.runInContext("Function", context), global: vm.runInContext("globalThis", context) }
}
const bench = new JsBench(realm())
const line = text => bench.console_({ op: "eval", line: text })
const values = checks => bench.console_({ op: "values", checks }).checks
const reset = () => bench.console_({ op: "reset" })
const run = (code, checks = []) => bench.run({ code, checks })

test("the console shows each entry's value and keeps names", () => {
  reset()
  assert.deepEqual(line("1 + 2"), { stdout: "", value: "3", incomplete: false, error: null })
  assert.equal(line('let school = "Ironwood"').value, null) // a declaration shows nothing
  assert.equal(line("school").value, "'Ironwood'")
  assert.equal(line("school.length").value, "8")
  assert.equal(line("const limit = 3").value, null)
  assert.equal(line("limit + 1").value, "4")
  assert.equal(line("school = 'Oak'").value, "'Oak'") // an assignment shows what was assigned
  assert.deepEqual(line('console.log("hi", [1, 2], { a: 1 })'), { stdout: "hi [ 1, 2 ] { a: 1 }\n", value: null, incomplete: false, error: null })
  assert.equal(line("_").value, "'Oak'") // the last value shown
  assert.equal(line("let nothing").value, null)
  assert.equal(line("nothing").value, "undefined") // asking for a name with no value says so
  assert.equal(line("{ a: 1, b: 'x' }").value, "{ a: 1, b: 'x' }") // an object, not a block
  assert.equal(line("class Dog { constructor(name) { this.name = name } }").value, null)
  assert.equal(line("new Dog('Rex')").value, "Dog { name: 'Rex' }")
  assert.equal(line("let a = 1; let b = 2; a + b").value, "3")
  assert.equal(line("for (let i = 0; i < 3; i++) { a += i }").error, null)
  assert.match(line("i").error.raw, /ReferenceError/) // a loop's own variable stays inside the loop
  assert.equal(line("a").value, "4")
})

test("the console waits while a bracket is open", () => {
  reset()
  assert.deepEqual(line("function double(n) {"), { stdout: "", value: null, incomplete: true, error: null })
  assert.equal(line("function double(n) {\n  return n * 2").incomplete, true)
  assert.equal(line("function double(n) {\n  return n * 2\n}").error, null)
  assert.equal(line("double(21)").value, "42")
  assert.equal(line("const xs = [1,").incomplete, true)
  assert.equal(line("const xs = [1,\n2]").incomplete, false)
  assert.equal(line("xs.map(n => double(n))").value, "[ 2, 4 ]")
  assert.equal(line("double(1))").incomplete, false) // one bracket too many is a mistake, not an unfinished entry
  assert.match(line("double(1))").error.raw, /^SyntaxError/)
})

test("complete() and scan() read brackets, text, templates and comments", () => {
  const done = ["let x = 1", "f(1)", "if (a) { b() }", "'(' + \"[\" + `{`", "x // (", "/* ( */ x", "`a ${ {b: 1}.b } c`", "s = 'unclosed", "f(1))", "", "a = [1,\n2]", "`${a}${b}`", "x = '\\''"]
  const waiting = ["f(", "if (a) {", "[1,", "`a", "`a ${b", "/* note", "x = {\n a: 1,", "function f() {\n  return (1\n}"]
  done.forEach(code => assert.equal(complete(code), true, code))
  assert.equal(complete("function f() {\n  return (1\n}"), true) // a mismatch: JavaScript reports it
  waiting.slice(0, -1).forEach(code => assert.equal(complete(code), false, code))
  assert.deepEqual(scan("a(\n  b[\n").open.map(o => [o.ch, o.line]), [["(", 1], ["[", 2]])
  assert.deepEqual(scan("x = 'abc\ny").unfinished, { what: "string", line: 1, sameLine: true })
  assert.equal(scan("`one\ntwo").unfinished.what, "template")
  assert.deepEqual(scan("f(1))").stray, { ch: ")", line: 1, wanted: null })
})

test("keepNames turns top-level let, const and class into names that last, and nothing else", () => {
  assert.equal(keepNames("let a = 1"), "var a = 1")
  assert.equal(keepNames("const b = 2; let c = 3"), "var b = 2; var c = 3")
  assert.equal(keepNames("class A { m() { let x = 1 } }"), "var A = class A { m() { let x = 1 } }")
  assert.equal(keepNames("for (let i = 0; i < 2; i++) { const k = i }"), "for (let i = 0; i < 2; i++) { const k = i }")
  assert.equal(keepNames("function f() {\n  let inside = 1\n}\nlet after = 2"), "function f() {\n  let inside = 1\n}\nvar after = 2")
  assert.equal(keepNames("s = 'let x = 1'"), "s = 'let x = 1'")
  assert.equal(keepNames("// let x\nlet y = `const z`"), "// let x\nvar y = `const z`")
  assert.equal(keepNames("letter = 1"), "letter = 1")
  assert.equal(keepNames("x = 1\nlet y = 2"), "x = 1\nvar y = 2")
})

test("values print the way a JavaScript console prints them", () => {
  assert.equal(inspect("it's"), "'it\\'s'")
  assert.equal(inspect(3.5), "3.5")
  assert.equal(inspect(-0), "-0")
  assert.equal(inspect(null), "null")
  assert.equal(inspect(undefined), "undefined")
  assert.equal(inspect(true), "true")
  assert.equal(inspect([]), "[]")
  assert.equal(inspect([1, "a", [2, [3, [4, [5]]]]]), "[ 1, 'a', [ 2, [ 3, [Array] ] ] ]") // deep nesting is cut short
  assert.equal(inspect({}), "{}")
  assert.equal(inspect({ name: "Ada", "two words": 1, nested: { ok: true } }), "{ name: 'Ada', 'two words': 1, nested: { ok: true } }")
  assert.equal(inspect(function double() {}), "[Function: double]")
  assert.equal(inspect(() => 1), "[Function: (anonymous)]")
  assert.equal(inspect(class Cat {}), "[class Cat]")
  assert.equal(inspect(new Map([["a", 1]])), "Map(1) { 'a' => 1 }")
  assert.equal(inspect(new Set([1, 2])), "Set(2) { 1, 2 }")
  assert.equal(inspect(new Error("boom")), "Error: boom")
  assert.equal(inspect(10n), "10n")
  const loop = { name: "loop" }; loop.self = loop
  assert.equal(inspect(loop), "{ name: 'loop', self: [Circular] }")
  assert.equal(inspect(Array.from({ length: 103 }, (_, i) => i)).endsWith("99, ... 3 more ]"), true)
})

test("the editor runs a program in a scope of its own and reads its output", async () => {
  const program = 'function shout(text) {\n  return text.toUpperCase() + "!"\n}\n\nconsole.log(shout("ab initio"))\n'
  const result = await run(program, [{ type: "stdout", expected: "AB INITIO!\n" }, { type: "method_returns", call: 'shout("owl")', expected: '"OWL!"' }, { type: "method_stdout_empty", call: 'shout("x")' }, { type: "method_returns", call: 'shout("owl")', expected: '"owl"' }])
  assert.equal(result.stdout, "AB INITIO!\n")
  assert.equal(result.error, null)
  assert.deepEqual(result.checks, [null, { ok: true, expected: "'OWL!'", actual: "'OWL!'" }, { ok: true, expected: "(prints nothing)", actual: "(prints nothing)" }, { ok: false, expected: "'owl'", actual: "'OWL!'" }])

  // Nothing leaks from one run to the next, or into the console.
  await run("let secret = 1\nconst other = 2\nfunction helper() {}")
  assert.match((await run("console.log(typeof secret, typeof other, typeof helper)")).stdout, /^undefined undefined undefined\n$/)
  reset()
  assert.match(line("secret").error.raw, /ReferenceError/)
  // A check can read let and const names, and a function that prints fails "prints nothing".
  const noisy = await run("const rate = 25\nlet hours = 4\nfunction pay() { console.log('paying'); return rate * hours }", [{ type: "method_returns", call: "pay()", expected: "100" }, { type: "method_stdout_empty", call: "pay()" }, { type: "value_is", call: "hours", expected: "4" }, { type: "method_returns", call: "nope()", expected: "1" }])
  assert.deepEqual(noisy.checks.map(c => c.ok), [true, false, true, false])
  assert.equal(noisy.checks[1].actual, "paying\n")
  assert.match(noisy.checks[3].actual, /doesn't know the name nope/)
  assert.equal(noisy.stdout, "") // what a check's call prints is not the program's output
})

test("promises and zero-delay timers get to print before the output is read", async () => {
  const result = await run('Promise.resolve(5).then(v => console.log("later", v))\nsetTimeout(() => console.log("timer"), 0)\nconsole.log("first")')
  assert.equal(result.stdout, "first\nlater 5\ntimer\n")
})

test("expected values compare by value", async () => {
  const check = async (call, expected) => (await run("const list = [5, 4]\nconst who = { name: 'Ada', tags: ['a'] }", [{ type: "method_returns", call, expected }])).checks[0].ok
  assert.equal(await check("list", "[5, 4]"), true)
  assert.equal(await check("list", "[4, 5]"), false)        // order counts in an array
  assert.equal(await check("list", "[5, 4, 0]"), false)
  assert.equal(await check("who", "{ tags: ['a'], name: 'Ada' }"), true) // key order doesn't
  assert.equal(await check("who", "{ name: 'Ada' }"), false)
  assert.equal(await check("0.1 + 0.2", "0.3"), true)
  assert.equal(await check("'3'", "3"), false)              // text is not a number
  assert.equal(await check("1", "true"), false)
  assert.equal(await check("null", "undefined"), false)
  assert.equal(await check("undefined", "undefined"), true)
  assert.equal(await check("NaN", "NaN"), true)
  assert.equal(await check("[]", "[]"), true)
  assert.equal(await check("'x'.repeat(3)", '"x".repeat(3)'), true) // a small expression works as an expected value
})

test("errors are explained in plain words, with JavaScript's own message and the line", async () => {
  const cases = [
    ["let a = 1\nconsole.log(a)\nconsole.log(nmae)", /doesn't know the name nmae/, "ReferenceError: nmae is not defined (line 3)"],
    ["const text = 'x'\ntext.toUppercase()", /text\.toUppercase isn't a function/, "TypeError: text.toUppercase is not a function (line 2)"],
    ["let user\nuser.name", /asked for \.name on something that is undefined/, "TypeError: Cannot read properties of undefined (reading 'name') (line 2)"],
    ["const k = 1\nk = 2", /A const can't be given a new value/, "TypeError: Assignment to constant variable. (line 2)"],
    ["console.log(q)\nlet q = 1", /q is used before the line that declares it/, "ReferenceError: Cannot access 'q' before initialization (line 1)"],
    ["let a = 1\nlet a = 2", /a is declared twice/, "SyntaxError: Identifier 'a' has already been declared"],
    ["function f() {\n  return (1\n}", /The \} on line 3 doesn't match the \( opened on line 2/, /^SyntaxError: /],
    ["function f() {\n  return 1\n", /The \{ opened on line 1 is never closed/, /^SyntaxError: /],
    ["let s = \"abc\nlet t = 1", /starts on line 1 is missing its closing quote/, /^SyntaxError: /],
    ["let x = 1\nf(x))", /The \) on line 2 closes something that was never opened/, /^SyntaxError: /],
    ["let t = `abc\n", /backtick text that starts on line 1 is never closed/, /^SyntaxError: /],
    ["let x = 5 5", /couldn't read that/, /^SyntaxError: /],
    ["function f() { return f() }\nf()", /kept calling itself/, /^RangeError: /],
    ["for (const n of 5) {}", /can't be looped over/, /^TypeError: .*not iterable/],
    ["throw new Error('my own')", /stopped with an error/, "Error: my own"],
    ["throw 'boom'", /threw a value that isn't an Error/, "Uncaught 'boom'"]
  ]
  for (const [code, plain, raw] of cases) {
    const { error, checks } = await run(code, [{ type: "method_returns", call: "1", expected: "1" }])
    assert.ok(error, code)
    assert.match(error.friendly, plain, code)
    raw instanceof RegExp ? assert.match(error.raw, raw, code) : assert.equal(error.raw, raw, code)
    assert.deepEqual(checks, [null]) // a program that stopped fails its checks
  }
  assert.equal((await run("console.log('before')\nnull.x")).stdout, "before\n") // what printed before the error is kept
  // Safari words the same mistakes differently; both are understood.
  assert.match(friendly("ReferenceError", "Can't find variable: nmae"), /doesn't know the name nmae/)
  assert.match(friendly("TypeError", "undefined is not an object (evaluating 'user.name')"), /something that is undefined, in user\.name/)
  assert.match(friendly("TypeError", "Attempted to assign to readonly property."), /A const can't be given a new value/)
  assert.match(friendly("SyntaxError", "Cannot declare a let variable twice: 'a'.".replace(/\.$/, "")), /a is declared twice/)
  assert.equal(friendly("EvalError", "anything"), "JavaScript stopped with an error.")
})

test("console checks ask the live console, and reset clears the student's names only", () => {
  reset()
  line("let hours = 8"); line("function double(n) { return n * 2 }")
  const checks = [{ type: "value_is", call: "hours", expected: "10" }, { type: "value_is", call: "double(4)", expected: "8" }, { type: "value_is", call: "missing", expected: "1" }]
  assert.deepEqual(values(checks), [{ ok: false, expected: "10", actual: "8" }, { ok: true, expected: "8", actual: "8" }, { ok: false, actual: "not there yet" }])
  reset()
  assert.match(line("hours").error.raw, /ReferenceError: hours is not defined/)
  assert.match(line("double").error.raw, /ReferenceError/)
  assert.equal(line("Math.max(1, 2)").value, "2")              // the language itself is untouched
  assert.equal(line("console.log('still here')").stdout, "still here\n")
})

// The classroom's runner on top of the real bench. A new worker starts with a
// fresh scope, as restarting the real worker does; the endless loop never answers.
class JsWorker {
  constructor() { this.bench = new JsBench(realm()) }
  async postMessage(message) {
    if (/while \(true\)/.test(message.line || message.code || "")) return
    const result = message.console ? await this.bench.console_({ op: message.op, line: message.line || "", checks: message.checks || [] }) : await this.bench.run({ code: message.code || "", checks: message.checks || [] })
    queueMicrotask(() => this.onmessage({ data: { id: message.id, ok: true, result } }))
  }
  terminate() {}
}

test("a function typed over several lines runs once, and a stopped loop keeps the student's names", async () => {
  const status = []
  const runner = new CodeRunner({ name: "JavaScript", workerUrl: "x", runtimeUrl: "", megabytes: null, timeoutMs: 40, WorkerClass: JsWorker, onStatus: text => status.push(text) })
  await runner.warm()
  assert.equal(status[0], "Loading JavaScript…") // nothing to download, so no size is promised

  const typed = []
  const type = async text => { const result = await runner.type(text); typed.push(result.incomplete ? "…" : ">"); return result }
  await type("let rate = 25")
  await type("function pay(hours) {")
  await type("  return rate * hours")
  assert.equal(runner.partial, "function pay(hours) {\n  return rate * hours\n")
  assert.equal((await type("}")).error, null)
  await type("nope()")                                  // an error is not replayed later
  assert.equal((await type("pay(4)")).value, "100")
  assert.deepEqual(typed, [">", "…", "…", ">", ">", ">"])
  assert.deepEqual(runner.history, ["let rate = 25", "function pay(hours) {\n  return rate * hours\n}", "pay(4)"])

  const stopped = await type("while (true) {}")
  assert.equal(stopped.stopped, true)
  assert.match(stopped.error.friendly, /Look for a loop that never ends\. JavaScript was restarted and your earlier lines were run again, so your variables are back\./)
  await runner.restoring
  assert.equal((await type("pay(2)")).value, "50")
  assert.deepEqual(await runner.values([{ type: "value_is", call: "rate", expected: "25" }]), [{ ok: true, expected: "25", actual: "25" }])

  await type("function broken(")
  runner.cancel()                                       // Ctrl+C gives up on a half-typed entry
  assert.equal((await type("rate")).value, "25")

  const program = await runner.run("while (true) {}")
  assert.match(program.error.friendly, /so it was stopped/)
  await runner.restoring
  assert.equal((await type("pay(1)")).value, "25")      // the editor's stopped run didn't cost the console its names
  await runner.resetConsole()
  assert.match((await type("rate")).error.raw, /ReferenceError/)
  runner.dispose()
})

test("a pattern with brackets in it is read as a pattern, not as open brackets", () => {
  reset()
  for (const entry of ["const re = /\\(/.test('a(')", "/[)\\]}]/g.test(')')", "'a/b'.split(/[/(]/)", "x = /{/", "return /\\[/", "f(/\\(/, /\\{/)", "/'/.test(s)", "/`/.test(s)", "/\\//.test('(')"]) {
    assert.equal(complete(entry), true, entry)
  }
  // Division is still division, and a real open bracket still waits.
  assert.equal(complete("total / 2 / (1"), false)
  assert.equal(complete("(a + b) / 2"), true)
  assert.equal(complete("list[0] / (2"), false)
  assert.equal(complete("const re = /\\(/.test("), false)
  assert.equal(patternEnd("a / b / c", 2), -1)
  assert.equal(patternEnd("x = /ab+/gi", 4), 10)
  assert.equal(patternEnd("// a comment", 0), -1)

  assert.equal(line("const hasBracket = /\\(/.test('a(')").value, null)
  assert.equal(line("hasBracket").value, "true")
  assert.equal(line("'a/b(c'.split(/[/(]/)").value, "[ 'a', 'b', 'c' ]")
  assert.equal(line("'let it be'.replace(/let (\\w+)/, 'const $1')").value, "'const it be'")
  assert.equal(line("let q = 8; q / 2 / 2").value, "2")
  // A let inside a pattern is left alone.
  assert.equal(keepNames("const r = /;let x/\nlet y = 1"), "var r = /;let x/\nvar y = 1")
})

test("await works at the top of a console entry, and its names are kept", async () => {
  reset()
  assert.equal(line("async function three() { return 3 }").value, null)
  assert.equal((await line("await three()")).value, "3")
  assert.deepEqual(await line("const r = await three()"), { stdout: "", value: null, incomplete: false, error: null }) // a declaration shows nothing
  assert.equal(line("r").value, "3")
  assert.equal((await line("const { a, b } = await Promise.resolve({ a: 1, b: 2 })")).error, null)
  assert.equal(line("a + b").value, "3")
  assert.equal((await line("const [x, y] = await Promise.all([three(), three()]); x + y")).value, "6")
  assert.equal(line("x").value, "3")
  // Functions, classes and later lines in the same entry.
  assert.equal((await line("function one() { return 1 }\nclass Dog {}\nlet n = await three()\nn = n + one()")).value, "4")
  assert.equal(line("one() + n").value, "5")
  assert.equal(line("new Dog() instanceof Dog").value, "true")
  assert.equal((await line("await new Promise(done => setTimeout(() => done('late'), 20))")).value, "'late'")
  assert.deepEqual(await line("console.log(await three())"), { stdout: "3\n", value: null, incomplete: false, error: null })
  assert.equal(line("_").value, "'late'") // printing didn't replace the last value

  const failed = await line("await Promise.reject(new Error('nope'))")
  assert.equal(failed.error.raw, "Error: nope")
  const typo = await line("await nmae")
  assert.match(typo.error.friendly, /doesn't know the name nmae/)
  const outside = await line("function h() { await three() }")
  assert.match(outside.error.friendly, /^await only works at the top of your code or inside a function marked async\./)
  assert.match(outside.error.raw, /^SyntaxError/)
})

test("keepNames can assign an entry's names as globals, and lastStatement finds the last one", () => {
  const globals = code => keepNames(code, { asGlobals: true })
  assert.equal(globals("const r = await f()"), "r = await f()")
  assert.equal(globals("let { a, b } = await g()"), "( { a, b } = await g())")
  assert.equal(globals("const [x, y] = await g(); x"), "[x, y] = await g(); x")
  assert.equal(globals("function f() { let inner = 1 }"), "f = function f() { let inner = 1 }")
  assert.equal(globals("async function f() {}"), "f = async function f() {}")
  assert.equal(globals("class Dog {}"), "Dog = class Dog {}")
  assert.equal(globals("for (let i = 0; i < 2; i++) { await f() }"), "for (let i = 0; i < 2; i++) { await f() }")
  assert.deepEqual(lastStatement("a = 1; b = 'x;y'\nf(a,\n b);"), { before: "a = 1; b = 'x;y'\n", last: "f(a,\n b)" })
  assert.deepEqual(lastStatement("a / 2"), { before: "", last: "a / 2" })
})

test("a promise shows its state the way a console does", async () => {
  reset()
  line("async function three() { return 3 }")
  assert.equal((await line("three()")).value, "Promise {<fulfilled>: 3}")
  assert.equal((await line("Promise.resolve({ ok: true })")).value, "Promise {<fulfilled>: { ok: true }}")
  assert.equal((await line("new Promise(() => {})")).value, "Promise {<pending>}")
  assert.equal((await line("Promise.reject(new Error('no'))")).value, "Promise {<rejected>: Error: no}")
  assert.equal((await line("const waiting = three()")).value ?? null, null)
  assert.equal((await line("await waiting")).value, "3")
})

test("await works at the top of an editor program too", async () => {
  const result = await run("const v = await Promise.resolve(7)\nconsole.log(v)\nfunction twice() { return v * 2 }", [{ type: "method_returns", call: "twice()", expected: "14" }])
  assert.equal(result.error, null)
  assert.equal(result.stdout, "7\n")
  assert.deepEqual(result.checks.map(c => c.ok), [true])
  const late = await run("let a = 1\nawait Promise.resolve()\nnull.x")
  assert.match(late.error.raw, /\(line 3\)$/)
  const outside = await run("function h() {\n  await f()\n}")
  assert.match(outside.error.friendly, /^await only works at the top/)
})
