// Runs the classroom's SQL bench on real SQLite (sql.js) under Node, and the
// classroom's runner (lib/code_runner.js) on top of it.
import { test, before } from "node:test"
import assert from "node:assert/strict"
import { createRequire } from "node:module"
import { createHash } from "node:crypto"
import { readFileSync } from "node:fs"
import { SqlBench, complete, table, friendly } from "../sql-harness.js"
import { CodeRunner } from "../../../app/javascript/lib/code_runner.js"

const require = createRequire(import.meta.url)
let SQL, bench
before(async () => {
  SQL = await require("sql.js/dist/sql-wasm.js")()
  bench = new SqlBench(SQL)
})

const line = text => bench.console({ op: "eval", line: text })
const values = checks => bench.console({ op: "values", checks }).checks
const reset = () => bench.console({ op: "reset" })

test("the binary the worker and bin/fetch-sqlite pin is the one these tests run", () => {
  const sha = createHash("sha256").update(readFileSync(require.resolve("sql.js/dist/sql-wasm.wasm"))).digest("hex")
  const browser = createHash("sha256").update(readFileSync(require.resolve("sql.js/dist/sql-wasm-browser.wasm"))).digest("hex")
  assert.equal(browser, sha)
  assert.match(readFileSync(new URL("../sql-worker.js", import.meta.url), "utf8"), new RegExp(`WASM_SHA256 = "${sha}"`))
  assert.match(readFileSync(new URL("../../../bin/fetch-sqlite", import.meta.url), "utf8"), new RegExp(`SHA256="${sha}"`))
  const version = JSON.parse(readFileSync(new URL("../node_modules/sql.js/package.json", import.meta.url), "utf8")).version
  assert.match(readFileSync(new URL("../../../bin/fetch-sqlite", import.meta.url), "utf8"), new RegExp(`VERSION="${version}"`))
})

test("a query prints a table with a header, a rule and a row count", () => {
  const result = bench.run({ code: "SELECT title, year FROM books WHERE year > 2020 ORDER BY year;" })
  assert.equal(result.error, null)
  assert.equal(result.stdout, [
    "title                  | year",
    "-----------------------+-----",
    "A Field Guide to Quiet | 2021",
    "Salt and Signal        | 2022",
    "(2 rows)", ""].join("\n"))
  assert.equal(bench.run({ code: "SELECT genre FROM books WHERE id = 9" }).stdout, "genre\n-----\nNULL\n(1 row)\n") // empty values show as NULL; no semicolon needed in the editor
  assert.equal(bench.run({ code: "SELECT id FROM books WHERE id > 100;" }).stdout, "id\n--\n(0 rows)\n")
  assert.equal(bench.run({ code: "-- nothing but a comment\n" }).stdout, "")
})

test("long results are cut short on screen but counted in full", () => {
  const result = bench.run({ code: "WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c LIMIT 150) SELECT x FROM c;", checks: [{ type: "rows_are", call: "", expected: JSON.stringify(Array.from({ length: 150 }, (_, i) => [i + 1])) }] })
  const lines = result.stdout.trimEnd().split("\n")
  assert.equal(lines.length, 2 + 100 + 2)
  assert.deepEqual(lines.slice(-2), ["… and 50 more", "(150 rows)"])
  assert.equal(result.checks[0].ok, true) // the check still sees every row
  assert.equal(table(["n"], [[1]], 1), "n\n-\n1\n(1 row)\n")
})

test("statements that change data say how many rows they touched", () => {
  const result = bench.run({ code: [
    "INSERT INTO members (name, joined_on) VALUES ('Gus Hale', '2026-11-12'), ('Hye Min', '2026-11-12');",
    "UPDATE books SET copies = copies + 1 WHERE author = 'Mara Ellison';",
    "DELETE FROM loans WHERE id = 12;",
    "CREATE TABLE shelves (id INTEGER PRIMARY KEY, label TEXT);",
    "SELECT count(*) AS n FROM members;"].join("\n") })
  assert.equal(result.stdout, "2 rows added.\n2 rows changed.\n1 row removed.\nDone.\nn\n-\n8\n(1 row)\n")
})

test("every editor run starts from a fresh copy of the library", () => {
  bench.run({ code: "DELETE FROM loans; DROP TABLE loans; CREATE TABLE extra (x);" })
  const result = bench.run({ code: "SELECT (SELECT count(*) FROM books), (SELECT count(*) FROM members), (SELECT count(*) FROM loans);", checks: [{ type: "rows_are", call: "", expected: "[[9, 6, 12]]" }, { type: "rows_are", call: "SELECT count(*) FROM sqlite_master WHERE name = 'extra'", expected: "[[0]]" }] })
  assert.deepEqual(result.checks.map(c => c.ok), [true, true])
})

test("errors are explained in plain words, with SQLite's own message kept", () => {
  const cases = [
    ["SELECT * FROM memberz;", /no table named memberz/, "Error: no such table: memberz"],
    ["SELECT nam FROM members;", /no column named nam/, "Error: no such column: nam"],
    ["SELECT name FORM members;", /SQL got lost at members|SQL got lost at FORM/, /^Error: near "(FORM|members)": syntax error$/],
    ["SELECT (1;", /got lost|stops before/, /^Error: /],
    ["INSERT INTO books (id, title, author) VALUES (1, 'x', 'y');", /already used in books\.id/, "Error: UNIQUE constraint failed: books.id"],
    ["INSERT INTO books (title) VALUES ('x');", /books\.author can't be left empty/, "Error: NOT NULL constraint failed: books.author"],
    ["INSERT INTO loans (book_id, member_id, loaned_on) VALUES (99, 1, '2026-11-12');", /points at a row that doesn't exist/, "Error: FOREIGN KEY constraint failed"],
    ["SELECT id FROM books JOIN loans ON book_id = books.id;", /More than one table here has a column named id/, "Error: ambiguous column name: id"],
    ["SELECT genre FROM books WHERE count(*) > 1 GROUP BY genre;", /use HAVING after GROUP BY/, /^Error: misuse of aggregate/],
    ["CREATE TABLE books (id);", /A table named books is already there/, /^Error: table "?books"? already exists$/],
    ["SELECT shout(title) FROM books;", /no function named shout/, "Error: no such function: shout"]
  ]
  for (const [sql, plain, raw] of cases) {
    const { error, stdout } = bench.run({ code: sql })
    assert.ok(error, sql)
    assert.match(error.friendly, plain, sql)
    raw instanceof RegExp ? assert.match(error.raw, raw, sql) : assert.equal(error.raw, raw, sql)
    assert.equal(stdout, "")
  }
  assert.equal(friendly("something new"), "SQL couldn't run that.")
})

test("a script that fails part-way keeps what ran, says which statement failed, and fails its checks", () => {
  const result = bench.run({ code: "SELECT 1 AS one;\nSELECT 2 AS two;\nSELECT * FROM nowhere;\nSELECT 4;", checks: [{ type: "rows_are", call: "", expected: "[[2]]" }, { type: "stdout", expected: "x" }] })
  assert.equal(result.stdout, "one\n---\n1\n(1 row)\ntwo\n---\n2\n(1 row)\n")
  assert.equal(result.error.raw, "Error: no such table: nowhere (statement 3)")
  assert.deepEqual(result.checks, [{ ok: false, plain: true, actual: "Fix the error first." }, null])
  // a failure while a statement runs (not while it is read) is numbered the same way
  assert.equal(bench.run({ code: "SELECT 1; INSERT INTO books (title) VALUES ('x');" }).error.raw, "Error: NOT NULL constraint failed: books.author (statement 2)")
  assert.equal(bench.run({ code: "INSERT INTO books (title) VALUES ('x');" }).error.raw, "Error: NOT NULL constraint failed: books.author")
})

test("rows_are compares the last result in order; rows_any_order ignores order", () => {
  const sorted = '[["Night Trains to Avery"], ["Rivers Under Glass"], ["The Long Division"]]'
  const checks = [{ type: "rows_are", call: "", expected: sorted }, { type: "rows_any_order", call: "", expected: sorted }, { type: "columns_are", call: "", expected: "Title" }]
  const inOrder = bench.run({ code: "SELECT title FROM books WHERE genre = 'mystery' ORDER BY title;", checks })
  assert.deepEqual(inOrder.checks.map(c => c.ok), [true, true, true])
  const byId = bench.run({ code: "SELECT title FROM books WHERE genre = 'mystery';", checks })
  assert.deepEqual(byId.checks.map(c => c.ok), [false, true, true])
  assert.equal(byId.checks[0].actual, "These are the right rows, in the wrong order. Look at your ORDER BY.\ntitle\n---------------------\nRivers Under Glass\nThe Long Division\nNight Trains to Avery")
  assert.deepEqual(inOrder.checks[0], { ok: true }) // a pass says nothing more

  const wide = bench.run({ code: "SELECT * FROM books WHERE genre = 'mystery';", checks })
  assert.deepEqual(wide.checks.map(c => c.ok), [false, false, false])
  assert.equal(wide.checks[2].actual, "Your columns are id, title, author, year, genre, copies.")
  assert.match(wide.checks[0].actual, /^Your rows have 6 columns\. This needs a different number of columns\.\nid \| title/)
  const none = bench.run({ code: "SELECT title FROM books WHERE genre = 'Mystery';", checks })
  assert.equal(none.checks[1].ok, false)
  assert.equal(none.checks[1].actual, "Your result has no rows. This needs a different number of rows.")
  // A row that appears twice is not the same as a row that appears once.
  const twice = bench.run({ code: "SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 2;", checks: [{ type: "rows_any_order", call: "", expected: "[[1], [2], [2]]" }, { type: "rows_any_order", call: "", expected: "[[2], [1], [1]]" }] })
  assert.deepEqual(twice.checks.map(c => c.ok), [false, true])
})

test("a missed row check says what is off in plain words and never shows the expected rows", () => {
  const expected = '[["Salt and Signal", 2022], ["A Field Guide to Quiet", 2021], ["How Maps Lie", 2020], ["The Copper Lantern", 2019]]'
  const miss = (sql, type = "rows_are") => bench.run({ code: sql, checks: [{ type, call: "", expected }] }).checks[0]
  const order = miss("SELECT title, year FROM books WHERE year > 2015 ORDER BY year;")
  assert.equal(order.actual.split("\n")[0], "These are the right rows, in the wrong order. Look at your ORDER BY.")
  assert.deepEqual(order.actual.split("\n").slice(1), [
    "title                  | year",
    "-----------------------+-----",
    "The Copper Lantern     | 2019",
    "How Maps Lie           | 2020",
    "A Field Guide to Quiet | 2021",
    "… and 1 more"]) // the student's own first rows, as the console prints them
  assert.equal(miss("SELECT title, year FROM books WHERE year > 2015 ORDER BY year;", "rows_any_order").ok, true)

  assert.equal(miss("SELECT title, year FROM books;").actual.split("\n")[0], "Your result has 9 rows. This needs a different number of rows.")
  assert.equal(miss("SELECT title, year FROM books WHERE year > 2030;").actual, "Your result has no rows. This needs a different number of rows.")
  assert.equal(miss("SELECT title, year FROM books WHERE year < 2016;").actual.split("\n")[0], "That's the right number of rows, but some of them aren't the ones asked for.")
  assert.equal(miss("SELECT title, year FROM books WHERE year < 2016;", "rows_any_order").actual.split("\n")[0], "That's the right number of rows, but some of them aren't the ones asked for.")
  assert.equal(miss("SELECT title FROM books WHERE year > 2015 ORDER BY year DESC;").actual.split("\n")[0], "Your rows have 1 column. This needs a different number of columns.")
  assert.equal(miss("SELECT year, title FROM books WHERE year > 2015 ORDER BY year DESC;").actual.split("\n")[0], "That's the right number of rows, but some of them aren't the ones asked for.")

  // Whatever the miss, nothing from the expected rows that the student didn't produce is shown, and no numbers of rows are given away.
  for (const sql of ["SELECT title, year FROM books WHERE year < 2000;", "SELECT 1;", "SELECT title, year FROM books WHERE year > 2030;"]) {
    const { actual, ok, plain } = miss(sql)
    assert.equal(ok, false)
    assert.equal(plain, true)
    assert.doesNotMatch(actual, /Salt and Signal|Copper Lantern|\b4\b|\[|"/, sql)
  }
})

test("values compare the way a student would expect", () => {
  const check = (sql, expected) => bench.run({ code: sql, checks: [{ type: "rows_are", call: "", expected }] }).checks[0].ok
  assert.equal(check("SELECT 0.1 + 0.2;", "[[0.3]]"), true)        // decimals by value
  assert.equal(check("SELECT 3;", "[[3.0]]"), true)
  assert.equal(check("SELECT '3';", "[[3]]"), false)                // text is not a number
  assert.equal(check("SELECT NULL;", "[[null]]"), true)
  assert.equal(check("SELECT NULL;", '[[""]]'), false)
  assert.equal(check("SELECT 'ada';", '[["Ada"]]'), false)          // capitals count in data
  assert.equal(check("SELECT 1, 2;", "[[1]]"), false)               // an extra column is not the same answer
  assert.equal(check("SELECT 7;", "[7]"), true)                     // a lesson may write one-column rows without the inner brackets
  assert.equal(check("CREATE TABLE t (x);", "[]"), false)           // nothing was selected
  assert.equal(bench.run({ code: "CREATE TABLE t (x);", checks: [{ type: "rows_are", call: "", expected: "[]" }] }).checks[0].actual, "No result yet. Run a SELECT.")
})

test("a check can look at the database after the student's statements", () => {
  const checks = [{ type: "rows_are", call: "SELECT town FROM members WHERE name = 'Finn Abara'", expected: '[["Avery"]]' }, { type: "rows_are", call: "SELECT count(*) FROM members WHERE town = 'Avery'", expected: "[[2]]" }]
  assert.deepEqual(bench.run({ code: "UPDATE members SET town = 'Avery' WHERE name = 'Finn Abara';", checks }).checks.map(c => c.ok), [true, true])
  const all = bench.run({ code: "UPDATE members SET town = 'Avery';", checks })
  assert.deepEqual(all.checks.map(c => c.ok), [true, false])
  assert.equal(all.checks[1].actual, "When this check looked, it found 1 row:\ncount(*)\n--------\n6")
  const broken = bench.run({ code: "DROP TABLE loans; DROP TABLE members;", checks })
  assert.equal(broken.checks[0].ok, false)
  assert.equal(broken.checks[0].actual, "The check couldn't look: no such table: members.")
  assert.equal(bench.run({ code: "SELECT 1;", checks: [{ type: "rows_are", call: "", expected: "not json" }] }).checks[0].ok, false)
})

test("the console keeps changes between statements and waits for the semicolon", () => {
  reset()
  assert.deepEqual(line("SELECT name"), { stdout: "", value: null, incomplete: true, error: null })
  assert.deepEqual(line("SELECT name\nFROM members WHERE id = 1;"), { stdout: "name\n-----------\nAda Fenwick\n(1 row)\n", value: null, incomplete: false, error: null })
  assert.equal(line("UPDATE members SET town = 'Avery' WHERE id = 6;").stdout, "1 row changed.\n")
  assert.equal(line("SELECT town FROM members WHERE id = 6;").stdout, "town\n-----\nAvery\n(1 row)\n")
  assert.equal(line("SELECT * FROM nope;").error.raw, "Error: no such table: nope")
  assert.equal(line("SELECT town FROM members WHERE id = 6;").stdout, "town\n-----\nAvery\n(1 row)\n") // an error loses nothing
  reset()
  assert.equal(line("SELECT town FROM members WHERE id = 6;").stdout, "town\n-------\nOakdale\n(1 row)\n")
})

test("console checks read the last result, and a check's own query doesn't replace it", () => {
  reset()
  assert.deepEqual(values([{ type: "rows_are", call: "", expected: "[[1]]" }]), [{ ok: false, plain: true, actual: "No result yet. Run a SELECT." }])
  line("SELECT title FROM books WHERE id = 3;")
  line("UPDATE books SET copies = 9 WHERE id = 3;") // a change doesn't wipe the last result
  const checks = [{ type: "rows_are", call: "SELECT copies FROM books WHERE id = 3", expected: "[[9]]" }, { type: "rows_are", call: "", expected: '[["A Field Guide to Quiet"]]' }, { type: "columns_are", call: "", expected: "title" }, { type: "value_is", call: "x", expected: "1" }]
  assert.deepEqual(values(checks).map(c => c.ok), [true, true, true, false])
  assert.deepEqual(values(checks).map(c => c.ok), [true, true, true, false]) // asking twice changes nothing
})

test("dot commands list tables and show a table's columns", () => {
  reset()
  assert.equal(line(".tables").stdout, "books\nloans\nmembers\n")
  assert.match(line(".schema members").stdout, /^CREATE TABLE members \(\n  id INTEGER PRIMARY KEY,\n  name TEXT NOT NULL,/)
  assert.match(line(".schema").stdout, /CREATE TABLE books[\s\S]+CREATE TABLE loans[\s\S]+CREATE TABLE members/)
  assert.match(line(".schema nope").error.friendly, /no table named nope/)
  assert.match(line(".help").stdout, /\.tables, \.schema and \.help/)
  assert.match(line(".mode box").error.friendly, /knows \.tables, \.schema and \.help/)
  assert.equal(line(".tables").incomplete, false) // no semicolon needed
  line("CREATE TABLE shelves (id INTEGER PRIMARY KEY, label TEXT);")
  assert.equal(line(".tables").stdout, "books\nloans\nmembers\nshelves\n")
  assert.equal(line(".schema shelves'; DROP TABLE books; --").error.friendly.includes("no table named"), true) // a name is only ever a name
  assert.equal(line("SELECT count(*) FROM books;").stdout.includes("9"), true)
})

test("complete() knows where a statement ends", () => {
  const done = ["SELECT 1;", "SELECT 1; -- trailing note", "select ';' ;", "SELECT 'it''s';", "SELECT 1; /* note; */", "  \n", "-- only a comment", ".tables", "SELECT \"a;b\" FROM t;",
    "CREATE TRIGGER t AFTER INSERT ON loans BEGIN UPDATE books SET copies = copies - 1; END;"]
  const waiting = ["SELECT 1", "SELECT ';'", "SELECT 'unfinished;", "SELECT 1 -- note;", "SELECT 1 /* note;", "SELECT 1; SELECT 2",
    "CREATE TRIGGER t AFTER INSERT ON loans BEGIN UPDATE books SET copies = copies - 1;"]
  done.forEach(sql => assert.equal(complete(sql), true, sql))
  waiting.forEach(sql => assert.equal(complete(sql), false, sql))
})

test("the practice library is the one the lessons describe, with nobody real in it", () => {
  const count = name => bench.run({ code: `SELECT count(*) FROM ${name};`, checks: [] }).stdout.split("\n")[2]
  assert.deepEqual(["books", "members", "loans"].map(count), ["9", "6", "12"])
  const open = bench.run({ code: "SELECT count(*) FROM loans WHERE returned_on IS NULL;" }).stdout.split("\n")[2]
  assert.equal(open, "5")
  const keys = bench.run({ code: "PRAGMA foreign_keys;" }).stdout
  assert.match(keys, /\n1\n/) // links between tables are enforced
})

// The classroom's runner on top of the real bench. A new worker starts with a
// fresh library, which is what stopping and restarting the real worker gives.
// The runaway query never answers (in the browser the worker would be busy).
const RUNAWAY = "WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c) SELECT count(*) FROM c;"
class SqlWorker {
  constructor() { this.bench = new SqlBench(SQL) }
  postMessage(message) {
    if ((message.line || message.code) === RUNAWAY) return
    const result = message.console ? this.bench.console({ op: message.op, line: message.line || "", checks: message.checks || [] }) : this.bench.run({ code: message.code || "", checks: message.checks || [] })
    queueMicrotask(() => this.onmessage({ data: { id: message.id, ok: true, result } }))
  }
  terminate() {}
}
const WORDS = { runaway: "Look for a query that never ends.", kept: "your earlier statements were run again, so your changes are back", lost: "the practice database is back to how it started" }

test("a statement typed over several lines runs once, and a stopped query keeps the student's changes", async () => {
  const status = []
  const runner = new CodeRunner({ name: "SQL", workerUrl: "x", runtimeUrl: "y", megabytes: 1, timeoutMs: 40, WorkerClass: SqlWorker, words: WORDS, onStatus: text => status.push(text) })
  await runner.warm()
  assert.equal(status[0], "Loading SQL (first time only, about 1 MB)…")

  assert.equal((await runner.type("UPDATE members")).incomplete, true)
  assert.equal(runner.partial, "UPDATE members\n")
  assert.equal((await runner.type("SET town = 'Avery'")).incomplete, true)
  const done = await runner.type("WHERE id = 6;")
  assert.equal(done.stdout, "1 row changed.\n")
  assert.equal(done.source, "UPDATE members\nSET town = 'Avery'\nWHERE id = 6;")
  assert.equal(runner.partial, "")
  await runner.type("SELECT * FROM nope;")                                    // an error is not replayed later
  await runner.type("INSERT INTO members (name, joined_on) VALUES ('Gus Hale', '2026-11-12');")
  assert.deepEqual(runner.history, ["UPDATE members\nSET town = 'Avery'\nWHERE id = 6;", "INSERT INTO members (name, joined_on) VALUES ('Gus Hale', '2026-11-12');"])

  const stopped = await runner.type(RUNAWAY)
  assert.equal(stopped.stopped, true)
  assert.equal(stopped.error.friendly, "That ran for more than 0 seconds, so it was stopped. Look for a query that never ends. SQL was restarted and your earlier statements were run again, so your changes are back.")
  await runner.restoring
  assert.equal((await runner.type("SELECT town FROM members WHERE id = 6;")).stdout, "town\n-----\nAvery\n(1 row)\n")
  assert.equal((await runner.type("SELECT count(*) AS n FROM members;")).stdout, "n\n-\n7\n(1 row)\n") // the insert ran once, not twice
  assert.deepEqual(await runner.values([{ type: "rows_are", call: "", expected: "[[7]]" }]), [{ ok: true }])

  // Ctrl+C gives up on a half-typed statement.
  await runner.type("DELETE FROM members")
  runner.cancel()
  assert.equal((await runner.type("SELECT count(*) AS n FROM members;")).stdout, "n\n-\n7\n(1 row)\n")

  // A runaway query in the editor is stopped too, and the console's changes come back.
  const program = await runner.run(RUNAWAY)
  assert.match(program.error.friendly, /so it was stopped/)
  await runner.restoring
  assert.equal((await runner.type("SELECT count(*) AS n FROM members;")).stdout, "n\n-\n7\n(1 row)\n")

  await runner.resetConsole()
  assert.equal((await runner.type("SELECT count(*) AS n FROM members;")).stdout, "n\n-\n6\n(1 row)\n")
  const fresh = new CodeRunner({ name: "SQL", workerUrl: "x", runtimeUrl: "y", timeoutMs: 40, WorkerClass: SqlWorker, words: WORDS })
  await fresh.warm()
  assert.match((await fresh.type(RUNAWAY)).error.friendly, /SQL was restarted, so the practice database is back to how it started\.$/)
  runner.dispose(); fresh.dispose()
})
