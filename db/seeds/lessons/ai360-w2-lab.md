---
id: ai360-w2-lab
course: AI 360
lesson: 4
title: "Week 2 lab: token-cost-estimator"
professor: Prof. Reyes
minutes: 120
---

## Step: teach
Lab day. You'll build three tiny engines from the lesson for real: a **subword tokenizer**, a **temperature** adjuster, and a **sampler**. You'll run an experiment with them, then ship **token-cost-estimator**, portfolio project 2.

Still no API key. Everything here runs on plain Python, which is the point: once you've built a toy version of each part, the real model stops being a black box.

## Step: teach
A simple subword tokenizer works like this. You have a **vocabulary**: a set of known pieces. Starting at the front of a word, take the **longest** piece from the vocabulary that the word starts with. Cut it off and repeat on what's left. If no piece matches, take a single character and move on.

With the vocabulary `{"re", "win", "window", "s"}`, the word `rewindows` becomes `re`, then `window` (it's longer than `win`, so it wins), then `s`. This is called **greedy longest match**.

## Step: try
mode: python
Write `subword(word, vocab)` that **returns** the list of pieces using greedy longest match. If nothing in `vocab` matches at the current position, use one character as the piece.

### Starter
```python
VOCAB = {"re", "win", "window", "dow", "s", "un", "believ", "able", "be", "lie"}

# Write subword below, then print subword("rewindows", VOCAB)
```

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | subword("rewindows", VOCAB) | ["re", "window", "s"] |
| method_returns | subword("unbelievable", VOCAB) | ["un", "believ", "able"] |
| method_returns | subword("xyz", VOCAB) | ["x", "y", "z"] |
| method_returns | subword("", VOCAB) | [] |
| stdout | - | `['re', 'window', 's']\n` |

### Hints
1. Keep a position `i` that starts at 0, and loop `while i < len(word)`.
2. At each position, try the longest possible slice first, `word[i:end]`, and shrink `end` until the slice is in `vocab`.
3. If you shrink all the way down to one character without a match, take that one character anyway. Either way, move `i` forward by the length of the piece you took.

## Step: try
mode: python
Below it, write `count_subwords(text, vocab)` that lowercases the text, splits it on spaces, and **returns** the total number of subword pieces across all the words.

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | count_subwords("Rewindows unbelievable", VOCAB) | 6 |
| method_returns | count_subwords("Ozwick windows", VOCAB) | 8 |
| method_returns | count_subwords("", VOCAB) | 0 |
| source_includes | - | subword( |

### Hints
1. `.lower()` then `.split()` gives you a list of words.
2. Add up `len(subword(w, vocab))` for each word.

## Step: teach
Look at your trace for `"Ozwick windows"`. The made-up name `Ozwick` isn't in the vocabulary, so it shattered into six single-character tokens, while `windows` cost only two.

Real tokenizers have vocabularies of tens of thousands of pieces, but the pattern holds: common words are cheap, and names, typos, rare words, long numbers and unusual formatting are expensive. When you budget for a real app, test with realistic text, not just tidy English.

## Step: quiz
Why does a made-up surname usually cost more tokens than the word "house"?
- [ ] Names are always longer
- [x] It isn't a common piece in the vocabulary, so it gets split into many small pieces
- [ ] Models charge extra for capital letters
> Common words are often a single token. Rare strings fall apart into many small pieces, each one a token.

## Step: teach
Now temperature, for real. One simple way to apply a temperature `t`: raise every probability to the power `1 / t`, then **normalize**, which means dividing each one by the new total so they add up to 1 again.

- `t = 1`: the power is 1, so nothing changes.
- `t < 1`: big probabilities get bigger compared to small ones. Sharper.
- `t > 1`: everything moves toward equal. Flatter.

In Python, `x ** y` is x to the power of y.

## Step: try
mode: python
Write `apply_temperature(probs, t)` that **returns** a new dict with the same tokens and the adjusted, normalized probabilities, each rounded to 2 decimal places.

### Starter
```python
# Write apply_temperature below.
```

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | apply_temperature({"a": 0.8, "b": 0.2}, 1.0) | {"a": 0.8, "b": 0.2} |
| method_returns | apply_temperature({"a": 0.8, "b": 0.2}, 0.5) | {"a": 0.94, "b": 0.06} |
| method_returns | apply_temperature({"a": 0.8, "b": 0.2}, 2.0) | {"a": 0.67, "b": 0.33} |
| method_returns | apply_temperature({"Monday": 0.4, "Tuesday": 0.3, "time": 0.2, "a": 0.1}, 2.0) | {"Monday": 0.33, "Tuesday": 0.28, "time": 0.23, "a": 0.16} |

### Hints
1. Two passes. First build a dict of raised values (`p ** (1 / t)`), then add those up.
2. Second pass: divide each raised value by the total, and round to 2 places.
3. Round only in the second pass. Rounding the raised values first throws the total off.

## Step: teach
To actually **pick** a token by its odds, Python has `random.choices(options, weights=...)`. It returns a **list** (of one item by default), so you take item `[0]`.

For experiments you want the same "random" results every run, so you can compare. Make your own generator with a **seed**: `rng = random.Random(42)`, then call `rng.choices(...)`. Same seed, same sequence, every time. Repeatable results mean a trace you can trust.

## Step: try
mode: python
Write `pick(probs, rng)` that **returns** one token, chosen at random according to its probability, using the generator `rng` that's passed in.

### Starter
```python
import random

# Write pick below.
```

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | pick({"only": 1.0}, random.Random(1)) | "only" |
| method_returns | pick({"never": 0.0, "always": 1.0}, random.Random(7)) | "always" |
| source_includes | - | rng.choices |
| source_excludes | - | random.choice( |

### Hints
1. The options are the dict's keys, and the weights are its values. Both need to be lists.
2. `rng.choices(...)` returns a list. You want the single item inside it.

## Step: try
mode: python
Below `pick`, paste your `apply_temperature`, then write `experiment(probs, t, n, seed)`. It applies the temperature, makes `rng = random.Random(seed)`, picks `n` tokens, and **returns** a plain dict counting how many times each token came up.

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | experiment({"only": 1.0}, 0.5, 10, 1) | {"only": 10} |
| method_returns | experiment({"a": 0.9, "b": 0.1}, 0.1, 50, 3) | {"a": 50} |
| method_returns | sum(experiment({"a": 0.5, "b": 0.5}, 1.0, 20, 7).values()) | 20 |
| source_includes | - | apply_temperature( |

### Hints
1. Make the generator once, before the loop, not inside it.
2. `collections.Counter` counts things for you. Wrap it in `dict(...)` to return a plain dict.
3. Loop `n` times, calling `pick` on the **adjusted** probabilities.

## Step: quiz
At temperature 0.1, `{"a": 0.9, "b": 0.1}` gave 50 a's and zero b's. Why?
- [ ] The seed was unlucky
- [x] The low temperature sharpened the odds so much that "b" rounded to 0
- [ ] `random.choices` ignores small weights
> 0.9 to the 10th power is about 0.35, and 0.1 to the 10th is 0.0000000001. After normalizing, "a" is about 1.0 and "b" is about 0. That's why low temperature is near-greedy.

## Step: teach
Now the project. **token-cost-estimator** answers a question every AI builder asks before shipping: "what will this cost?" It estimates the tokens in a piece of text and prices the call on a few model sizes. Then it shows what temperature does, using your experiment.

We'll practise the report here first. The prices below are **pretend**, for small, medium and large models. Real ones are on each provider's pricing page.

## Step: try
mode: python
Paste your `estimate_tokens` (from the lesson homework) and `cost` (from the lesson) at the top. Then write `report(text, output_tokens, prices)` that **returns** one line per model, like `small: $0.002514`, with the cost shown to 6 decimal places. Print `report(NOTE, 500, PRICES)`.

### Starter
```python
import math

PRICES = {"small": (1.0, 5.0), "medium": (3.0, 15.0), "large": (15.0, 75.0)}
NOTE = "Customer wants 6 double-hung windows quoted by Friday."

# Paste estimate_tokens and cost here, then write report.
```

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | estimate_tokens(NOTE) | 14 |
| method_returns | report(NOTE, 500, PRICES) | "small: $0.002514\nmedium: $0.007542\nlarge: $0.037710" |
| method_returns | report("abcd", 0, {"tiny": (2.0, 4.0)}) | "tiny: $0.000002" |
| stdout | - | `small: $0.002514\nmedium: $0.007542\nlarge: $0.037710\n` |

### Hints
1. Loop over `prices.items()`. Each value is a tuple you can unpack: `in_price, out_price = ...`.
2. In an f-string, `{value:.6f}` shows a number with exactly 6 decimal places.
3. Collect the lines in a list and `"\n".join` them, as in last week's `brief`.

## Step: mac
Make this week's project folder in your portfolio and move into it. This project uses only Python's standard library, so it doesn't need a venv or packages.

### Run
```
mkdir -p ~/code/agentic-ai-portfolio/week-02-token-cost-estimator
```

```
cd ~/code/agentic-ai-portfolio/week-02-token-cost-estimator
```

```
pwd
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `/code/agentic-ai-portfolio/week-02-token-cost-estimator$` |

### Hints
1. Run all three in the same Terminal window, in order.

## Step: teach
In VS Code, create two files in this folder:

1. `sample.txt`: a paragraph of made-up text, like a fake customer note or job description. Include a made-up name and a long number, so you can see them cost more.
2. `token_cost_estimator.py`, with your `estimate_tokens`, `cost`, `report`, `apply_temperature`, `pick` and `experiment`. At the bottom, inside `if __name__ == "__main__":`, it should:
   - read `sample.txt`, then print `report(text, 500, PRICES)`;
   - then, for `t` in `0.2`, `1.0` and `2.0`, print a line like `t=0.2 {'Monday': 49, 'Tuesday': 1}`, using the "crew will arrive on" probabilities from the lesson, `n=50` and `seed=42`.

## Step: mac
Run it and paste the whole output.

### Run
```
python3 token_cost_estimator.py
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `^small: \$\d+\.\d{6}$` |
| output_matches | - | `^large: \$\d+\.\d{6}$` |
| output_matches | - | `^t=0\.2 \{` |
| output_matches | - | `^t=2\.0 \{` |

### Hints
1. `FileNotFoundError` means `sample.txt` isn't in the folder you ran from. Check with `ls`.
2. To read a file: `with open("sample.txt") as f:` and then `text = f.read()` inside the block.
3. A loop over `[0.2, 1.0, 2.0]` with an f-string like `f"t={t} {experiment(...)}"` prints the three lines.

## Step: teach
Now read your own trace. At `t=0.2`, how much did Monday dominate? At `t=2.0`, how many different tokens showed up? Write a `README.md` for this project with: what it does, how to run it, your full output pasted in, **three sentences in your own words on what temperature did**, and a known limit (for example, the 4-character rule is only an estimate).

## Step: mac
Commit project 2 from the portfolio root and show the log.

### Run
```
cd ~/code/agentic-ai-portfolio
```

```
git add . && git commit -m "Add week 2: token-cost-estimator"
```

```
git log --oneline
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `Add week 2: token-cost-estimator` |
| output_matches | - | `Add week 1: weather-brief` |

### Hints
1. If the commit says "nothing to commit", check that your files are saved in VS Code and are inside `week-02-token-cost-estimator`.

## Step: teach
Two weeks, two projects, and you've rebuilt the core loop of a language model with your own hands: tokenize, predict odds, adjust with temperature, sample, and pay per token.

Next week we finally call a real model with the Anthropic SDK. You'll need an API key and a spending cap set before class. Show me the trace.

## Study guide
- Greedy longest-match tokenizing: at each position, take the longest vocabulary piece that fits, or else one character.
- Unknown words break into many tokens, so test cost estimates with realistic, messy text.
- Temperature: raise each probability to the power `1/t`, then normalize so they add up to 1.
- `t < 1` sharpens the odds, `t > 1` flattens them, and `t = 1` leaves them unchanged.
- `rng.choices(options, weights=...)[0]` picks one item by its odds.
- A seeded generator (`random.Random(42)`) makes experiments repeatable.
- `collections.Counter` counts items. `f"{x:.6f}"` shows 6 decimal places.
- Every estimate in a README gets a "known limits" line.

## Flashcards
- Greedy longest match, in one sentence? :: At each position, take the longest known piece that fits, then repeat on the rest.
- What happens to a word the vocabulary doesn't know? :: It splits into many small pieces, often single characters.
- How do you apply temperature `t` to probabilities? :: Raise each to the power `1/t`, then divide by the new total.
- What does normalize mean here? :: Rescale the numbers so they add up to 1.
- `random.choices(...)` returns what? :: A list, so take `[0]` for one pick.
- Why seed a random generator in an experiment? :: So you get the same results every run and can compare fairly.
- What does `f"{0.0025:.6f}"` show? :: `0.002500`
- At very low temperature, sampling behaves like what? :: Greedy: it almost always picks the top token.

## Homework

### Task
mode: python
Write `cheapest(prices, input_tokens, output_tokens)` that **returns** the name of the cheapest model for that call. `prices` has the same shape as `PRICES`.

#### Starter
```python
PRICES = {"small": (1.0, 5.0), "medium": (3.0, 15.0), "large": (15.0, 75.0)}

# Write cheapest below.
```

#### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | cheapest(PRICES, 2000, 500) | "small" |
| method_returns | cheapest({"x": (1.0, 20.0), "y": (4.0, 4.0)}, 1000, 1000) | "y" |
| method_returns | cheapest({"x": (1.0, 20.0), "y": (4.0, 4.0)}, 10000, 0) | "x" |

#### Hints
1. Work out each model's cost for this call, then pick the smallest.
2. `min` takes a `key=` argument, just like `max`.

### Task
mode: python
A preview of Week 5. Write `trim_to_budget(messages, max_tokens)` that keeps the **newest** messages whose estimated tokens (4-characters rule, rounded up) fit within `max_tokens`, and **returns** them in their original order. Stop at the first message that doesn't fit.

#### Starter
```python
import math

# Write trim_to_budget below.
```

#### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | trim_to_budget(["a" * 40, "b" * 20, "c" * 8], 7) | ["b" * 20, "c" * 8] |
| method_returns | trim_to_budget(["a" * 40, "b" * 20, "c" * 8], 6) | ["c" * 8] |
| method_returns | trim_to_budget(["a" * 40, "b" * 20, "c" * 8], 100) | ["a" * 40, "b" * 20, "c" * 8] |
| method_returns | trim_to_budget(["a" * 40], 3) | [] |

#### Hints
1. Walk the list from the end (`reversed(messages)`), adding up tokens as you go.
2. When adding the next message would go over the budget, stop.
3. You collected them newest-first, so flip them back before returning.

### Task
mode: python
**Judge it.** This cost function gives answers 1,000 times too big, and it's also mixing up which price goes with which tokens. Fix `call_cost` so the checks pass. Keep the same parameters.

#### Starter
```python
def call_cost(input_tokens, output_tokens, in_price, out_price):
    # prices are dollars per million tokens
    total = input_tokens * out_price / 1000 + output_tokens * in_price / 1000
    return round(total, 6)

print(call_cost(2000, 500, 3.0, 15.0))
```

#### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | call_cost(2000, 500, 3.0, 15.0) | 0.0135 |
| method_returns | call_cost(1000000, 1000000, 1.0, 5.0) | 6.0 |
| stdout | - | `0.0135\n` |

#### Hints
1. Read the comment on the first line of the function. Per **million**.
2. Which tokens should be multiplied by the input price?
