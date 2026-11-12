# AI 360: grading rubric

## Weekly grade
| Part | Weight | Who records it |
|---|---|---|
| Portfolio project | 40% | Your tutor's review, against the table below |
| Lab | 25% | Portal checks (all steps passed = full marks) |
| Quiz | 20% | Portal |
| Judge it (homework) | 15% | Portal checks |

Letter grades: **A** 90 and up · **B** 80 to 89 · **C** 70 to 79 · **D** 60 to 69 · **F** below 60.
A week below **C** is redone before you move on. You can redo any lesson or project as many times as you like, and the latest attempt counts.

## Project rubric (100 points)
| Area | Points | A-level work | What loses points |
|---|---|---|---|
| **Works** | 25 | Runs from a fresh clone by following the README. Does what the week asks | Crashes on the happy path, missing steps, needs fixes to run |
| **Handles failure** | 15 | Timeouts on network calls, clear messages for bad input or a failed API, no silent wrong answers | Crashes on bad input, swallows errors silently, hangs |
| **Code quality** | 15 | Small functions that return values, clear names, no copy-pasted blocks, idiomatic Python | Everything in one block, printing inside helper functions, confusing names |
| **Trace and evidence** | 15 | The README shows a real sample run, and from Week 3 on, what was sent to the model and what came back | No sample output, or output that doesn't match the code |
| **README** | 15 | What it does, how to run it, sample trace, what you learned (in your own words), known limits | Missing sections, vague "it works" claims |
| **Safety and hygiene** | 10 | No secrets committed, `.env.example` where keys are needed, `.gitignore` correct, made-up data only | A key in git or the README, real personal or employer data, `.venv` committed |
| **Cost awareness** | 5 | From Week 3 on: small model by default, a rough cost per run noted. Weeks 1 and 2: the estimate is explained | No idea what a run costs |

**Automatic stops** (the project can't pass until fixed): a committed API key, any real employer or client data, or code the student didn't write.

## How your tutor writes a review
1. What works, specifically.
2. What's wrong, pointing at lines (not rewriting them).
3. What isn't idiomatic.
4. What's untested, or would break in production.
5. A score for each rubric area with a one-line reason, the total, and the letter grade.
6. The single most important thing to fix first.
