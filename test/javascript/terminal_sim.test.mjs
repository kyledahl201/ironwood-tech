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
  assert.match(await run(sim, "git status"), /Untracked files:\n  \(use "git add <file>\.\.\." to include in what will be committed\)\n\ta\.txt\n\nnothing added to commit but untracked files present \(use "git add" to track\)$/)
  await run(sim, "git add .")
  assert.match(await run(sim, "git status"), /Changes to be committed:\n  \(use "git rm --cached <file>\.\.\." to unstage\)\n\tnew file:   a\.txt/)
  assert.match(await run(sim, 'git commit -m "first"'), /\[main \(root-commit\) [0-9a-f]{7}\] first\n 1 file changed/)
  assert.match(await run(sim, "git status"), /nothing to commit, working tree clean/)
  await run(sim, "echo b >> a.txt")
  assert.match(await run(sim, "git status"), /Changes not staged for commit:\n  \(use "git add <file>\.\.\." to update what will be committed\)\n  \(use "git restore <file>\.\.\." to discard changes in working directory\)\n\tmodified:   a\.txt\n\nno changes added to commit \(use "git add" and\/or "git commit -a"\)$/)
  assert.match(await run(sim, 'git commit -m "second"'), /no changes added to commit \(use "git add" and\/or "git commit -a"\)$/)
  assert.match(await run(sim, "git log --oneline"), /^[0-9a-f]{7} \(HEAD -> main\) first$/)
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

// A project with one commit on main, for the git tests below.
async function project() {
  const sim = fresh()
  await run(sim, "mkdir site", "cd site", "git init", "echo '# Site' > README.md", "git add .", 'git commit -m "Start the site"')
  return sim
}

test("practice git: the index holds what was added, not what came after", async () => {
  const sim = await project()
  await run(sim, "echo one >> README.md", "git add README.md", "echo two >> README.md")
  const status = await run(sim, "git status")
  assert.match(status, /Changes to be committed:\n  \(use "git restore --staged <file>\.\.\." to unstage\)\n\tmodified:   README\.md/)
  assert.match(status, /Changes not staged for commit:\n  \(use "git add <file>\.\.\." to update what will be committed\)\n  \(use "git restore <file>\.\.\." to discard changes in working directory\)\n\tmodified:   README\.md$/)
  assert.equal(await run(sim, "git diff --staged"), "diff --git a/README.md b/README.md\n--- a/README.md\n+++ b/README.md\n@@ -1 +1,2 @@\n # Site\n+one")
  assert.equal(await run(sim, "git diff"), "diff --git a/README.md b/README.md\n--- a/README.md\n+++ b/README.md\n@@ -1,2 +1,3 @@\n # Site\n one\n+two")
  await run(sim, 'git commit -m "Add one"')
  assert.equal(sim.gitState().tree["README.md"], "# Site\none\n") // "two" was never added
  assert.match(await run(sim, 'git commit -am "Add two"'), /\[main [0-9a-f]{7}\] Add two\n 1 file changed/)
  assert.equal(sim.gitState().clean, true)
  assert.match(await run(sim, "git commit -m again"), /nothing to commit, working tree clean/)
  assert.match(await run(sim, "echo x > new.txt", "git commit -m x"), /nothing added to commit but untracked files present \(use "git add" to track\)$/)
})

test("practice git: deleted files, git rm, restore and .gitignore", async () => {
  const sim = await project()
  await run(sim, "echo a > a.txt", "echo secret > .env", "echo '.env' > .gitignore", "echo '*.log' >> .gitignore", "echo 'tmp/' >> .gitignore", "mkdir tmp", "echo t > tmp/t.txt", "echo l > run.log")
  assert.match(await run(sim, "git status"), /Untracked files:\n  \(use "git add <file>\.\.\." to include in what will be committed\)\n\t\.gitignore\n\ta\.txt\n/)
  assert.match(await run(sim, "git add .env"), /ignored by one of your \.gitignore files:\n\.env/)
  await run(sim, "git add .", "git commit -m files")
  assert.deepEqual(Object.keys(sim.gitState().tree).sort(), [".gitignore", "README.md", "a.txt"])

  await run(sim, "rm a.txt")
  assert.match(await run(sim, "git status"), /Changes not staged for commit:\n  \(use "git add\/rm <file>\.\.\." to update what will be committed\)\n  \(use "git restore <file>\.\.\." to discard changes in working directory\)\n\tdeleted:    a\.txt/)
  await run(sim, "git restore a.txt")
  assert.equal(await run(sim, "cat a.txt"), "a")
  assert.equal(await run(sim, "git rm a.txt"), "rm 'a.txt'")
  assert.match(await run(sim, "git status"), /Changes to be committed:\n  \(use "git restore --staged <file>\.\.\." to unstage\)\n\tdeleted:    a\.txt/)
  await run(sim, "git restore --staged a.txt", "git restore a.txt")
  assert.equal(sim.gitState().clean, true)
  await run(sim, "echo junk >> README.md", "git add .", "git restore --staged .", "git restore .")
  assert.equal(sim.gitState().clean, true)
  assert.match(await run(sim, "git restore nope.txt"), /did not match any file/)
  assert.match(await run(sim, "git add nope.txt"), /pathspec 'nope.txt' did not match any files/)
})

test("practice git: branches, switching and a fast-forward merge", async () => {
  const sim = await project()
  assert.equal(await run(sim, "git branch"), "* main")
  assert.equal(await run(sim, "git switch -c about"), "Switched to a new branch 'about'")
  assert.equal(await run(sim, "git branch"), "* about\n  main")
  await run(sim, "echo About > about.md", "git add .", 'git commit -m "Add the about page"')
  assert.match(await run(sim, "git log --oneline"), /^[0-9a-f]{7} \(HEAD -> about\) Add the about page\n[0-9a-f]{7} \(main\) Start the site$/)
  assert.equal(await run(sim, "git switch main"), "Switched to branch 'main'")
  assert.equal(await run(sim, "ls"), "README.md") // the other branch's file left the folder
  assert.match(await run(sim, "git branch -d about"), /not fully merged/)
  assert.match(await run(sim, "git merge about"), /^Updating [0-9a-f]{7}\.\.[0-9a-f]{7}\nFast-forward\n about\.md\n 1 file changed$/)
  assert.equal(await run(sim, "ls"), "about.md  README.md")
  assert.equal(await run(sim, "git merge about"), "Already up to date.")
  assert.match(await run(sim, "git branch -d about"), /^Deleted branch about \(was [0-9a-f]{7}\)\.$/)
  assert.equal(await run(sim, "git checkout -b fix"), "Switched to a new branch 'fix'")
  assert.equal(await run(sim, "git checkout main"), "Switched to branch 'main'")
  assert.equal(await run(sim, "git switch main"), "Already on 'main'")
  assert.match(await run(sim, "git switch nope"), /invalid reference: nope/)
  assert.match(await run(sim, "git branch fix"), /already exists/)
  assert.match(await run(sim, "git branch -d main"), /you are on it/)
  assert.match(await run(sim, "git merge nope"), /not something we can merge/)
  // Work that isn't committed is never silently lost by a switch.
  await run(sim, "git switch fix", "echo fixed > README.md", 'git commit -am "Fix"', "git switch main", "echo mine > README.md")
  assert.match(await run(sim, "git switch fix"), /would be overwritten by checkout:\n\tREADME\.md\nPlease commit your changes/)
  assert.equal(await run(sim, "cat README.md"), "mine")
})

test("practice git: a merge of two lines of work, and a real conflict to fix", async () => {
  const sim = await project()
  await run(sim, "git switch -c footer", "echo foot > footer.md", "git add .", "git commit -m Footer", "git switch main", "echo notes > notes.md", "git add .", "git commit -m Notes")
  assert.match(await run(sim, "git merge footer"), /^Merge made by the 'ort' strategy\.\n footer\.md\n 1 file changed$/)
  assert.equal(await run(sim, "ls"), "footer.md  notes.md  README.md")
  assert.match(await run(sim, "git log -1"), /^commit [0-9a-f]{7} \(HEAD -> main\)\nMerge: [0-9a-f]{7} [0-9a-f]{7}\nAuthor: sam\n\n    Merge branch 'footer'$/)
  assert.equal(sim.gitState().commits, 4)
  assert.equal(sim.gitState().merged("footer"), true)

  await run(sim, "git switch -c tagline", "echo '# Site, built to last' > README.md", 'git commit -am "Tagline"', "git switch main", "echo '# The Site' > README.md", 'git commit -am "Rename"')
  assert.equal(await run(sim, "git merge tagline"), "Auto-merging README.md\nCONFLICT (content): Merge conflict in README.md\nAutomatic merge failed; fix conflicts and then commit the result.")
  assert.equal(await run(sim, "cat README.md"), "<<<<<<< HEAD\n# The Site\n=======\n# Site, built to last\n>>>>>>> tagline")
  assert.match(await run(sim, "git status"), /You have unmerged paths\.[\s\S]*Unmerged paths:[\s\S]*\tboth modified:   README\.md/)
  assert.match(await run(sim, "git commit -m done"), /Committing is not possible because you have unmerged files/)
  assert.match(await run(sim, "git switch tagline"), /in the middle of a merge/)
  assert.equal(sim.gitState().clean, false)

  // Backing out puts everything back.
  assert.equal(await run(sim, "git merge --abort"), "")
  assert.equal(await run(sim, "cat README.md"), "# The Site")
  assert.equal(sim.gitState().clean, true)

  // Fixing it: edit the file, add it, commit.
  await run(sim, "git merge tagline", "echo '# The Site, built to last' > README.md", "git add README.md")
  assert.match(await run(sim, "git status"), /All conflicts fixed but you are still merging/)
  assert.match(await run(sim, "git commit"), /^\[main [0-9a-f]{7}\] Merge branch 'tagline'$/)
  assert.equal(sim.gitState().merged("tagline"), true)
  assert.equal(sim.gitState().clean, true)
  assert.match(await run(sim, "git merge --abort"), /no merge to abort/)
})

test("practice git: what it doesn't do, it says plainly, and its state survives a reload", async () => {
  const sim = await project()
  for (const real of ["push", "pull", "clone https://example.com/x.git", "fetch", "remote -v"]) assert.match(await run(sim, `git ${real}`), /talks to another computer \(like GitHub\)[\s\S]*on your Mac/)
  // A real command that practice git leaves out is named as real, and as coming later.
  for (const later of ["stash", "reset --hard", "rebase main", "tag v1", "mv a b", "revert HEAD", "show", "config user.name Sam"]) {
    assert.match(await run(sim, `git ${later}`), new RegExp(`^git ${later.split(" ")[0]} is a real git command, but practice git doesn't have it\\. It comes later, in the Terminal app on your Mac\\.\\n\\nPractice git knows: init, status, add, commit, log, diff, branch, switch, checkout, merge, restore, rm$`))
  }
  // Only a word git itself wouldn't know gets git's own "not a git command".
  assert.match(await run(sim, "git comit"), /^git: 'comit' is not a git command\. See 'git --help'\./)
  assert.match(await run(sim, "git commit --amend"), /doesn't rewrite commits/)
  assert.match(await run(sim, "git"), /Practice commands: init, status/)
  assert.match(await run(sim, "help"), /Practice git: init, status/)

  await run(sim, "git switch -c spare", "echo s > s.txt", "git add .", "git commit -m Spare")
  const again = fresh()
  again.restore(sim.serialize())
  assert.equal(again.gitState().branch, "spare")
  assert.deepEqual(again.gitState().branches, ["main", "spare"])
  assert.match(await run(again, "git log --oneline"), /\(HEAD -> spare\) Spare\n[0-9a-f]{7} \(main\) Start the site$/)

  // A repository saved by the older classroom (a list of commits, a list of staged names) still opens.
  const old = fresh()
  await run(old, "mkdir p", "cd p", "echo a > a.txt", "echo b > b.txt")
  old.repos["/Users/sam/p"] = { staged: ["b.txt"], commits: [{ id: "aaaaaaa", message: "first", files: { "a.txt": "a\n" } }] }
  assert.match(await run(old, "git status"), /On branch main\n\nChanges to be committed:\n  \(use "git restore --staged <file>\.\.\." to unstage\)\n\tnew file:   b\.txt$/)
  assert.match(await run(old, 'git commit -m "second"'), /\[main [0-9a-f]{7}\] second/)
  assert.match(await run(old, "git log --oneline"), /second\naaaaaaa first$/)
})

test("practice git: diff prints real @@ hunk headers for an add, a change and a delete", async () => {
  const sim = await project()
  const twenty = skip => Array.from({ length: 20 }, (_, i) => `line ${i + 1}`).filter((_, i) => i !== skip).join("\n") + "\n"
  sim.write("/Users/sam/site/long.txt", twenty())
  await run(sim, "git add .")
  // A new file: nothing before, twenty lines after.
  assert.match(await run(sim, "git diff --staged"), /^diff --git a\/long\.txt b\/long\.txt\nnew file mode 100644\n--- \/dev\/null\n\+\+\+ b\/long\.txt\n@@ -0,0 \+1,20 @@\n\+line 1\n/)
  await run(sim, "git commit -m long")

  // A line added in the middle: three lines of context each side, and the new file is one longer.
  sim.write("/Users/sam/site/long.txt", twenty().replace("line 10\n", "line 10\nten and a half\n"))
  assert.equal(await run(sim, "git diff"), ["diff --git a/long.txt b/long.txt", "--- a/long.txt", "+++ b/long.txt", "@@ -8,6 +8,7 @@", " line 8", " line 9", " line 10", "+ten and a half", " line 11", " line 12", " line 13"].join("\n"))

  // A line changed: the old one leaves, then the new one arrives, and the counts match.
  sim.write("/Users/sam/site/long.txt", twenty().replace("line 2\n", "LINE TWO\n"))
  assert.equal(await run(sim, "git diff"), ["diff --git a/long.txt b/long.txt", "--- a/long.txt", "+++ b/long.txt", "@@ -1,5 +1,5 @@", " line 1", "-line 2", "+LINE TWO", " line 3", " line 4", " line 5"].join("\n"))

  // A line deleted near the end, and two changes far apart get a hunk each.
  sim.write("/Users/sam/site/long.txt", twenty(15))
  assert.equal(await run(sim, "git diff"), ["diff --git a/long.txt b/long.txt", "--- a/long.txt", "+++ b/long.txt", "@@ -13,7 +13,6 @@", " line 13", " line 14", " line 15", "-line 16", " line 17", " line 18", " line 19"].join("\n"))
  sim.write("/Users/sam/site/long.txt", twenty(15).replace("line 2\n", "LINE TWO\n"))
  assert.deepEqual((await run(sim, "git diff")).split("\n").filter(l => l.startsWith("@@")), ["@@ -1,5 +1,5 @@", "@@ -13,7 +13,6 @@"])

  // A whole file deleted, and a one-line file.
  await run(sim, "git restore .", "rm README.md")
  assert.equal(await run(sim, "git diff"), "diff --git a/README.md b/README.md\ndeleted file mode 100644\n--- a/README.md\n+++ /dev/null\n@@ -1 +0,0 @@\n-# Site")
  assert.equal(await run(sim, "git restore .", "git diff"), "")
})

test("practice git: git rm --cached unstages a new file without deleting it", async () => {
  const sim = fresh()
  await run(sim, "mkdir p", "cd p", "git init", "echo a > a.txt", "git add .")
  assert.equal(await run(sim, "git rm --cached a.txt"), "rm 'a.txt'")
  assert.equal(await run(sim, "cat a.txt"), "a")
  assert.match(await run(sim, "git status"), /Untracked files:[\s\S]*\ta\.txt/)
})
