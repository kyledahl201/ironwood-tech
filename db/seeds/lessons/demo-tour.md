---
id: demo-tour
course: TOUR
lesson: 1
title: A tour of the classroom
professor: Sentry
minutes: 8
---

## Step: teach
Welcome to the classroom. I'm Sentry. Your professors teach up here, one step at a time, and you work in the bench below.

Read a step, then press **Continue**. When a step gives you a task, the next one opens as soon as your work checks out.

## Step: teach
The bench below has three tools, and each step picks the right one for you:

- **Terminal**: a practice computer. Nothing you do here can touch your real Mac.
- **Ruby console**: type one line of Ruby, press Enter, see what it gives back.
- **Ruby editor**: write a whole program, then run it.

You can switch tools yourself with the dropdown whenever you want to experiment. The bench has Python, JavaScript and SQL tools too. Each has its own short tour.

## Step: try
mode: terminal
Start in the practice Terminal. Ask the computer which folder you are in.

### Checks
| type | call / input | expected |
|---|---|---|
| command_matches | - | `^pwd$` (you asked where you are) |

### Hints
1. There is a three-letter command that stands for "print working directory".
2. Type the letters p, w, d and press Enter.

## Step: try
mode: terminal
Make a folder called `tour`, then move into it.

### Checks
| type | call / input | expected |
|---|---|---|
| dir_exists | - | ~/tour |
| cwd_is | - | ~/tour |

### Hints
1. One command makes a directory. Another changes directory.
2. `mkdir` takes the new folder's name. `cd` takes the folder to move into.

## Step: quiz
You typed `cd tour`. What did that do?
- [ ] It made a new folder called tour
- [x] It moved you into the folder called tour
- [ ] It deleted the folder called tour
> `cd` means "change directory". Making a folder is `mkdir`.

## Step: try
mode: irb
Now the Ruby console. Make a variable called `school` that holds the text `"Ironwood"`.

### Checks
| type | call / input | expected |
|---|---|---|
| value_is | `school` | `"Ironwood"` |

### Hints
1. A variable is a name, an equals sign, then the value.
2. Text needs quotes around it. Spelling and the capital I count.

## Step: show
visual: loop
Some steps show a visualizer like this one. Press Step a few times to watch Ruby walk through a list, then Continue.

## Step: try
mode: ruby
Last one. In the editor, write a program that prints exactly `Ab initio` and press **Check**.

### Starter
```ruby
# Print the motto on the line below.
```

### Checks
| type | call / input | expected |
|---|---|---|
| stdout | - | `Ab initio\n` |

### Hints
1. Ruby's command for printing a line is four letters long.
2. The text goes in quotes after `puts`.

## Step: teach
That's the classroom. Your time in here is logged by itself, and finishing a lesson opens its practice exercises in the Code lab.

Your professors give the real grades. The checks in here are self-checked practice.

## Study guide
- The classroom plays a lesson one step at a time; tasks open the next step when they check out.
- `pwd` prints the folder you are in. `mkdir name` makes a folder. `cd name` moves into it.
- In the Ruby console, a line's value prints after `=>`.
- `puts` prints a line of text.

## Flashcards
- What does `pwd` stand for? :: Print working directory: the folder you are in.
- Which command makes a new folder? :: `mkdir`
- What does `cd` do? :: Changes the folder you are in.
- What does `puts` do? :: Prints its text, then a new line.

## Homework

### Task
mode: terminal
Inside your home folder, make a folder called `practice` with a file inside it called `notes.txt`.

#### Checks
| type | call / input | expected |
|---|---|---|
| file_exists | - | ~/practice/notes.txt |

#### Hints
1. You need two commands: one makes the folder, one makes an empty file.
2. `touch` makes an empty file. Give it the path, folder first.
