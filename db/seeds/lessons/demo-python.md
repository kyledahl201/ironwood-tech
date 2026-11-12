---
id: demo-python
course: TOUR
lesson: 2
title: A tour of Python in the classroom
professor: Sentry
minutes: 8
---

## Step: teach
The bench speaks Python too. Courses that need it, like the Agentic AI Bootcamp, use two more tools:

- **Python console**: type one line of Python, press Enter, see what it gives back.
- **Python editor**: write a whole program, then run it.

Python runs right here in your browser. The first time, it takes a few seconds to load.

## Step: try
mode: pyrepl
Start in the Python console. Make a variable called `school` that holds the text `"Ironwood"`.

### Checks
| type | call / input | expected |
|---|---|---|
| value_is | `school` | `"Ironwood"` |

### Hints
1. A variable is a name, an equals sign, then the value.
2. Text needs quotes around it. Spelling and the capital I count.

## Step: try
mode: pyrepl
Variables stay until you reset the console. Ask Python how many letters are in `school`.

### Checks
| type | call / input | expected |
|---|---|---|
| command_matches | - | `len\(\s*school\s*\)` (you asked for the length) |
| output_matches | - | `^8$` (Python answered 8) |

### Hints
1. Python has a built-in function that gives the length of a text or a list.
2. Its name is three letters, short for "length". Put `school` inside its brackets.

## Step: teach
Python uses indenting to show what belongs inside a function or a loop. In the console, the prompt changes from `>>>` to `...` while you are inside a block.

When the block is finished, press **Enter on an empty line** to run it.

## Step: try
mode: pyrepl
Write a function called `double` that takes a number and returns two times that number. Then call it with 21.

### Checks
| type | call / input | expected |
|---|---|---|
| value_is | `double(4)` | `8` |
| output_matches | - | `^42$` (you called it with 21) |

### Hints
1. A function starts with `def`, its name, its input in brackets, and a colon. The next line is indented.
2. Inside, `return` hands a value back. After the indented line, press Enter on an empty line.
3. Once the function exists, call it by name with 21 in the brackets.

## Step: quiz
In the Python console, the prompt shows `...` and nothing runs when you press Enter. What is Python waiting for?
- [ ] For you to type `end`
- [x] For the rest of the block, then an empty line
- [ ] For the page to reload
> `...` means you are inside a block. An empty line tells Python the block is finished.

## Step: try
mode: python
Now the editor. Finish `shout` so it returns the text in capital letters with an exclamation mark on the end, then press **Check**.

### Starter
```python
def shout(text):
    # your code here
    pass


print(shout("ab initio"))
```

### Checks
| type | call / input | expected |
|---|---|---|
| stdout | - | `AB INITIO!\n` |
| method_returns | `shout("owl")` | `"OWL!"` |
| source_excludes | - | AB INITIO |

### Hints
1. Text has a method that gives back a capital-letters copy of itself.
2. Join two pieces of text with `+`.
3. `return` the capital-letters copy of `text` joined to `"!"`.

## Step: teach
That's Python in the classroom. Anything that needs your real computer, like installing packages or calling a web address, is done as an "On your Mac" step.

## Study guide
- The Python console runs one entry at a time and keeps your variables until you reset it.
- `>>>` means Python is ready. `...` means it is waiting for the rest of a block.
- Press Enter on an empty line to finish an indented block in the console.
- The Python editor runs a whole program from a clean start each time.
- Python in the browser has the standard library only: no pip, files or internet.

## Flashcards
- What does the `...` prompt mean in the Python console? :: Python is waiting for the rest of a block.
- How do you finish an indented block in the console? :: Press Enter on an empty line.
- What does `def` start? :: A function definition.
- What does `return` do? :: Hands a value back from a function.
