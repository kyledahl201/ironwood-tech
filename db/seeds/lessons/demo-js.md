---
id: demo-js
course: TOUR
lesson: 4
title: A tour of JavaScript in the classroom
professor: Sentry
minutes: 10
---

## Step: teach
The bench speaks JavaScript, the language every web browser runs. Rails apps use it for the parts of a page that react without reloading. It gets two tools:

- **JavaScript console**: type one line, press Enter, see what it gives back.
- **JavaScript editor**: write a whole program, then run it.

Here it's just the language: there's no web page to change and nothing to install.

## Step: try
mode: jsrepl
Start in the JavaScript console. Make a variable called `school` that holds the text `"Ironwood"`. In JavaScript you announce a new variable with the word `let`.

### Checks
| type | call / input | expected |
|---|---|---|
| value_is | `school` | `"Ironwood"` |

### Hints
1. The shape is the word `let`, a name, an equals sign, then the value.
2. Text needs quotes around it. Spelling and the capital I count.

## Step: try
mode: jsrepl
Names stay until you reset the console. Ask JavaScript how many letters are in `school`. Text keeps its length in a property, which you reach with a dot.

### Checks
| type | call / input | expected |
|---|---|---|
| command_matches | - | `school\s*\.\s*length` (you asked for the length) |
| output_matches | - | `^8$` (JavaScript answered 8) |

### Hints
1. A property comes after the name and a dot, with no brackets.
2. The property is called `length`.

## Step: teach
A function in JavaScript wraps its work in **curly brackets**:

```js
function half(n) {
  return n / 2
}
```

In the console you can type that over several lines. While a bracket is still open, the prompt changes from `>` to `…` and nothing runs until you close it.

## Step: try
mode: jsrepl
Write a function called `double` that takes a number and returns two times that number. Then call it with 21.

### Checks
| type | call / input | expected |
|---|---|---|
| value_is | `double(4)` | `8` |
| output_matches | - | `^42$` (you called it with 21) |

### Hints
1. Follow the shape of `half`: the word `function`, the name, the input in round brackets, then the work in curly brackets.
2. Inside, `return` hands a value back. Multiply with `*`.
3. Once the function exists, call it by name with 21 in round brackets.

## Step: quiz
In the JavaScript console, the prompt shows `…` and nothing runs when you press Enter. What is it waiting for?
- [ ] For you to type `end`
- [x] For the bracket you opened to be closed
- [ ] For the page to reload
> `…` means a bracket is still open. Close it and the whole entry runs. Ctrl+C gives up on the entry.

## Step: teach
Now the **JavaScript editor**, for whole programs. Two things to know:

- A value only shows up in the Output if you print it with `console.log(...)`.
- Text has methods you call with a dot and round brackets, like `"owl".toUpperCase()`.

## Step: try
mode: js
Finish `shout` so it returns the text in capital letters with an exclamation mark on the end, then press **Check**.

### Starter
```js
function shout(text) {
  // your code here
}

console.log(shout("ab initio"))
```

### Checks
| type | call / input | expected |
|---|---|---|
| stdout | - | `AB INITIO!\n` |
| method_returns | `shout("owl")` | `"OWL!"` |
| source_excludes | - | AB INITIO |

### Hints
1. The Output says `undefined`? The function isn't handing anything back yet. It needs a `return`.
2. Join two pieces of text with `+`.
3. Call the capital-letters method on `text`, then join `"!"` to the result.

## Step: teach
A list in JavaScript is called an **array**, written in square brackets. Arrays come with methods that take a small function and run it on every item. Small functions are often written with an arrow:

```js
const prices = [4, 10, 7]
prices.map(p => p * 2)       // a new array with every price doubled
prices.filter(p => p > 5)    // a new array with only the prices over 5
```

`const` is like `let`, for a name that will never be given a different value.

## Step: try
mode: js
Finish `longSessions` so it returns only the study sessions that lasted **3 hours or more**.

### Starter
```js
const hours = [2, 5, 1, 4]

function longSessions(list) {
  // your code here
}

console.log(longSessions(hours))
```

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | `longSessions([2, 5, 1, 4])` | `[5, 4]` |
| method_returns | `longSessions([3, 0.5])` | `[3]` |
| method_returns | `longSessions([1])` | `[]` |
| source_includes | - | .filter |

### Hints
1. One of the two array methods in the example keeps only some items. Use it on `list`, not on `hours`.
2. The arrow function should answer true for a session worth keeping.
3. "3 or more" is written `>=`. Remember to `return` the new array.

## Step: teach
That's JavaScript in the classroom. What you practised here is the language itself. Making a web page react to clicks uses the same language with a page attached, and comes later.

## Study guide
- The JavaScript console runs one entry at a time and keeps your names until you reset it.
- `>` means it is ready. `…` means a bracket is still open.
- `let` announces a variable. `const` announces a name that never changes.
- A function's work goes in curly brackets, and `return` hands a value back.
- In the editor, use `console.log(...)` to print. Each run starts clean.
- Arrays have `.map` (change every item) and `.filter` (keep some items).

## Flashcards
- What does the `…` prompt mean in the JavaScript console? :: A bracket is still open.
- Which word announces a new variable? :: `let` (or `const` if it never changes)
- How do you print in the editor? :: `console.log(...)`
- What does a function give back if it has no `return`? :: `undefined`
- Which array method keeps only some items? :: `.filter`
- Which array method makes a new array by changing every item? :: `.map`
