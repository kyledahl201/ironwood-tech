// Builds the text behind "Copy for my tutor": where the student is, the task,
// their own work and what the checks said, ready to paste into a chat with
// their professor. It only ever holds the student's work, never an answer.
const FENCE = "```"
const clip = (text, max) => {
  const clean = String(text ?? "").replace(/\s+$/, "")
  return clean.length > max ? `${clean.slice(0, max)}\n… (cut here: ${clean.length - max} more characters)` : clean
}

export function buildTutorNote({ about, place, task, tool, language = "", code, transcript, output, checks = [], hints = 0 }) {
  const parts = [`Ironwood Tech classroom: ${about}`, place]
  if (task) parts.push(`The task:\n${clip(task, 1500)}`)
  if (code != null) parts.push(`My code (${tool}):\n${FENCE}${language}\n${clip(code, 6000)}\n${FENCE}`)
  if (output) parts.push(`What it printed:\n${FENCE}\n${clip(output, 2000)}\n${FENCE}`)
  if (transcript) parts.push(`What I typed and what came back (${tool}):\n${FENCE}\n${clip(transcript, 4000)}\n${FENCE}`)
  if (checks.length) {
    parts.push(`The portal's checks:\n${checks.map(c => `- ${c.ok ? "Pass" : "Not yet"}: ${c.label}${!c.ok && c.detail ? ` (${c.detail})` : ""}`).join("\n")}`)
    parts.push(`Hints I've opened on this task: ${hints}`)
  }
  parts.push("My question: ")
  return parts.join("\n\n")
}
