// The practice Terminal: a pretend computer that lives in the browser.
// It has folders and files, the everyday commands, practice git, and it can
// run Ruby through the lab's Ruby worker. Nothing here touches a real machine.
const DIR = "dir"
const REAL_ONLY = ["brew", "mise", "code", "open", "sudo", "curl", "bundle", "gem", "rails", "irb", "nano", "vim", "ssh", "npm", "node", "python", "python3", "man"]

export class TerminalSim {
  constructor({ user = "student", runRuby = null } = {}) {
    this.user = user
    this.home = `/Users/${user}`
    this.runRuby = runRuby
    this.root = dir({ Users: dir({ [user]: dir({ Desktop: dir(), Documents: dir(), Downloads: dir() }) }) })
    this.cwd = this.home
    this.history = []
    this.repos = {}   // path => { staged: [], commits: [{ id, message, files }] }
  }

  // State that survives a page reload.
  serialize() { return JSON.stringify({ root: this.root, cwd: this.cwd, history: this.history.slice(-100), repos: this.repos }) }

  restore(json) {
    try {
      const state = JSON.parse(json)
      if (!state?.root || !state.cwd) return false
      Object.assign(this, { root: state.root, cwd: state.cwd, history: state.history || [], repos: state.repos || {} })
      if (!this.isDir(this.cwd)) this.cwd = this.home
      return true
    } catch (_) { return false }
  }

  get prompt() { return `${this.user}@ironwood ${this.cwd === this.home ? "~" : this.cwd.split("/").pop() || "/"} %` }

  // Paths ---------------------------------------------------------------------

  resolve(path) {
    let p = String(path || "")
    if (p === "~" || p.startsWith("~/")) p = this.home + p.slice(1)
    else if (!p.startsWith("/")) p = `${this.cwd}/${p}`
    const out = []
    p.split("/").forEach(part => {
      if (!part || part === ".") return
      if (part === "..") out.pop(); else out.push(part)
    })
    return "/" + out.join("/")
  }

  display(path) { return path === this.home ? "~" : path.startsWith(this.home + "/") ? "~" + path.slice(this.home.length) : path }

  node(path) {
    let at = this.root
    for (const part of this.resolve(path).split("/").filter(Boolean)) {
      if (!at || at.type !== DIR || !Object.hasOwn(at.children, part)) return null
      at = at.children[part]
    }
    return at
  }

  parent(path) {
    const full = this.resolve(path)
    const name = full.split("/").pop()
    return { dir: this.node(full.slice(0, full.lastIndexOf("/")) || "/"), name, full }
  }

  isDir(path) { return this.node(path)?.type === DIR }
  isFile(path) { const n = this.node(path); return !!n && n.type !== DIR }
  read(path) { const n = this.node(path); return n && n.type !== DIR ? n.content : null }

  write(path, content, append = false) {
    const { dir: folder, name } = this.parent(path)
    if (!folder || folder.type !== DIR) return `no such file or directory: ${path}`
    const existing = folder.children[name]
    if (existing?.type === DIR) return `is a directory: ${path}`
    folder.children[name] = { type: "file", content: append && existing ? existing.content + content : content }
    return null
  }

  // Running a line --------------------------------------------------------------

  async exec(line) {
    const text = String(line).trim()
    if (!text) return { output: "" }
    this.history.push(text)
    let tokens
    try { tokens = tokenize(text) } catch (e) { return { output: `zsh: ${e.message}` } }

    // Output redirection: echo "text" > file, or >> to add to the end.
    let target = null, append = false
    const at = tokens.findIndex(t => t.op)
    if (at >= 0) {
      target = tokens[at + 1]?.text
      append = tokens[at].op === ">>"
      if (!target) return { output: "zsh: parse error near `\\n'" }
      tokens = tokens.slice(0, at)
    }
    const [name, ...args] = tokens.map(t => t.text)
    if (!name) return { output: "" }

    const command = this.commands[name]
    let result
    if (command) result = await command.call(this, args, text)
    else if (REAL_ONLY.includes(name)) result = `${name} is a real tool, so it isn't in the practice terminal. Run it in the Terminal app on your Mac.`
    else result = `zsh: command not found: ${name}`
    if (result && typeof result === "object") return result

    let output = result || ""
    if (target !== null) {
      const error = this.write(target, output ? output + "\n" : "", append)
      output = error ? `zsh: ${error}` : ""
    }
    return { output }
  }

  get commands() { return COMMANDS }

  // Practice git ----------------------------------------------------------------

  repoPath() {
    let at = this.cwd
    while (at) {
      if (this.repos[at]) return at
      at = at.slice(0, at.lastIndexOf("/"))
    }
    return null
  }

  filesUnder(path, base = path, out = {}) {
    const n = this.node(path)
    Object.entries(n?.children || {}).forEach(([name, child]) => {
      const full = `${path}/${name}`
      if (child.type === DIR) this.filesUnder(full, base, out); else out[full.slice(base.length + 1)] = child.content
    })
    return out
  }

  git(args) {
    const sub = args[0]
    if (!sub) return "usage: git <command>\n\nPractice commands: init, status, add, commit, log"
    if (sub === "init") {
      if (this.repos[this.cwd]) return `Reinitialized existing Git repository in ${this.cwd}/.git/`
      this.repos[this.cwd] = { staged: [], commits: [] }
      return `Initialized empty Git repository in ${this.cwd}/.git/`
    }
    const root = this.repoPath()
    if (!root) return "fatal: not a git repository (or any of the parent directories): .git"
    const repo = this.repos[root]
    const files = this.filesUnder(root)
    const last = repo.commits.at(-1)?.files || {}
    const changed = Object.keys(files).filter(f => files[f] !== last[f]).sort()
    const staged = repo.staged.filter(f => changed.includes(f))
    const unstaged = changed.filter(f => !staged.includes(f))

    if (sub === "status") {
      const lines = ["On branch main"]
      if (!repo.commits.length) lines.push("", "No commits yet")
      if (staged.length) lines.push("", "Changes to be committed:", ...staged.map(f => `\t${f in last ? "modified:   " : "new file:   "}${f}`))
      const modified = unstaged.filter(f => f in last), fresh = unstaged.filter(f => !(f in last))
      if (modified.length) lines.push("", "Changes not staged for commit:", ...modified.map(f => `\tmodified:   ${f}`))
      if (fresh.length) lines.push("", "Untracked files:", ...fresh.map(f => `\t${f}`))
      if (!changed.length) lines.push(repo.commits.length ? "nothing to commit, working tree clean" : "nothing to commit (create/copy files and use \"git add\" to track)")
      return lines.join("\n")
    }
    if (sub === "add") {
      const what = args.slice(1)
      if (!what.length) return "Nothing specified, nothing added."
      for (const item of what) {
        if (item === "." || item === "-A" || item === "--all") { repo.staged = changed.slice(); continue }
        const rel = this.resolve(item).slice(root.length + 1)
        const hits = changed.filter(f => f === rel || f.startsWith(rel + "/"))
        if (!hits.length && !(rel in files)) return `fatal: pathspec '${item}' did not match any files`
        repo.staged = [...new Set([...repo.staged, ...hits])]
      }
      return ""
    }
    if (sub === "commit") {
      const flag = args.indexOf("-m")
      if (flag < 0 || !args[flag + 1]) return "Practice git needs a message: git commit -m \"what changed\""
      if (!staged.length) return changed.length ? "no changes added to commit (use \"git add\")" : "nothing to commit, working tree clean"
      const snapshot = { ...last }
      staged.forEach(f => { snapshot[f] = files[f] })
      const id = hash(JSON.stringify(snapshot) + args[flag + 1] + repo.commits.length)
      repo.commits.push({ id, message: args[flag + 1], files: snapshot })
      repo.staged = []
      return `[main ${repo.commits.length === 1 ? "(root-commit) " : ""}${id}] ${args[flag + 1]}\n ${staged.length} file${staged.length === 1 ? "" : "s"} changed`
    }
    if (sub === "log") {
      if (!repo.commits.length) return "fatal: your current branch 'main' does not have any commits yet"
      const oneline = args.includes("--oneline")
      return repo.commits.slice().reverse().map(c => oneline ? `${c.id} ${c.message}` : `commit ${c.id}\nAuthor: ${this.user}\n\n    ${c.message}`).join(oneline ? "\n" : "\n\n")
    }
    return `Practice git knows init, status, add, commit and log. '${sub}' comes later, on your real Terminal.`
  }
}

const dir = (children = {}) => ({ type: DIR, children })

function hash(text) {
  let h = 5381
  for (let i = 0; i < text.length; i++) h = ((h << 5) + h + text.charCodeAt(i)) >>> 0
  return h.toString(16).padStart(7, "0").slice(0, 7)
}

// Splits a line into words the way a shell does: quotes keep spaces together,
// and > or >> outside quotes send output to a file.
export function tokenize(line) {
  const tokens = []
  let current = null, quote = null
  const push = () => { if (current !== null) { tokens.push({ text: current }); current = null } }
  for (let i = 0; i < line.length; i++) {
    const ch = line[i]
    if (quote) {
      if (ch === quote) quote = null
      else if (ch === "\\" && quote === '"' && '"\\$'.includes(line[i + 1])) current += line[++i]
      else current += ch
    } else if (ch === '"' || ch === "'") { quote = ch; current ??= "" }
    else if (ch === "\\" && i + 1 < line.length) current = (current ?? "") + line[++i]
    else if (/\s/.test(ch)) push()
    else if (ch === ">") { push(); if (line[i + 1] === ">") { tokens.push({ op: ">>" }); i++ } else tokens.push({ op: ">" }) }
    else current = (current ?? "") + ch
  }
  if (quote) throw new Error(`unmatched ${quote}`)
  push()
  return tokens
}

const flagsOf = args => args.filter(a => /^-[a-zA-Z]+$/.test(a)).join("").replaceAll("-", "")
const plain = args => args.filter(a => !/^-[a-zA-Z]+$/.test(a))

const COMMANDS = {
  pwd() { return this.cwd },
  whoami() { return this.user },
  date() { return new Date().toString().replace(/ GMT.*/, "") },
  clear() { return { output: "", clear: true } },
  history() { return this.history.map((h, i) => `${String(i + 1).padStart(5)}  ${h}`).join("\n") },
  help() { return "Practice commands: pwd ls cd mkdir touch cat echo cp mv rm rmdir clear whoami date history ruby git\nSend output to a file with > (replace) or >> (add to the end)." },
  echo(args) { return args.join(" ") },

  ls(args) {
    const flags = flagsOf(args)
    const targets = plain(args)
    const path = targets[0] || "."
    const node = this.node(path)
    if (!node) return `ls: ${path}: No such file or directory`
    if (node.type !== DIR) return path
    let names = Object.keys(node.children).sort((a, b) => a.localeCompare(b))
    if (flags.includes("a")) names = [".", "..", ...names]
    else names = names.filter(n => !n.startsWith("."))
    if (flags.includes("l")) {
      return names.map(n => {
        const child = node.children[n]
        const isDir = !child || child.type === DIR
        return `${isDir ? "drwxr-xr-x" : "-rw-r--r--"}  ${this.user}  ${String(isDir ? 64 : child.content.length).padStart(5)}  ${n}`
      }).join("\n")
    }
    return names.map(n => node.children[n]?.type === DIR && flags.includes("F") ? n + "/" : n).join("  ")
  },

  cd(args) {
    const path = args[0] || "~"
    const node = this.node(path)
    if (!node) return `cd: no such file or directory: ${path}`
    if (node.type !== DIR) return `cd: not a directory: ${path}`
    this.cwd = this.resolve(path)
    return ""
  },

  mkdir(args) {
    const parents = flagsOf(args).includes("p")
    const out = []
    for (const path of plain(args)) {
      if (parents) {
        let at = ""
        for (const part of this.resolve(path).split("/").filter(Boolean)) {
          at += "/" + part
          const { dir: folder, name } = this.parent(at)
          if (!folder.children[name]) folder.children[name] = dir()
        }
        continue
      }
      const { dir: folder, name } = this.parent(path)
      if (!folder || folder.type !== DIR) out.push(`mkdir: ${path}: No such file or directory`)
      else if (folder.children[name]) out.push(`mkdir: ${path}: File exists`)
      else folder.children[name] = dir()
    }
    if (!plain(args).length) return "usage: mkdir folder_name"
    return out.join("\n")
  },

  touch(args) {
    if (!args.length) return "usage: touch file_name"
    const out = []
    for (const path of plain(args)) {
      if (this.node(path)) continue
      const error = this.write(path, "")
      if (error) out.push(`touch: ${path}: No such file or directory`)
    }
    return out.join("\n")
  },

  cat(args) {
    if (!args.length) return "usage: cat file_name"
    return args.map(path => {
      const node = this.node(path)
      if (!node) return `cat: ${path}: No such file or directory`
      if (node.type === DIR) return `cat: ${path}: Is a directory`
      return node.content.replace(/\n$/, "")
    }).join("\n")
  },

  rmdir(args) {
    return plain(args).map(path => {
      const node = this.node(path)
      if (!node) return `rmdir: ${path}: No such file or directory`
      if (node.type !== DIR) return `rmdir: ${path}: Not a directory`
      if (Object.keys(node.children).length) return `rmdir: ${path}: Directory not empty`
      return this.remove(path)
    }).filter(Boolean).join("\n")
  },

  rm(args) {
    const recursive = /[rR]/.test(flagsOf(args))
    if (!plain(args).length) return "usage: rm file_name"
    return plain(args).map(path => {
      const node = this.node(path)
      if (!node) return `rm: ${path}: No such file or directory`
      if (node.type === DIR && !recursive) return `rm: ${path}: is a directory`
      return this.remove(path)
    }).filter(Boolean).join("\n")
  },

  cp(args) { return transfer.call(this, "cp", args, false) },
  mv(args) { return transfer.call(this, "mv", args, true) },

  async ruby(args) {
    if (args[0] === "-v" || args[0] === "--version") return "ruby 3.4 (practice terminal: Ruby running in your browser)"
    let code
    if (args[0] === "-e") {
      if (args[1] === undefined) return "ruby: no code specified for -e"
      code = args[1]
    } else if (args[0]) {
      const node = this.node(args[0])
      if (!node || node.type === DIR) return `ruby: No such file or directory -- ${args[0]} (LoadError)`
      code = node.content
    } else return "The practice terminal runs Ruby from a file (ruby hello.rb) or from the line (ruby -e '...'). For a console, switch the tool to Ruby console."
    if (!this.runRuby) return "Ruby isn't loaded yet."
    const result = await this.runRuby(code)
    const lines = [(result.stdout || "").replace(/\n$/, "")]
    if (result.error) lines.push(result.error.friendly, result.error.raw)
    return lines.filter(Boolean).join("\n")
  },

  git(args) { return this.git(args) }
}

TerminalSim.prototype.remove = function (path) {
  const { dir: folder, name, full } = this.parent(path)
  if (full === this.home || this.cwd === full || this.cwd.startsWith(full + "/")) return `rm: ${path}: you are standing in it. cd somewhere else first.`
  delete folder.children[name]
  return ""
}

function transfer(name, args, move) {
  const recursive = /[rR]/.test(flagsOf(args))
  const [from, to] = plain(args)
  if (!from || !to) return `usage: ${name} source target`
  const source = this.node(from)
  if (!source) return `${name}: ${from}: No such file or directory`
  if (source.type === DIR && !move && !recursive) return `cp: ${from} is a directory (not copied). Use cp -r for folders.`
  let target = this.resolve(to)
  if (this.isDir(target)) target += "/" + this.resolve(from).split("/").pop()
  if (target === this.resolve(from)) return `${name}: ${from} and ${to} are identical`
  if ((target + "/").startsWith(this.resolve(from) + "/")) return `${name}: can't put ${from} inside itself`
  const { dir: folder, name: leaf } = this.parent(target)
  if (!folder || folder.type !== DIR) return `${name}: ${to}: No such file or directory`
  folder.children[leaf] = JSON.parse(JSON.stringify(source))
  if (move) {
    const origin = this.parent(from)
    delete origin.dir.children[origin.name]
    if (this.cwd === origin.full || this.cwd.startsWith(origin.full + "/")) this.cwd = target + this.cwd.slice(origin.full.length)
  }
  return ""
}
