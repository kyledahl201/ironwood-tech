// Decides whether a classroom step's checks pass. Checks only ever say
// pass or not yet; they never hold or reveal a solution.

// Lesson scripts write patterns the Ruby way. This turns one into a JavaScript
// RegExp: ^ and $ match at each line, and a leading (?i) means "ignore case".
export function toRegex(source) {
  let text = String(source ?? "")
  let flags = "m"
  const inline = text.match(/^\(\?([im]+)\)/)
  if (inline) {
    if (inline[1].includes("i")) flags += "i"
    if (inline[1].includes("m")) flags += "s" // Ruby's m lets . match a newline
    text = text.slice(inline[0].length)
  }
  text = text.replace(/\\A/g, "(?<![\\s\\S])").replace(/\\[zZ]/g, "(?![\\s\\S])").replace(/\\h/g, "[0-9a-fA-F]")
  try { return new RegExp(text, flags) } catch (_) { return null }
}

// Trailing spaces and the final newline don't count; everything else does.
export function normalize(text) {
  return String(text ?? "").replace(/\r\n/g, "\n").split("\n").map(l => l.replace(/\s+$/, "")).join("\n").replace(/\n+$/, "")
}

const matches = (pattern, texts) => {
  const re = toRegex(pattern)
  return !!re && texts.some(t => re.test(String(t ?? "")))
}

// context: { commands, outputs, sim, runner, pasted, code, result }
//   commands/outputs: what was typed and printed in a console during this step
//   pasted: text pasted for an "on your Mac" step
//   code/result: the editor's program and the worker's result for it
export async function evaluateChecks(checks, context) {
  const { commands = [], outputs = [], sim, runner, pasted, code, result } = context
  const inEditor = result !== undefined
  const outcomes = checks.map((check, i) => {
    switch (check.type) {
      case "command_matches": return { ok: matches(check.expected, commands) }
      case "output_matches":
        if (pasted !== undefined) return { ok: matches(check.expected, [pasted.replace(/\r\n/g, "\n")]) }
        return { ok: matches(check.expected, inEditor ? [result.stdout] : outputs) }
      case "cwd_is": return { ok: !!sim && sim.cwd === sim.resolve(check.expected), actual: sim && `you are in ${sim.display(sim.cwd)}` }
      case "file_exists": return { ok: !!sim?.isFile(check.expected) }
      case "dir_exists": return { ok: !!sim?.isDir(check.expected) }
      case "file_contains": {
        const text = sim?.read(check.call)
        return { ok: text != null && text.includes(check.expected), actual: text == null ? "that file isn't there yet" : null }
      }
      case "stdout": {
        const want = normalize(check.expected)
        if (inEditor) return { ok: !result.error && normalize(result.stdout) === want, actual: result.error ? null : `printed ${JSON.stringify(normalize(result.stdout))}` }
        return { ok: outputs.some(o => normalize(o) === want) }
      }
      case "source_includes": return { ok: source(code, commands).includes(check.expected) }
      case "source_excludes": return { ok: source(code, commands).trim() !== "" && !source(code, commands).includes(check.expected) }
      case "source_matches": return { ok: matches(check.expected, [source(code, commands)]) }
      default: // value_is, method_returns, method_stdout_empty: Ruby answers these
        if (inEditor) {
          const fromWorker = result.checks?.[i]
          if (fromWorker?.plain || fromWorker?.ok) return { ok: !!fromWorker.ok, actual: fromWorker.ok ? null : fromWorker.actual } // SQL writes its own sentence
          return fromWorker ? { ok: false, actual: `gave ${fromWorker.actual}` } : { ok: false }
        }
        return { pending: true }
    }
  })

  const waiting = outcomes.map((o, i) => o.pending ? i : -1).filter(i => i >= 0)
  if (waiting.length) {
    const answers = runner ? await runner.values(waiting.map(i => checks[i])) : []
    waiting.forEach((at, n) => {
      const answer = answers[n]
      outcomes[at] = answer?.plain ? { ok: !!answer.ok, actual: answer.ok ? null : answer.actual } : answer ? { ok: !!answer.ok, actual: answer.ok ? null : (answer.actual === "not there yet" ? "not set yet" : `now ${answer.actual}`) } : { ok: false }
    })
  }
  return outcomes
}

const source = (code, commands) => code ?? commands.join("\n")
