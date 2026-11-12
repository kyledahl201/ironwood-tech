# Week 1 tutor notes: Python for AI work

Portal: **AI 360 Lesson 1** (Week 1: Python for AI work) and **Lesson 2** (Week 1 lab: weather-brief).
The student can read these notes. They contain no answers, only what to teach, look for and ask.

## Goals: by the end of the week the student can
- Build and read dicts, and choose between `d["key"]` and `d.get("key")`
- Write functions that **return** values instead of printing them
- Use f-strings with expressions inside
- Turn JSON text into Python data and back, and explain which direction each function goes
- Explain what an API, a query parameter and a status code are
- Install Python 3.11 or newer, then create and activate a virtual environment with it, install a package, and record it in `requirements.txt`
- Keep machine settings in a `.env` file that git ignores, and read them with `python-dotenv`
- Call a real API from Python with a timeout, check the status, and save the raw JSON
- Commit a documented project to their portfolio repo

## Before they start
- First, probe the install path. Ask for the output of `python3 --version` and `which python3` on their Mac. They need **Python 3.11 or newer**. `/usr/bin/python3` is the Mac's built-in 3.9, which is past end of life. To install a current one, Lesson 1 gives three ways: `mise use -g python@3.12` (if they did CS 090), `brew install python`, or the python.org installer followed by its Install Certificates step. Then they open a new Terminal window. If macOS offers to install command line developer tools, that's expected.
- Ask about their Python background and adjust the pace. Week 1 is a refresher. If they can't yet write a function, tell them honestly that a beginner Python course should come first.

## Common mistakes to probe
| Mistake | How it shows up | Question to ask instead of fixing it |
|---|---|---|
| Printing instead of returning | Output shows `None`, or a value appears on its own line before the real output | "What does a Python function hand back when there's no `return` line?" |
| Using a global instead of the parameter | A function passes the sample but fails the other checks | "Which variable does your function actually read: the one passed in, or the one at the top of the file?" |
| Float surprises | A percent comes out as `30.000000000000004` | "Try `0.3 * 100` in the console. What do you see, and which built-in tidies it?" |
| `loads` vs `dumps` mix-up | `TypeError: string indices must be integers`, or a dict where text was expected | "Is `raw` text or a dict right now? Print `type(raw)`." |
| JSON vs Python spellings | Expecting `true` or `null` in Python | "Load it and look at the trace. What did `null` become?" |
| Still on the Mac's built-in Python | `python3 --version` shows 3.9, or `which python3` shows `/usr/bin/python3` after installing | "Did you open a new Terminal window after installing? What does `which python3` say now?" |
| Venv built with the old Python | `NotOpenSSLWarning ... LibreSSL` at the top of the first API trace, or `python --version` inside the venv shows 3.9 | "Which Python created this venv? What does `python --version` say with `(.venv)` active?" (They delete and rebuild the venv with Python 3.11 or newer. The warning is harmless, but it means they're on the wrong interpreter.) |
| `.env` committed or not loaded | `.env` listed under changes to commit, or settings come back as `None` | "What does `git status --ignored` list? Where does `load_dotenv()` look for the file?" |
| `.env` copied into `.env.example` | `.env.example` shows real values (their own latitude or town) instead of placeholders, or they mention `cp .env .env.example` | "Which of those two files goes to GitHub? What will be in your `.env` from Week 3?" (They rewrite `.env.example` by hand with placeholders. Real values never go in it.) |
| Venv not active | `ModuleNotFoundError: No module named 'requests'`, or `pip: command not found` | "Does your prompt start with `(.venv)`? What does `which python` say?" |
| Venv created in the wrong folder | `.venv` appears in `git status` | "Where is your `.gitignore`, and where is your `.venv`? Run `pwd` in each." |
| No timeout | The program hangs on bad Wi-Fi | "What happens if the server never answers? How long would you wait?" |
| Off-by-one on lists | Picking the wrong day | "What index is the first item?" |
| Not reading the error | Pastes a full error and says "it's broken" | "Read me just the last line. What does it name? Now the line above it: which file and line?" |

## Questions to check understanding
- "Why does each project get its own venv?"
- "Your function printed the right number, but the check failed. Why might that be?"
- "In the API response, how do you know which high goes with which date?"
- "What's the difference between status 200 and status 404? Which one does `raise_for_status()` turn into an error?"
- "Why save the raw JSON as well as the summary?"

## Project: weather-brief
**A good trace** (pasted in the README) shows the command they ran, the header line, one line per day with date, high and low, and evidence that `forecast.json` was saved, for example a few lines of `head forecast.json`.

**A good README** has:
- What it does, in one or two sentences
- How to run it from a fresh clone: create and activate a venv, `pip install -r requirements.txt`, run the script
- The sample trace above, real and unedited
- What they learned, in their own words (look for venvs, JSON, parallel lists, and why timeouts matter)
- Known limits (for example: fixed coordinates, Fahrenheit only, no retry on failure)

## Review checklist
- [ ] Runs from a fresh clone by following the README
- [ ] Network call has a timeout and checks the status
- [ ] Helper functions return values. Printing happens only in the main block
- [ ] Parsing is separate from fetching, so it could be tested without the internet
- [ ] Handles a missing key or a failed request with a clear message, not a raw crash
- [ ] Main code sits inside `if __name__ == "__main__":`
- [ ] `requirements.txt` is present. `.venv/` and `.env` are git-ignored, and `.env.example` is committed
- [ ] Location settings come from `.env` through `os.environ.get`, not hard-coded
- [ ] Built and run on Python 3.11 or newer
- [ ] README has all five sections and a real trace
- [ ] Clear commit message, and no stray files (`.DS_Store`, `__pycache__`)

## Stretch ideas (only once the base project is graded)
- Take the place name as a command-line argument
- Add the daily rain chance and a tip line
- Retry once on a timeout before giving up
