# Week 2 tutor notes: How LLMs work

Portal: **AI 360 Lesson 3** (Week 2: How LLMs work) and **Lesson 4** (Week 2 lab: token-cost-estimator).
No API key this week. Everything runs on plain Python with made-up data and **pretend prices**.
The student can read these notes. They contain no answers.

## Goals: by the end of the week the student can
- Explain next-token prediction in two sentences, without the word "magic"
- Explain what a token is, why rare words cost more, and estimate tokens with the 4-characters rule
- Explain the context window, including that the reply counts and that the model has no memory between calls
- Explain what temperature does to the odds, and when to use low or high
- Calculate the cost of a call from input and output tokens and per-million prices
- Explain why latency grows with output length, and what streaming is for
- Build toy versions of a tokenizer, a temperature adjuster and a sampler, and run a repeatable experiment

## Common mistakes to probe
| Mistake | How it shows up | Question to ask |
|---|---|---|
| "The model looks things up" | Describes an LLM as a search engine or a database | "At each step, what exactly does the model output?" |
| Thinking tokens are words | Counts words to estimate cost | "How might a made-up name with no spaces be split? Try it in your tokenizer." |
| Forgetting the reply uses context | Thinks only the prompt counts | "If the window is full of prompt, where does the answer go?" |
| Thinking the model remembers | Surprised a new call "forgot" | "What do you send on the second call of a chat?" |
| Temperature as a "smartness" dial | "Higher temperature makes it smarter" | "Does temperature change the predicted odds, or how we pick from them?" |
| `max` on a dict | Gets the alphabetically last key | "What does `max` compare when you hand it a dict with no `key=`?" |
| Rounding too early | Probabilities don't add up to 1, or the cost is slightly off | "At which step did you round? What happens if you round before you add up?" |
| Per-thousand vs per-million | Cost is 1,000 times too big | "What unit are the prices quoted in?" |
| Seeding inside the loop | Every pick is the same token | "How many times does your code create the random generator?" |
| Unrepeatable experiment | Different counts every run | "How would someone else get exactly your numbers?" |

## Questions to check understanding
- "Why does the same idea cost a different amount when it's written differently?"
- "You're extracting order numbers from 1,000 made-up notes. Which temperature, and why?"
- "An agent makes 30 calls per task and re-sends the conversation each time. What happens to cost as the task goes on?"
- "Why do output tokens make you wait longer than input tokens?"
- "In your experiment, what changed between t=0.2 and t=2.0, and why?"

## Project: token-cost-estimator
**A good trace** shows the per-model report (one line per model, cost to 6 decimal places) for their own `sample.txt`, and three temperature lines (t=0.2, 1.0 and 2.0) with counts from a seeded experiment.

**A good README** has:
- What it does and why a builder would want it
- How to run it (`python3 token_cost_estimator.py`, with no packages needed)
- The full trace, unedited
- **Three sentences in their own words on what temperature did in their run.** This is the heart of the project: look for sharpening at low t, flattening at high t, and a link back to the math
- Known limits: the 4-characters rule is a rough estimate, the prices are pretend, real tokenizers differ by model, and real temperature works on the model's internal scores

## Review checklist
- [ ] Runs with no packages and no API key
- [ ] `sample.txt` uses made-up text that includes a name and a number
- [ ] `estimate_tokens` rounds up, and `cost` uses per-million prices
- [ ] Probabilities are normalized after the temperature is applied, and rounding happens last
- [ ] The random generator is created once, with a seed, and passed in
- [ ] Functions return values. Only the main block prints
- [ ] The pretend prices are clearly labeled as pretend in the code and the README
- [ ] The README's temperature explanation is in their own words and matches their trace
- [ ] Committed under `week-02-token-cost-estimator/`, with a clear message

## Getting ready for Week 3
Before Week 3, the student needs an API key **with a monthly spend limit already set**, stored in a `.env` file that's in `.gitignore`. Ask them to confirm the limit is set, but never ask to see the key. If they paste one, tell them to revoke it immediately.
