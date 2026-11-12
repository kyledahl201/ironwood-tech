---
id: demo-git
course: TOUR
lesson: 6
title: A tour of Git in the practice Terminal
professor: Sentry
minutes: 15
---

## Step: teach
**Git** keeps the history of a project. Each time you reach a point worth keeping, you take a snapshot called a **commit**. You can look back at any commit, and try ideas on a side copy called a **branch** without risking what works.

Every engineering team uses it, every day. The practice Terminal has its own Git, so you can learn the moves here where nothing can break.

## Step: try
mode: terminal
Make a folder called `notes`, go into it, and turn it into a Git project. The Git command that starts a project is `git init`.

### Checks
| type | call / input | expected |
|---|---|---|
| cwd_is | - | `~/notes` |
| git_repo_is | - | `~/notes` (the notes folder is a Git project) |

### Hints
1. That's three commands: make the folder, move into it, then start Git.
2. `mkdir` makes a folder and `cd` moves into one.
3. Run `git init` only after your prompt shows you are inside `notes`.

## Step: try
mode: terminal
Make a file with one line in it, then ask Git what it sees. This makes the file:

`echo "Learn Git" > plan.txt`

Then run the command that asks Git how things stand: `git status`.

### Checks
| type | call / input | expected |
|---|---|---|
| file_exists | - | `~/notes/plan.txt` |
| output_matches | - | `Untracked files:` (Git told you it sees a new file) |

### Hints
1. Type the `echo` line exactly as shown, quotes and all.
2. Then type `git status` on its own line. Read what comes back: Git lists the file as untracked, which means "I see it, but I'm not keeping it yet."

## Step: teach
A commit takes two moves.

1. **`git add`** picks what goes into the snapshot. This is called staging. `git add plan.txt` stages one file. `git add .` stages everything that changed.
2. **`git commit -m "a message"`** takes the snapshot. The message says what changed, in a few words, for the person reading the history later. That person is usually you.

## Step: try
mode: terminal
Stage `plan.txt` and commit it, with a message that says what you did.

### Checks
| type | call / input | expected |
|---|---|---|
| git_tracked | - | `plan.txt` |
| git_commits | - | `1` (the project has its first commit) |
| git_clean | - | - |

### Hints
1. Two commands, in the order from the last step: first the one that stages, then the one that takes the snapshot.
2. The commit needs `-m` and then your message inside quotes.
3. If Git says "nothing added to commit", the file wasn't staged. Run `git status` to see where it stands.

## Step: quiz
You changed three files but only ran `git add` on one of them. What goes into your next commit?

- [ ] All three files
- [x] Only the one you added
- [ ] Nothing, until all three are added

> A commit holds what you staged. The other two changes stay in your folder, waiting, and `git status` will keep listing them.

## Step: try
mode: terminal
Time to try an idea safely. Make a new branch called `ideas` and move onto it. One command does both: `git switch -c` followed by the branch's name.

### Checks
| type | call / input | expected |
|---|---|---|
| git_branch_is | - | `ideas` |

### Hints
1. The `-c` means "create". The name goes right after it.
2. Run `git branch` afterwards. The star marks the branch you are on.

## Step: try
mode: terminal
You're on `ideas` now, so anything you commit stays off `main` until you say so. Add a second line to the plan, then commit it. This adds the line:

`echo "Build a site" >> plan.txt`

Before you commit, run `git diff` to see exactly what changed.

### Checks
| type | call / input | expected |
|---|---|---|
| command_matches | - | `^git diff` (you looked at the change first) |
| git_commits | - | `2` (the ideas branch has a second commit) |
| git_branch_is | - | `ideas` |
| git_clean | - | - |

### Hints
1. Two `>>` add to the end of a file. One `>` would replace it.
2. In `git diff`, a line starting with `+` is one you added.
3. Then it's the same two moves as before: stage, then commit with a message.

## Step: try
mode: terminal
The idea worked, so bring it into `main`. Switch back to `main`, look at `plan.txt` with `cat` (the new line isn't there), then merge the `ideas` branch in.

### Checks
| type | call / input | expected |
|---|---|---|
| git_branch_is | - | `main` |
| git_merged | - | `ideas` |
| file_contains | `~/notes/plan.txt` | `Build a site` |

### Hints
1. `git switch` with a branch's name moves you to it. No `-c` this time: the branch already exists.
2. You merge from the branch that should receive the work. So stand on `main`, then name the other branch.
3. The command is `git merge` followed by the branch to bring in.

## Step: teach
That's the everyday loop: **branch, change, add, commit, merge.**

The practice Git knows more for when your lessons need it: `git log` shows the history, `git restore` throws away a change you don't want, and when two branches change the same line it gives you a real conflict to fix.

What it can't do is talk to GitHub. `git push`, `git pull` and `git clone` need another computer on the other end, so those are "on your Mac" steps.
