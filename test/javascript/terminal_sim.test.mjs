import { test } from "node:test"
import assert from "node:assert/strict"
import { TerminalSim, tokenize } from "../../app/javascript/lib/terminal_sim.js"

const fresh = () => new TerminalSim({ user: "sam", runRuby: async code => ({ stdout: `ran: ${code}` }) })
const run = async (sim, ...lines) => { let last; for (const l of lines) last = await sim.exec(l); return last.output }

test("starts in the home folder with the usual Mac folders", async () => {
  const sim = fresh()
  assert.equal(await run(sim, "pwd"), "/Users/sam")
  assert.equal(await run(sim, "ls"), "Desktop  Documents  Downloads")
  assert.equal(await run(sim, "whoami"), "sam")
  assert.equal(sim.prompt, "sam@ironwood ~ %")
})

test("mkdir, cd and pwd move around, and errors read like a real shell", async () => {
  const sim = fresh()
  assert.equal(await run(sim, "mkdir code", "cd code", "pwd"), "/Users/sam/code")
  assert.equal(sim.prompt, "sam@ironwood code %")
  assert.equal(await run(sim, "cd .."), "")
  assert.equal(sim.cwd, "/Users/sam")
  assert.equal(await run(sim, "cd nowhere"), "cd: no such file or directory: nowhere")
  assert.equal(await run(sim, "mkdir code"), "mkdir: code: File exists")
  assert.equal(await run(sim, "mkdir -p a/b/c", "ls a/b"), "c")
  assert.equal(await run(sim, "cd ~/a/b/c", "cd", "pwd"), "/Users/sam")
})

test("touch, echo with > and >>, and cat work on files", async () => {
  const sim = fresh()
  await run(sim, "touch notes.txt")
  assert.equal(sim.read("~/notes.txt"), "")
  await run(sim, 'echo "first line" > notes.txt', "echo second >> notes.txt")
  assert.equal(await run(sim, "cat notes.txt"), "first line\nsecond")
  await run(sim, "echo replaced > notes.txt")
  assert.equal(sim.read("notes.txt"), "replaced\n")
  assert.equal(await run(sim, "cat missing.txt"), "cat: missing.txt: No such file or directory")
  assert.equal(await run(sim, "cat Desktop"), "cat: Desktop: Is a directory")
  assert.equal(await run(sim, "echo hi > nowhere/file.txt"), "zsh: no such file or directory: nowhere/file.txt")
})

test("single quotes keep double quotes inside, so Ruby can be echoed into a file", async () => {
  const sim = fresh()
  await run(sim, `echo 'puts "Hello from a file"' > hello.rb`)
  assert.equal(sim.read("hello.rb"), 'puts "Hello from a file"\n')
  assert.deepEqual(tokenize(`echo "a b" 'c d' e\\ f`).map(t => t.text), ["echo", "a b", "c d", "e f"])
  assert.equal(await run(sim, 'echo "unclosed'), 'zsh: unmatched "')
})

test("cp, mv, rm and rmdir", async () => {
  const sim = fresh()
  await run(sim, "echo a > one.txt", "cp one.txt two.txt", "mv two.txt Documents")
  assert.equal(sim.read("~/Documents/two.txt"), "a\n")
  assert.equal(sim.isFile("~/two.txt"), false)
  assert.equal(await run(sim, "rm one.txt"), "")
  assert.equal(sim.isFile("~/one.txt"), false)
  assert.equal(await run(sim, "rm one.txt"), "rm: one.txt: No such file or directory")
  assert.equal(await run(sim, "rm Documents"), "rm: Documents: is a directory")
  assert.equal(await run(sim, "rmdir Documents"), "rmdir: Documents: Directory not empty")
  assert.equal(await run(sim, "rm -r Documents"), "")
  assert.equal(sim.isDir("~/Documents"), false)
  assert.equal(await run(sim, "rmdir Desktop"), "")
  assert.match(await run(sim, "mkdir here", "cd here", "rm -r ../here"), /standing in it/)
})

test("ls flags", async () => {
  const sim = fresh()
  await run(sim, "touch .hidden", "echo hey > file.txt")
  assert.equal(await run(sim, "ls"), "Desktop  Documents  Downloads  file.txt")
  assert.match(await run(sim, "ls -a"), /\.hidden/)
  assert.match(await run(sim, "ls -la"), /-rw-r--r--  sam\s+4  file\.txt/)
  assert.equal(await run(sim, "ls nope"), "ls: nope: No such file or directory")
})

test("history lists what was typed, in order", async () => {
  const sim = fresh()
  const out = await run(sim, "pwd", "ls", "history")
  assert.deepEqual(out.split("\n").map(l => l.trim()), ["1  pwd", "2  ls", "3  history"])
})

test("Tab completes a name only when exactly one fits", async () => {
  const sim = fresh()
  await run(sim, "touch hello.rb", "mkdir code", "touch code/app.rb")
  assert.equal(sim.complete("cat he"), "cat hello.rb")
  assert.equal(sim.complete("cd co"), "cd code/")
  assert.equal(sim.complete("cat code/a"), "cat code/app.rb")
  assert.equal(sim.complete("cd D"), "cd D") // Desktop, Documents and Downloads all fit
  assert.equal(sim.complete("cat zzz"), "cat zzz")
})

test("ruby runs a file or a line through the Ruby runner", async () => {
  const sim = fresh()
  await run(sim, `echo 'puts 1' > one.rb`)
  assert.equal(await run(sim, "ruby one.rb"), "ran: puts 1")
  assert.equal(await run(sim, `ruby -e 'puts "hi"'`), 'ran: puts "hi"')
  assert.match(await run(sim, "ruby missing.rb"), /No such file or directory -- missing\.rb/)
  assert.match(await run(sim, "ruby -v"), /^ruby /)
  const broken = new TerminalSim({ runRuby: async () => ({ stdout: "", error: { friendly: "Friendly words.", raw: "NameError: x" } }) })
  await broken.exec("echo x > a.rb")
  assert.equal((await broken.exec("ruby a.rb")).output, "Friendly words.\nNameError: x")
})

test("unknown commands, real-only tools and clear", async () => {
  const sim = fresh()
  assert.equal(await run(sim, "frobnicate"), "zsh: command not found: frobnicate")
  assert.match(await run(sim, "brew install mise"), /real tool/)
  assert.deepEqual(await sim.exec("clear"), { output: "", clear: true })
  assert.equal(await run(sim, "   "), "")
})

test("practice git: init, status, add, commit, log", async () => {
  const sim = fresh()
  assert.match(await run(sim, "git status"), /not a git repository/)
  await run(sim, "mkdir proj", "cd proj", "git init", "echo a > a.txt")
  assert.match(await run(sim, "git status"), /Untracked files:\n\ta\.txt/)
  await run(sim, "git add .")
  assert.match(await run(sim, "git status"), /Changes to be committed:\n\tnew file:   a\.txt/)
  assert.match(await run(sim, 'git commit -m "first"'), /\[main \(root-commit\) [0-9a-f]{7}\] first\n 1 file changed/)
  assert.match(await run(sim, "git status"), /nothing to commit, working tree clean/)
  await run(sim, "echo b >> a.txt")
  assert.match(await run(sim, "git status"), /Changes not staged for commit:\n\tmodified:   a\.txt/)
  assert.match(await run(sim, 'git commit -m "second"'), /no changes added to commit/)
  assert.match(await run(sim, "git log --oneline"), /^[0-9a-f]{7} first$/)
})

test("the practice computer survives a reload", async () => {
  const sim = fresh()
  await run(sim, "mkdir code", "cd code", "echo x > f.txt")
  const copy = fresh()
  assert.equal(copy.restore(sim.serialize()), true)
  assert.equal(copy.cwd, "/Users/sam/code")
  assert.equal(copy.read("f.txt"), "x\n")
  assert.equal(copy.restore("not json"), false)
})
