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
    this.repos = {}   // path => { branch, branches: { name: commit id }, commits: { id: { message, files, parents } }, index, merging }
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

  // Tab: finish the last word when exactly one file or folder name fits.
  complete(line) {
    const parts = String(line).split(" ")
    const word = parts.pop()
    const slash = word.lastIndexOf("/")
    const folder = this.node(slash >= 0 ? word.slice(0, slash) || "/" : ".")
    const names = Object.keys(folder?.children || {}).filter(n => n.startsWith(word.slice(slash + 1)))
    if (names.length !== 1) return line
    const tail = folder.children[names[0]].type === DIR ? "/" : ""
    return [...parts, word.slice(0, slash + 1) + names[0] + tail].join(" ")
  }

  // Practice git ----------------------------------------------------------------
  // A small, honest git: an index, commits with parents, branches, merges with
  // real conflicts. No remotes: pushing and pulling need GitHub and a real Terminal.

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

  // The repository at a path, brought up to today's shape if it was saved by an older classroom.
  repo(root) {
    const repo = this.repos[root]
    if (repo && Array.isArray(repo.commits)) {
      const commits = {}
      repo.commits.forEach((c, n) => { commits[c.id] = { ...c, n, parents: n ? [repo.commits[n - 1].id] : [] } })
      const last = repo.commits.at(-1)
      const files = this.filesUnder(root)
      const index = { ...(last?.files || {}) }
      ;(repo.staged || []).forEach(f => { if (f in files) index[f] = files[f] })
      this.repos[root] = { branch: "main", branches: last ? { main: last.id } : {}, commits, index, made: repo.commits.length, merging: null }
    }
    return this.repos[root]
  }

  // Where a repository stands, for the classroom's checks and for git status.
  gitState(root = this.repoPath()) {
    const repo = root && this.repo(root)
    if (!repo) return null
    const head = repo.branches[repo.branch] || null
    const tree = head ? repo.commits[head].files : {}
    const ignored = ignoreRules(this.read(`${root}/.gitignore`))
    const all = this.filesUnder(root)
    const files = Object.fromEntries(Object.entries(all).filter(([f]) => f in repo.index || !ignored(f)))
    const names = new Set([...Object.keys(tree), ...Object.keys(repo.index), ...Object.keys(files)])
    const staged = [], unstaged = [], untracked = []
    ;[...names].sort().forEach(f => {
      if (repo.index[f] !== tree[f]) staged.push([f in repo.index ? (f in tree ? "modified" : "new file") : "deleted", f])
      if (f in repo.index && files[f] !== repo.index[f]) unstaged.push([f in files ? "modified" : "deleted", f])
      if (!(f in repo.index) && f in files) untracked.push(f)
    })
    const history = this.ancestors(repo, head)
    return { root, repo, head, tree, files, staged, unstaged, untracked, history,
             branch: repo.branch, branches: Object.keys(repo.branches).sort(), commits: history.length,
             clean: !staged.length && !unstaged.length && !untracked.length && !repo.merging,
             message: head ? repo.commits[head].message : null,
             merged: name => !!repo.branches[name] && history.some(c => c.id === repo.branches[name]) }
  }

  // A commit and everything before it, newest first.
  ancestors(repo, id) {
    const seen = new Set(), queue = id ? [id] : []
    while (queue.length) {
      const at = queue.pop()
      if (seen.has(at)) continue
      seen.add(at)
      queue.push(...repo.commits[at].parents)
    }
    return [...seen].map(c => repo.commits[c]).sort((a, b) => b.n - a.n)
  }

  // Makes the folder match a commit: tracked files that left are removed, the rest written.
  checkOut(root, from, to) {
    Object.keys(from).filter(f => !(f in to)).forEach(f => { if (this.isFile(`${root}/${f}`)) { const { dir: folder, name } = this.parent(`${root}/${f}`); delete folder.children[name] } })
    Object.entries(to).forEach(([f, content]) => {
      let at = root
      f.split("/").slice(0, -1).forEach(part => { at += `/${part}`; const { dir: folder, name } = this.parent(at); if (!folder.children[name]) folder.children[name] = dir() })
      this.write(`${root}/${f}`, content)
    })
  }

  commit(repo, message, files, parents) {
    const n = repo.made++
    const id = hash(JSON.stringify(files) + message + n)
    repo.commits[id] = { id, n, message, files: { ...files }, parents }
    repo.branches[repo.branch] = id
    repo.index = { ...files }
    return id
  }

  git(args) {
    const sub = args[0]
    if (!sub || sub === "help" || sub === "--help") return `usage: git <command>\n\nPractice commands: ${GIT_KNOWS}`
    if (sub === "--version" || sub === "version") return "git version 2.54.0 (practice terminal)"
    if (sub === "init") {
      if (this.repos[this.cwd]) return `Reinitialized existing Git repository in ${this.cwd}/.git/`
      this.repos[this.cwd] = { branch: "main", branches: {}, commits: {}, index: {}, made: 0, merging: null }
      return `Initialized empty Git repository in ${this.cwd}/.git/`
    }
    if (GIT_NEEDS_GITHUB.includes(sub)) return `git ${sub} talks to another computer (like GitHub), and the practice terminal has none. It comes later, in the Terminal app on your Mac.`
    const state = this.gitState()
    if (!state) return "fatal: not a git repository (or any of the parent directories): .git"
    const command = GIT[sub]
    if (!command && GIT_LATER.includes(sub)) return `git ${sub} is a real git command, but practice git doesn't have it. It comes later, in the Terminal app on your Mac.\n\nPractice git knows: ${GIT_KNOWS}`
    if (!command) return `git: '${sub}' is not a git command. See 'git --help'.\n\nPractice git knows: ${GIT_KNOWS}`
    return command.call(this, args.slice(1), state)
  }
}

const GIT_KNOWS = "init, status, add, commit, log, diff, branch, switch, checkout, merge, restore, rm"
const GIT_NEEDS_GITHUB = ["push", "pull", "clone", "fetch", "remote"]
// Real commands that practice git leaves for the real Terminal.
const GIT_LATER = ["stash", "reset", "rebase", "tag", "mv", "revert", "cherry-pick", "show", "blame", "bisect", "config", "reflog", "clean", "worktree", "submodule"]
// The closing line of git status when nothing is staged.
const nothingAdded = ({ unstaged }) => unstaged.length ? "no changes added to commit (use \"git add\" and/or \"git commit -a\")" : "nothing added to commit but untracked files present (use \"git add\" to track)"
const count = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`

// .gitignore, the everyday parts: a name, a folder/, or *.ending per line.
function ignoreRules(text) {
  const rules = String(text || "").split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("#"))
  return file => rules.some(rule => {
    const parts = file.split("/")
    if (rule.endsWith("/")) return parts.slice(0, -1).includes(rule.slice(0, -1))
    if (rule.startsWith("*")) return parts.at(-1).endsWith(rule.slice(1))
    return parts.includes(rule.replace(/^\//, "")) || file === rule.replace(/^\//, "")
  })
}

// The lines that left and the lines that came, the way git diff shows them.
function lineDiff(before, after) {
  const a = before === undefined ? [] : before.replace(/\n$/, "").split("\n"), b = after === undefined ? [] : after.replace(/\n$/, "").split("\n")
  const table = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0))
  for (let i = a.length - 1; i >= 0; i--) for (let j = b.length - 1; j >= 0; j--) table[i][j] = a[i] === b[j] ? table[i + 1][j + 1] + 1 : Math.max(table[i + 1][j], table[i][j + 1])
  const out = []
  let i = 0, j = 0
  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i] === b[j]) { out.push(` ${a[i]}`); i++; j++ }
    else if (i < a.length && (j >= b.length || table[i + 1][j] >= table[i][j + 1])) out.push(`-${a[i++]}`) // what left comes first, as git shows it
    else out.push(`+${b[j++]}`)
  }
  return out
}

// Groups those lines into hunks with three lines of context, each under an
// @@ -start,count +start,count @@ header: where the hunk sits in the old file and in the new.
function hunks(before, after) {
  const lines = lineDiff(before, after)
  const changed = lines.map((l, n) => l[0] === " " ? -1 : n).filter(n => n >= 0)
  if (!changed.length) return []
  const spans = []
  changed.forEach(n => { const last = spans.at(-1); if (last && n - 3 <= last[1] + 1) last[1] = Math.min(lines.length - 1, n + 3); else spans.push([Math.max(0, n - 3), Math.min(lines.length - 1, n + 3)]) })
  const range = (start, size) => `${size === 0 ? start - 1 : start}${size === 1 ? "" : `,${size}`}`
  return spans.flatMap(([from, to]) => {
    const old = lines.slice(0, from).filter(l => l[0] !== "+").length + 1, fresh = lines.slice(0, from).filter(l => l[0] !== "-").length + 1
    const part = lines.slice(from, to + 1)
    return [`@@ -${range(old, part.filter(l => l[0] !== "+").length)} +${range(fresh, part.filter(l => l[0] !== "-").length)} @@`, ...part]
  })
}

function diffText(pairs) {
  return pairs.map(([file, before, after]) => [
    `diff --git a/${file} b/${file}`,
    before === undefined ? "new file mode 100644" : after === undefined ? "deleted file mode 100644" : null,
    `--- ${before === undefined ? "/dev/null" : `a/${file}`}`, `+++ ${after === undefined ? "/dev/null" : `b/${file}`}`,
    ...hunks(before, after)
  ].filter(l => l !== null).join("\n")).join("\n")
}

const GIT = {
  status(_args, { repo, staged, unstaged, untracked, head }) {
    const lines = [`On branch ${repo.branch}`]
    const conflicts = repo.merging?.conflicts || []
    if (repo.merging) lines.push(conflicts.length ? "You have unmerged paths.\n  (fix conflicts and run \"git commit\")\n  (use \"git merge --abort\" to abort the merge)" : "All conflicts fixed but you are still merging.\n  (use \"git commit\" to conclude merge)")
    if (!head) lines.push("", "No commits yet")
    const settled = staged.filter(([, f]) => !conflicts.includes(f))
    if (settled.length) lines.push("", "Changes to be committed:", head ? "  (use \"git restore --staged <file>...\" to unstage)" : "  (use \"git rm --cached <file>...\" to unstage)", ...settled.map(([kind, f]) => `\t${`${kind}:`.padEnd(12)}${f}`))
    if (conflicts.length) lines.push("", "Unmerged paths:", "  (use \"git add <file>...\" to mark resolution)", ...conflicts.map(f => `\tboth modified:   ${f}`))
    const loose = unstaged.filter(([, f]) => !conflicts.includes(f))
    if (loose.length) lines.push("", "Changes not staged for commit:", `  (use "git add${loose.some(([kind]) => kind === "deleted") ? "/rm" : ""} <file>..." to update what will be committed)`, "  (use \"git restore <file>...\" to discard changes in working directory)", ...loose.map(([kind, f]) => `\t${`${kind}:`.padEnd(12)}${f}`))
    if (untracked.length) lines.push("", "Untracked files:", "  (use \"git add <file>...\" to include in what will be committed)", ...untracked.map(f => `\t${f}`))
    if (!staged.length && !repo.merging) lines.push(...(unstaged.length || untracked.length ? ["", nothingAdded({ unstaged, untracked })] : [head ? "nothing to commit, working tree clean" : "nothing to commit (create/copy files and use \"git add\" to track)"]))
    return lines.join("\n")
  },

  add(args, { root, repo, files, unstaged, untracked }) {
    if (!args.length) return "Nothing specified, nothing added."
    const pending = [...unstaged.map(([, f]) => f), ...untracked]
    for (const item of args) {
      const everything = item === "-A" || item === "--all"
      const rel = everything ? "" : this.resolve(item).slice(root.length + 1)
      const hits = pending.filter(f => rel === "" || f === rel || f.startsWith(`${rel}/`))
      if (!hits.length && rel !== "" && !(rel in files) && !Object.keys(files).some(f => f.startsWith(`${rel}/`))) {
        const all = this.filesUnder(root)
        if (rel in all) return `The following paths are ignored by one of your .gitignore files:\n${rel}`
        return `fatal: pathspec '${item}' did not match any files`
      }
      hits.forEach(f => { if (f in files) repo.index[f] = files[f]; else delete repo.index[f] })
      if (repo.merging) repo.merging.conflicts = repo.merging.conflicts.filter(f => !hits.includes(f) && f !== rel)
    }
    return ""
  },

  rm(args, { root, repo }) {
    const targets = plain(args).filter(a => !a.startsWith("--"))
    if (!targets.length) return "usage: git rm file_name"
    for (const item of targets) {
      const rel = this.resolve(item).slice(root.length + 1)
      if (!(rel in repo.index)) return `fatal: pathspec '${item}' did not match any files`
      delete repo.index[rel]
      if (!args.includes("--cached") && this.isFile(item)) { const { dir: folder, name } = this.parent(item); delete folder.children[name] }
    }
    return targets.map(f => `rm '${f}'`).join("\n")
  },

  commit(args, state) {
    const { repo, head, tree } = state
    if (args.includes("--amend")) return "Practice git doesn't rewrite commits. Make a new commit instead."
    const flag = args.findIndex(a => /^-a?m$/.test(a))
    let message = flag >= 0 ? args[flag + 1] : null
    if (args.some(a => a === "-a" || a === "-am")) state.unstaged.forEach(([kind, f]) => { if (kind === "deleted") delete repo.index[f]; else repo.index[f] = state.files[f] })
    if (repo.merging) {
      if (repo.merging.conflicts.length) return `error: Committing is not possible because you have unmerged files.\nFix them, then use 'git add <file>' to mark each one as fixed.\n${repo.merging.conflicts.map(f => `U\t${f}`).join("\n")}`
      message ||= `Merge branch '${repo.merging.name}'`
      const id = this.commit(repo, message, repo.index, [head, repo.merging.target])
      repo.merging = null
      return `[${repo.branch} ${id}] ${message}`
    }
    if (!message) return "Practice git needs a message: git commit -m \"what changed\""
    const changed = [...new Set([...Object.keys(tree), ...Object.keys(repo.index)])].filter(f => repo.index[f] !== tree[f])
    if (!changed.length) return state.unstaged.length || state.untracked.length ? GIT.status.call(this, [], state) : `On branch ${repo.branch}\nnothing to commit, working tree clean`
    const id = this.commit(repo, message, repo.index, head ? [head] : [])
    return `[${repo.branch} ${head ? "" : "(root-commit) "}${id}] ${message}\n ${count(changed.length, "file")} changed`
  },

  log(args, { repo, head, history }) {
    if (!head) return `fatal: your current branch '${repo.branch}' does not have any commits yet`
    const oneline = args.includes("--oneline")
    const names = id => {
      const here = Object.keys(repo.branches).filter(b => repo.branches[b] === id).sort((a, b) => (b === repo.branch) - (a === repo.branch) || a.localeCompare(b))
      return here.length ? ` (${here.map(b => b === repo.branch ? `HEAD -> ${b}` : b).join(", ")})` : ""
    }
    const limit = Number((args.find(a => /^-\d+$/.test(a)) || "").slice(1)) || history.length
    return history.slice(0, limit).map(c => oneline ? `${c.id}${names(c.id)} ${c.message}`
      : [`commit ${c.id}${names(c.id)}`, c.parents.length > 1 ? `Merge: ${c.parents.join(" ")}` : null, `Author: ${this.user}`, "", `    ${c.message}`].filter(l => l !== null).join("\n")).join(oneline ? "\n" : "\n\n")
  },

  diff(args, { repo, tree, files, staged, unstaged }) {
    if (args.includes("--staged") || args.includes("--cached")) return diffText(staged.map(([, f]) => [f, tree[f], repo.index[f]]))
    return diffText(unstaged.map(([, f]) => [f, repo.index[f], files[f]]))
  },

  branch(args, { repo, head, merged }) {
    const flag = args.find(a => /^-[dD]$|^--delete$/.test(a)), name = plain(args).find(a => !a.startsWith("--"))
    if (flag) {
      if (!name) return "fatal: branch name required"
      if (!repo.branches[name]) return `error: branch '${name}' not found`
      if (name === repo.branch) return `error: cannot delete branch '${name}': you are on it. Switch to another branch first.`
      if (flag !== "-D" && !merged(name)) return `error: the branch '${name}' is not fully merged.\nIf you are sure you want to delete it, run 'git branch -D ${name}'`
      const was = repo.branches[name]
      delete repo.branches[name]
      return `Deleted branch ${name} (was ${was}).`
    }
    if (!name) return [...new Set([...Object.keys(repo.branches), ...(head ? [] : [])])].sort().map(b => `${b === repo.branch ? "*" : " "} ${b}`).join("\n")
    if (!/^[\w./-]+$/.test(name) || name.startsWith("-")) return `fatal: '${name}' is not a valid branch name`
    if (!head) return `fatal: not a valid object name: '${repo.branch}'. Make a first commit, then branch from it.`
    if (repo.branches[name]) return `fatal: a branch named '${name}' already exists`
    repo.branches[name] = head
    return ""
  },

  switch(args, state, verb = "switch") {
    const { root, repo, head, tree, staged, unstaged } = state
    const create = args.find(a => a === "-c" || a === "-b" || a === "--create")
    const name = plain(args).find(a => !a.startsWith("--"))
    if (!name) return `fatal: missing branch name; try git ${verb} ${verb === "switch" ? "-c" : "-b"} new-branch-name`
    if (repo.merging) return "fatal: you are in the middle of a merge. Finish it with git commit, or stop it with git merge --abort."
    if (create) {
      if (!/^[\w./-]+$/.test(name)) return `fatal: '${name}' is not a valid branch name`
      if (repo.branches[name]) return `fatal: a branch named '${name}' already exists`
      if (head) repo.branches[name] = head
      repo.branch = name
      return `Switched to a new branch '${name}'`
    }
    if (name === repo.branch) return `Already on '${name}'`
    if (!repo.branches[name]) return verb === "checkout" && this.isFile(name) ? `Practice git restores a file with: git restore ${name}` : `fatal: invalid reference: ${name}`
    const to = repo.commits[repo.branches[name]].files
    const differs = [...new Set([...Object.keys(tree), ...Object.keys(to)])].filter(f => tree[f] !== to[f])
    const dirty = [...staged, ...unstaged].map(([, f]) => f).filter(f => differs.includes(f))
    if (dirty.length) return `error: Your local changes to the following files would be overwritten by ${verb === "switch" ? "checkout" : verb}:\n${[...new Set(dirty)].map(f => `\t${f}`).join("\n")}\nPlease commit your changes before you switch branches.`
    const carried = Object.fromEntries(Object.keys(repo.index).filter(f => repo.index[f] !== tree[f]).map(f => [f, repo.index[f]]))
    this.checkOut(root, Object.fromEntries(differs.filter(f => f in tree).map(f => [f, tree[f]])), Object.fromEntries(differs.filter(f => f in to).map(f => [f, to[f]])))
    repo.index = { ...to, ...carried }
    repo.branch = name
    return `Switched to branch '${name}'`
  },

  checkout(args, state) { return GIT.switch.call(this, args, state, "checkout") },

  restore(args, { root, repo, tree, files }) {
    const fromIndex = args.includes("--staged")
    const targets = plain(args).filter(a => !a.startsWith("--"))
    if (!targets.length) return "fatal: you must specify path(s) to restore"
    for (const item of targets) {
      const rel = this.resolve(item).slice(root.length + 1)
      const source = fromIndex ? tree : repo.index
      const known = [...new Set([...Object.keys(source), ...Object.keys(fromIndex ? repo.index : files)])].filter(f => rel === "" || f === rel || f.startsWith(`${rel}/`)).filter(f => fromIndex || f in repo.index)
      if (!known.length) return `error: pathspec '${item}' did not match any file(s) known to git`
      known.forEach(f => {
        if (fromIndex) { if (f in tree) repo.index[f] = tree[f]; else delete repo.index[f] }
        else this.checkOut(root, {}, { [f]: repo.index[f] })
      })
    }
    return ""
  },

  merge(args, state) {
    const { root, repo, head, tree, staged, unstaged, history } = state
    if (args.includes("--abort")) {
      if (!repo.merging) return "fatal: There is no merge to abort (MERGE_HEAD missing)."
      this.checkOut(root, repo.index, tree)
      repo.merging.conflicts.forEach(f => { if (!(f in tree) && this.isFile(`${root}/${f}`)) { const { dir: folder, name } = this.parent(`${root}/${f}`); delete folder.children[name] } })
      repo.index = { ...tree }
      repo.merging = null
      return ""
    }
    const said = args.indexOf("-m")
    const name = plain(args).find((a, n) => !a.startsWith("--") && (said < 0 || args.indexOf(a) !== said + 1))
    if (!name) return "fatal: name the branch to merge in: git merge branch-name"
    if (repo.merging) return "fatal: You have not concluded your merge. Finish it with git commit, or stop it with git merge --abort."
    const target = repo.branches[name]
    if (!target) return `merge: ${name} - not something we can merge`
    if (history.some(c => c.id === target)) return "Already up to date."
    if (staged.length || unstaged.length) return "error: Your local changes would be overwritten by merge.\nPlease commit your changes before you merge."
    const theirs = repo.commits[target].files
    const theirHistory = this.ancestors(repo, target)
    const summary = (from, to) => { const changed = [...new Set([...Object.keys(from), ...Object.keys(to)])].filter(f => from[f] !== to[f]); return [...changed.map(f => ` ${f}`), ` ${count(changed.length, "file")} changed`].join("\n") }
    if (!head || theirHistory.some(c => c.id === head)) {
      this.checkOut(root, tree, theirs)
      repo.branches[repo.branch] = target
      repo.index = { ...theirs }
      return `Updating ${head || "(nothing)"}..${target}\nFast-forward\n${summary(tree, theirs)}`
    }
    const base = history.find(c => theirHistory.some(t => t.id === c.id))?.files || {}
    const result = {}, conflicts = []
    ;[...new Set([...Object.keys(tree), ...Object.keys(theirs)])].sort().forEach(f => {
      const [b, o, t] = [base[f], tree[f], theirs[f]]
      const pick = o === t || t === b ? o : o === b ? t : null
      if (pick === null) { conflicts.push(f); result[f] = `<<<<<<< HEAD\n${o ?? ""}=======\n${t ?? ""}>>>>>>> ${name}\n` }
      else if (pick !== undefined) result[f] = pick
    })
    this.checkOut(root, tree, result)
    if (!conflicts.length) {
      const message = said >= 0 && args[said + 1] ? args[said + 1] : `Merge branch '${name}'`
      this.commit(repo, message, result, [head, target])
      return `Merge made by the 'ort' strategy.\n${summary(tree, result)}`
    }
    repo.index = { ...result }
    conflicts.forEach(f => { if (f in tree) repo.index[f] = tree[f]; else delete repo.index[f] })
    repo.merging = { name, target, conflicts }
    return [...conflicts.map(f => `Auto-merging ${f}\nCONFLICT (content): Merge conflict in ${f}`), "Automatic merge failed; fix conflicts and then commit the result."].join("\n")
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
  help() { return `Practice commands: pwd ls cd mkdir touch cat echo cp mv rm rmdir clear whoami date history ruby git\nPractice git: ${GIT_KNOWS}\nSend output to a file with > (replace) or >> (add to the end).` },
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
