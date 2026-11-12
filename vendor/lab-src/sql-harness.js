// The classroom's SQL bench: a real SQLite database (sql.js) with a small
// made-up library in it. The editor runs a whole script on a fresh copy; the
// console keeps one database alive so changes last between statements.
// It answers in the same shapes as the Ruby and Python harnesses.

// Every fresh database starts with this. All names and titles are invented.
export const SAMPLE = `
CREATE TABLE books (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  year INTEGER,
  genre TEXT,
  copies INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE members (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  town TEXT,
  joined_on TEXT NOT NULL
);
CREATE TABLE loans (
  id INTEGER PRIMARY KEY,
  book_id INTEGER NOT NULL REFERENCES books(id),
  member_id INTEGER NOT NULL REFERENCES members(id),
  loaned_on TEXT NOT NULL,
  returned_on TEXT
);
INSERT INTO books (id, title, author, year, genre, copies) VALUES
  (1, 'The Copper Lantern', 'Mara Ellison', 2019, 'fantasy', 3),
  (2, 'Rivers Under Glass', 'Tobias Renn', 2004, 'mystery', 2),
  (3, 'A Field Guide to Quiet', 'Ines Calloway', 2021, 'essays', 1),
  (4, 'Salt and Signal', 'Mara Ellison', 2022, 'fantasy', 4),
  (5, 'The Long Division', 'Peter Okoro', 1998, 'mystery', 1),
  (6, 'Small Engines', 'Hana Whitlock', 2015, 'science', 2),
  (7, 'Night Trains to Avery', 'Tobias Renn', 2011, 'mystery', 2),
  (8, 'How Maps Lie', 'Hana Whitlock', 2020, 'science', 1),
  (9, 'An Untitled Almanac', 'Ines Calloway', NULL, NULL, 1);
INSERT INTO members (id, name, town, joined_on) VALUES
  (1, 'Ada Fenwick', 'Maple Falls', '2024-01-15'),
  (2, 'Bo Larkin', 'Oakdale', '2024-03-02'),
  (3, 'Cleo Marsh', 'Maple Falls', '2024-06-20'),
  (4, 'Dev Anand', 'Avery', '2025-02-11'),
  (5, 'Edie Stone', NULL, '2025-09-30'),
  (6, 'Finn Abara', 'Oakdale', '2026-01-08');
INSERT INTO loans (id, book_id, member_id, loaned_on, returned_on) VALUES
  (1, 1, 1, '2026-09-01', '2026-09-15'),
  (2, 2, 1, '2026-09-20', '2026-10-01'),
  (3, 4, 2, '2026-09-22', '2026-10-10'),
  (4, 1, 3, '2026-10-02', '2026-10-20'),
  (5, 6, 3, '2026-10-05', NULL),
  (6, 7, 4, '2026-10-11', '2026-10-25'),
  (7, 4, 1, '2026-10-18', NULL),
  (8, 5, 2, '2026-10-21', '2026-11-02'),
  (9, 1, 4, '2026-10-28', NULL),
  (10, 8, 3, '2026-11-01', NULL),
  (11, 2, 6, '2026-11-03', '2026-11-09'),
  (12, 4, 6, '2026-11-05', NULL);
`

const SHOWN = 100       // rows printed per result
const KEPT = 2000       // rows kept per result for the checks
const SQL_CHECKS = ["rows_are", "rows_any_order", "columns_are"]
const HELP = "This practice console knows .tables, .schema and .help. Everything else is SQL, and a statement ends with a semicolon."

// Is this entry finished? SQL ends at a semicolon that isn't inside a quoted
// string or a comment. Lines starting with a dot are console commands.
export function complete(text) {
  const source = String(text ?? "")
  if (/^\s*\./.test(source)) return true
  let last = ""
  for (let i = 0; i < source.length; i++) {
    const ch = source[i], two = source.slice(i, i + 2)
    if (two === "--") { const end = source.indexOf("\n", i); if (end < 0) break; i = end; continue }
    if (two === "/*") { const end = source.indexOf("*/", i + 2); if (end < 0) return false; i = end + 1; continue }
    if (ch === "'" || ch === '"' || ch === "`") {
      let at = i + 1
      for (;;) {
        const end = source.indexOf(ch, at)
        if (end < 0) return false
        if (source[end + 1] === ch) { at = end + 2; continue } // a doubled quote is a quote inside the string
        i = end
        break
      }
      last = ch
      continue
    }
    if (!/\s/.test(ch)) last = ch
  }
  if (last === "") return true // nothing but spaces and comments
  if (last !== ";") return false
  // A trigger's body holds semicolons of its own; it ends at END;
  if (/^\s*create\s+(temp\w*\s+)?trigger\b/i.test(source)) return /\bend\s*;\s*$/i.test(source.replace(/--[^\n]*$/gm, ""))
  return true
}

const cell = value => value === null ? "NULL" : value instanceof Uint8Array ? "(binary data)" : String(value)

// A result as text: a header, a rule, the rows, and a count.
export function table(columns, rows, total = rows.length) {
  const shown = rows.slice(0, SHOWN).map(row => row.map(cell))
  const widths = columns.map((name, i) => Math.max(name.length, ...shown.map(row => row[i].length)))
  const line = cells => cells.map((text, i) => text.padEnd(widths[i])).join(" | ").replace(/\s+$/, "")
  const out = [line(columns), widths.map(w => "-".repeat(w)).join("-+-"), ...shown.map(line)]
  if (total > shown.length) out.push(`… and ${total - shown.length} more`)
  out.push(`(${total} ${total === 1 ? "row" : "rows"})`)
  return out.join("\n") + "\n"
}

// What SQLite said, in plainer words. The raw message is always shown as well.
export function friendly(message) {
  const text = String(message || "").replace(/^Error:\s*/, "")
  let m
  if ((m = text.match(/^no such table: (.+)/))) return `There's no table named ${m[1]}. Check the spelling. In the console, .tables lists the tables.`
  if ((m = text.match(/^no such column: (.+)/))) return `There's no column named ${m[1]} in the table you're reading. Check the spelling, or look at the table with .schema in the console. If it's meant to be text, put it in 'single quotes'.`
  if ((m = text.match(/^near "(.+)": syntax error/))) return `SQL got lost at ${m[1]}. Look just before it for a missing comma, a missing keyword or a typo.`
  if (/^incomplete input/.test(text)) return "The statement stops before it's finished. Check for a missing closing bracket or quote."
  if ((m = text.match(/^table "?(.+?)"? already exists/))) return `A table named ${m[1]} is already there. Pick another name, or remove it first with DROP TABLE.`
  if ((m = text.match(/^UNIQUE constraint failed: (.+)/))) return `That value is already used in ${m[1]}, and it has to be different in every row.`
  if ((m = text.match(/^NOT NULL constraint failed: (.+)/))) return `${m[1]} can't be left empty. Give it a value.`
  if (/^FOREIGN KEY constraint failed/.test(text)) return "That row points at a row that doesn't exist in the other table (or you're removing a row something still points at)."
  if ((m = text.match(/^ambiguous column name: (.+)/))) return `More than one table here has a column named ${m[1]}. Say which one, like books.${m[1]}.`
  if ((m = text.match(/^misuse of aggregate(?: function)?:? ?(.*)/))) return `A counting or totalling function${m[1] ? ` (${m[1]})` : ""} is in a place it can't go. To filter on a total, use HAVING after GROUP BY, not WHERE.`
  if ((m = text.match(/^no such function: (.+)/))) return `This database has no function named ${m[1]}. Check the spelling.`
  if ((m = text.match(/^(\d+) values for (\d+) columns/))) return `You gave ${m[1]} values but named ${m[2]} columns. They have to match one for one.`
  if ((m = text.match(/^table (.+) has (\d+) columns but (\d+) values were supplied/))) return `${m[1]} has ${m[2]} columns but you gave ${m[3]} values. Name the columns you're filling, or give a value for each one.`
  if ((m = text.match(/^table (.+) has no column named (.+)/))) return `${m[1]} has no column named ${m[2]}. Check the spelling.`
  return "SQL couldn't run that."
}

const changed = (verb, count) => {
  const rows = `${count} ${count === 1 ? "row" : "rows"}`
  return verb === "INSERT" || verb === "REPLACE" ? `${rows} added.` : verb === "DELETE" ? `${rows} removed.` : `${rows} changed.`
}

// Runs every statement in the text. Returns what was printed, the last result
// (for the checks), and the error that stopped it, if any.
export function execute(db, sql) {
  let stdout = "", last = null, statements = 0, stepping = false
  const iterator = db.iterateStatements(sql)
  try {
    for (const statement of iterator) {
      statements += 1
      stepping = true
      const columns = statement.getColumnNames()
      const verb = (statement.getSQL().replace(/^(\s|--[^\n]*\n|\/\*[\s\S]*?\*\/)*/, "").match(/^\w+/) || [""])[0].toUpperCase()
      if (columns.length) {
        const rows = []
        let total = 0
        while (statement.step()) { total += 1; if (rows.length < KEPT) rows.push(statement.get()) }
        last = { columns, rows, total }
        stdout += table(columns, rows, total)
      } else {
        statement.step()
        if (["INSERT", "UPDATE", "DELETE", "REPLACE"].includes(verb)) stdout += `${changed(verb, db.getRowsModified())}\n`
        else if (!["PRAGMA", "BEGIN", "COMMIT", "END", "ROLLBACK", "SAVEPOINT", "RELEASE"].includes(verb)) stdout += "Done.\n"
      }
      stepping = false
    }
  } catch (e) {
    const raw = String(e && e.message || e).replace(/^Error:\s*/, "")
    const at = stepping ? statements : statements + 1 // failed while running, or while reading the next one
    const where = at > 1 ? ` (statement ${at})` : ""
    return { stdout, last, error: { friendly: friendly(raw), raw: `Error: ${raw}${where}` } }
  }
  return { stdout, last, error: null }
}

const sameCell = (a, b) => typeof a === "number" && typeof b === "number" ? Math.abs(a - b) < 1e-9 : a === b
const sameRow = (a, b) => Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((v, i) => sameCell(v, b[i]))
const sortKey = row => JSON.stringify(row.map(v => typeof v === "number" ? Number(v.toFixed(9)) : v))
const plain = rows => rows.map(row => row.map(v => v instanceof Uint8Array ? "(binary data)" : v))

// The first few rows of a result as the console would print them.
const sample = result => table(result.columns, result.rows.slice(0, 3), result.total).replace(/\n\(\d+ rows?\)\n$/, "")
const count = total => total === 0 ? "no rows" : `${total} ${total === 1 ? "row" : "rows"}`
const found = (text, result) => ({ ok: false, plain: true, actual: result && result.total ? `${text}\n${sample(result)}` : text })

// Says what is off about a result without giving the expected rows away.
function diagnose(result, want, ordered, own) {
  const got = plain(result.rows)
  if (!own) return `When this check looked, it found ${count(result.total)}${result.total ? ":" : "."}`
  if (result.total !== want.length) return `Your result has ${count(result.total)}. This needs a different number of rows.`
  if (want.length && got[0].length !== want[0].length) return `Your rows have ${got[0].length} ${got[0].length === 1 ? "column" : "columns"}. This needs a different number of columns.`
  const a = got.map(sortKey).sort(), b = want.map(sortKey).sort()
  if (ordered && a.every((key, i) => key === b[i])) return "These are the right rows, in the wrong order. Look at your ORDER BY."
  return "That's the right number of rows, but some of them aren't the ones asked for."
}

// Checks only say pass or not yet, and describe what the student's own result holds.
export function judge(db, last, check) {
  if (!SQL_CHECKS.includes(check.type)) return null
  let result = last
  const own = !String(check.call || "").trim() // judging the student's last result, not a query of the lesson's
  if (!own) {
    const ran = execute(db, check.call)
    if (ran.error || !ran.last) return found(ran.error ? `The check couldn't look: ${ran.error.raw.replace(/^Error:\s*/, "")}.` : "There's nothing to look at yet.")
    result = ran.last
  }
  if (!result) return found("No result yet. Run a SELECT.")
  if (check.type === "columns_are") {
    const want = String(check.expected || "").split(",").map(s => s.trim().toLowerCase()).filter(Boolean)
    const got = result.columns.map(c => c.toLowerCase())
    const ok = want.length === got.length && want.every((c, i) => c === got[i])
    return ok ? { ok } : found(`${own ? "Your columns are" : "The columns there are"} ${result.columns.join(", ")}.`)
  }
  let want
  try { want = JSON.parse(check.expected) } catch (_) { want = null }
  if (!Array.isArray(want)) return found("This check was written wrongly. Tell your professor.")
  want = want.map(row => Array.isArray(row) ? row : [row])
  const got = plain(result.rows)
  let ok = result.total === want.length && got.length === want.length
  if (ok && check.type === "rows_any_order") {
    const a = got.map(sortKey).sort(), b = want.map(sortKey).sort()
    ok = a.every((key, i) => key === b[i])
  } else if (ok) {
    ok = got.every((row, i) => sameRow(row, want[i]))
  }
  return ok ? { ok } : found(diagnose(result, want, check.type === "rows_are", own), result)
}

export class SqlBench {
  constructor(SQL) {
    this.SQL = SQL
    this.db = null
    this.last = null
  }

  fresh() {
    const db = new this.SQL.Database()
    db.run("PRAGMA foreign_keys = ON;")
    db.run(SAMPLE)
    return db
  }

  // The editor: the whole script on a fresh database.
  run({ code = "", checks = [] }) {
    const db = this.fresh()
    try {
      const { stdout, last, error } = execute(db, code)
      return { stdout, error, checks: checks.map(check => error ? (SQL_CHECKS.includes(check.type) ? { ok: false, plain: true, actual: "Fix the error first." } : null) : judge(db, last, check)) }
    } finally { db.close() }
  }

  // The console: { op: "eval" | "values" | "reset" }.
  console({ op, line = "", checks = [] }) {
    if (op === "reset") { this.db?.close(); this.db = null; this.last = null; return {} }
    this.db ||= this.fresh()
    if (op === "values") return { checks: checks.map(check => judge(this.db, this.last, check) || { ok: false, plain: true, actual: "This check doesn't work in the SQL console." }) }
    if (!complete(line)) return { stdout: "", value: null, incomplete: true, error: null }
    if (/^\s*\./.test(line)) return { ...this.dot(line.trim()), value: null, incomplete: false }
    const { stdout, last, error } = execute(this.db, line)
    if (last) this.last = last
    return { stdout, value: null, incomplete: false, error }
  }

  dot(command) {
    const [name, arg] = command.split(/\s+/)
    if (name === ".help") return { stdout: `${HELP}\n`, error: null }
    if (name === ".tables") {
      const names = this.db.exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")[0]?.values.map(r => r[0]) || []
      return { stdout: names.length ? `${names.join("\n")}\n` : "(no tables)\n", error: null }
    }
    if (name === ".schema") {
      const statement = this.db.prepare(`SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ${arg ? "AND lower(tbl_name) = lower(:name)" : ""} ORDER BY tbl_name, type DESC`)
      if (arg) statement.bind({ ":name": arg.replace(/;$/, "") })
      const found = []
      while (statement.step()) found.push(`${statement.get()[0]};`)
      statement.free()
      if (!found.length) return { stdout: "", error: { friendly: arg ? `There's no table named ${arg.replace(/;$/, "")}. .tables lists the tables.` : "There are no tables yet.", raw: "" } }
      return { stdout: `${found.join("\n")}\n`, error: null }
    }
    return { stdout: "", error: { friendly: HELP, raw: "" } }
  }
}
