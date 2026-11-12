---
id: ai360-w1-lab
course: AI 360
lesson: 2
title: "Week 1 lab: weather-brief"
professor: Prof. Reyes
minutes: 120
---

## Step: teach
Lab day. By the end you'll have **weather-brief**: a small program that calls a real, free weather API, prints a clean three-day summary, and saves the raw JSON next to it. It becomes the first project in your portfolio repo, `agentic-ai-portfolio`.

The plan: set up a project folder and a virtual environment on your Mac, make one real API call and read the trace, practise the parsing here in the browser, then put it all together in VS Code.

## Step: mac
Make the portfolio folder and this week's project folder inside it, then move into it. `-p` creates any missing parent folders along the way.

### Run
```
mkdir -p ~/code/agentic-ai-portfolio/week-01-weather-brief
```

```
cd ~/code/agentic-ai-portfolio/week-01-weather-brief
```

```
pwd
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `/code/agentic-ai-portfolio/week-01-weather-brief$` |

### Hints
1. Run the three commands in order, in the same Terminal window, and paste what `pwd` prints.
2. If `cd` says "no such file or directory", the `mkdir` line didn't run. Check for typos in the folder names.

## Step: teach
Every Python project you build should get its own **virtual environment** (venv): a private folder of Python packages for that project only. Without one, every project shares one big pile of packages, and upgrading a package for one project can break another.

You create it once with `python3 -m venv .venv`, then **activate** it each time you open a new Terminal window. While it's active, `python` and `pip` mean the copies inside `.venv`.

## Step: mac
Create the venv with your Python 3.11 or newer, activate it, and ask which `python` you're using now and its version. A venv copies the interpreter that created it, so creating it with an old Python would lock this project to that old Python.

### Run
```
python3 -m venv .venv
```

```
source .venv/bin/activate
```

```
which python
```

```
python --version
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `week-01-weather-brief/\.venv/bin/python$` |
| output_matches | - | `^Python 3\.(1[1-9]\|[2-9][0-9])\.` |

### Hints
1. After `source`, your prompt should start with `(.venv)`. If it doesn't, run the `source` line again.
2. Make sure you're still inside `week-01-weather-brief` when you create the venv. Check with `pwd`.
3. If the version is 3.9 or 3.10, the venv was built with an old Python. Run `deactivate`, delete the folder with `rm -rf .venv`, check that `python3 --version` shows Python 3.11 or newer (Lesson 1 covers installing it), and create the venv again.

## Step: quiz
You open a brand-new Terminal window tomorrow and `cd` into this project. What do you need to do before running it?
- [ ] Create the venv again
- [x] Activate it again with `source .venv/bin/activate`
- [ ] Nothing; it stays active forever
> The venv folder stays, but activation only lasts for one Terminal window. Look for `(.venv)` in your prompt.

## Step: teach
Python's standard library can talk to the web, but nearly everyone uses a package called **requests** because it's simpler. You install packages with **pip**, Python's package installer.

Then you write down exactly what you installed in a file called `requirements.txt`, so anyone (including future you) can rebuild the same setup with one command.

## Step: mac
With the venv active, install requests, record it, and show the file.

### Run
```
pip install requests
```

```
pip freeze > requirements.txt
```

```
cat requirements.txt
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `(?i)^requests==\d` |

### Hints
1. If `pip` says "command not found", your venv isn't active. Run the `source` line from the last step.
2. `requirements.txt` will list a few other packages too. requests brings friends. That's normal.

## Step: teach
We'll use **Open-Meteo**, a free public weather API that needs no account or key. Here's what one request looks like, with its query parameters:

```
https://api.open-meteo.com/v1/forecast
  ?latitude=41.88&longitude=-87.63
  &daily=temperature_2m_max,temperature_2m_min
  &temperature_unit=fahrenheit&timezone=auto&forecast_days=3
```

Before writing any program around it, we look at the raw response. Show me the trace.

## Step: mac
Paste this one-liner to make the request and print the status code and the start of the body. You'll write a proper program later. This is just to see the trace.

### Run
```
python -c "import requests; r = requests.get('https://api.open-meteo.com/v1/forecast', params={'latitude': 41.88, 'longitude': -87.63, 'daily': 'temperature_2m_max,temperature_2m_min', 'temperature_unit': 'fahrenheit', 'timezone': 'auto', 'forecast_days': 3}, timeout=10); print(r.status_code); print(r.text[:400])"
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `^200$` |
| output_matches | - | `"daily"` |
| output_matches | - | `temperature_2m_max` |

### Hints
1. Copy the whole line with the copy button. One missing quote breaks it.
2. If you see `ConnectionError` or a timeout, check your Wi-Fi and run it again.
3. Seeing `NotOpenSSLWarning ... LibreSSL` at the top? That means this venv was built with the Mac's old 3.9 Python, whose security library is out of date. It's only a warning, but it means you're on the wrong interpreter. Rebuild the venv with Python 3.11 or newer (see the venv step's hints).

## Step: teach
Read your trace. Inside `"daily"` there are **parallel lists**: `time` holds the dates, `temperature_2m_max` the highs, and `temperature_2m_min` the lows. Item 0 of each list is the same day, item 1 is the next day, and so on.

That's a very common API shape, and Python has a tool built for it: `zip`, which walks several lists side by side. `list(zip([1, 2], ["a", "b"]))` gives `[(1, 'a'), (2, 'b')]`.

## Step: try
mode: python
The browser can't reach the internet, so below is a saved response with made-up numbers in the same shape. Write `daily_rows(data)` that **returns** a list of `(date, high, low)` tuples, one per day.

### Starter
```python
SAMPLE = {
    "daily": {
        "time": ["2026-11-12", "2026-11-13", "2026-11-14"],
        "temperature_2m_max": [51.2, 47.0, 55.8],
        "temperature_2m_min": [38.1, 35.6, 41.3],
    }
}

# Write daily_rows below.
```

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | daily_rows(SAMPLE) | [("2026-11-12", 51.2, 38.1), ("2026-11-13", 47.0, 35.6), ("2026-11-14", 55.8, 41.3)] |
| method_returns | daily_rows({"daily": {"time": ["2026-01-01"], "temperature_2m_max": [20.0], "temperature_2m_min": [9.9]}}) | [("2026-01-01", 20.0, 9.9)] |

### Hints
1. First grab the inner dict: `data["daily"]`. Then grab each of the three lists from it.
2. `zip` the three lists together in the order date, high, low.
3. `zip` gives you something you can loop over, not a list. Wrap it in `list(...)`.

## Step: try
mode: python
Below `daily_rows`, write `format_row(row)` that takes one tuple and **returns** a line like `2026-11-12  high 51F  low 38F` (two spaces between the parts, temperatures rounded to whole numbers).

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | format_row(("2026-11-12", 51.2, 38.1)) | "2026-11-12  high 51F  low 38F" |
| method_returns | format_row(("2026-11-13", 47.0, 35.6)) | "2026-11-13  high 47F  low 36F" |

### Hints
1. You can unpack a tuple straight into names: `date, high, low = row`.
2. An f-string with `round(...)` inside the braces handles the numbers.
3. Count the spaces. The check compares the text exactly.

## Step: try
mode: python
Now write `brief(data, place)` that **returns** the whole report as one string: a first line `Forecast for PLACE`, then one formatted line per day. Use your two functions. Then print `brief(SAMPLE, "Chicago")`.

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | brief(SAMPLE, "Chicago") | "Forecast for Chicago\n2026-11-12  high 51F  low 38F\n2026-11-13  high 47F  low 36F\n2026-11-14  high 56F  low 41F" |
| stdout | - | `Forecast for Chicago\n2026-11-12  high 51F  low 38F\n2026-11-13  high 47F  low 36F\n2026-11-14  high 56F  low 41F\n` |
| source_includes | - | format_row( |

### Hints
1. Build a list of lines: start it with the header, then add one `format_row` result per row from `daily_rows`.
2. `"\n".join(lines)` glues a list of strings together with a new line between each.
3. The returned string has no new line at the end. `print` adds that.

## Step: teach
Real APIs fail. The Wi-Fi drops, the server is busy, or you misspell a parameter and get status 400. Three habits keep your program honest:

- Always pass `timeout=10` to `requests.get`, so a dead server can't hang your program forever.
- Call `r.raise_for_status()`, which raises an error for any status that isn't a success.
- Don't assume a key exists. Read data defensively and fail with a clear message.

In Python you catch errors with `try:` / `except SomeError:`.

## Step: try
mode: python
Write `safe_high(data, i)` that **returns** the high for day `i`, or `None` if the data is missing the key or doesn't have that many days. Use `try` / `except` and catch both `KeyError` and `IndexError`.

### Starter
```python
# Write safe_high below.
```

### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | safe_high({"daily": {"temperature_2m_max": [51.2, 47.0]}}, 1) | 47.0 |
| method_returns | safe_high({"daily": {"temperature_2m_max": [51.2]}}, 5) | None |
| method_returns | safe_high({"error": True, "reason": "bad latitude"}, 0) | None |
| source_includes | - | except |

### Hints
1. Put the risky lookup inside `try:` and return it from there.
2. `except` can catch more than one error type if you group them in parentheses: `except (A, B):`.
3. In the `except` block, return `None`.

## Step: quiz
Why pass `timeout=10` to `requests.get`?
- [ ] It makes the request faster
- [ ] It retries the request 10 times
- [x] It stops waiting after 10 seconds instead of hanging forever
- [ ] It caches the response for 10 seconds
> Without a timeout, a server that never answers can freeze your program. Agents make many network calls, so this habit matters a lot later.

## Step: teach
Time to build the real thing on your Mac. Open the project in VS Code with `code .` (or open the folder from VS Code's File menu) and create `weather_brief.py`. It needs:

1. `fetch(lat, lon)`: calls Open-Meteo with `requests.get`, the params from the trace step, `timeout=10`, then `raise_for_status()`, and returns `r.json()`.
2. Your `daily_rows`, `format_row` and `brief` from today, copied over.
3. At the bottom, inside `if __name__ == "__main__":`, fetch the data, print the brief, and save the raw data to `forecast.json` with `json.dump(data, f, indent=2)`.

Type it yourself. If you get stuck, come back here and re-read the steps above.

## Step: mac
Run your program with the venv active. Paste the full output.

### Run
```
python weather_brief.py
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `^Forecast for ` |
| output_matches | - | `^\d{4}-\d{2}-\d{2}  high -?\d+F  low -?\d+F$` |

### Hints
1. `ModuleNotFoundError: No module named 'requests'` means the venv isn't active in this window.
2. If nothing prints, check that your `print(brief(...))` line is inside the `if __name__ == "__main__":` block and that the block isn't indented under a function.
3. Read the last line of any error first. It names the problem, and the line above it names the file and line number.

## Step: mac
Check that the raw JSON was saved, and peek at the top of it.

### Run
```
ls
```

```
head -8 forecast.json
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `forecast\.json` |
| output_matches | - | `weather_brief\.py` |
| output_matches | - | `"latitude"` |

### Hints
1. If `forecast.json` is missing, the save step didn't run. Use `with open("forecast.json", "w") as f:` and `json.dump` inside that block.
2. Don't forget `import json` at the top of the file.

## Step: teach
A portfolio project isn't done until someone else can run it. Two files make that possible:

- A **README.md** in the project folder: what it does, how to run it (venv, `pip install -r requirements.txt`, `python weather_brief.py`), a sample run pasted in (your trace), what you learned, and known limits.
- A **.gitignore** at the root of the portfolio folder, so the `.venv` folder and secret files never get committed.

Write the README in VS Code now. Keep it short and honest.

## Step: mac
Go up to the portfolio folder, create the `.gitignore`, start a git repo there, and check what git sees.

### Run
```
cd ~/code/agentic-ai-portfolio
```

```
printf ".venv/\n__pycache__/\n.env\n.DS_Store\n" > .gitignore
```

```
git init -b main
```

```
git add . && git status
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `new file:\s+\.gitignore` |
| output_matches | - | `new file:\s+week-01-weather-brief/weather_brief\.py` |
| output_matches | - | `new file:\s+week-01-weather-brief/README\.md` |

### Hints
1. If `.venv` files show up in the list, the `.gitignore` is in the wrong folder. It belongs in `agentic-ai-portfolio`, not in the week folder. Run `git reset`, fix it, then `git add .` again.
2. If `README.md` is missing, save it in VS Code (into `week-01-weather-brief`) and run `git add .` again.

## Step: mac
One more habit before you commit: a **.env file**. It holds settings that belong to your machine and shouldn't go into git: next week's practice values, and from Week 3 your API key. Practise with something harmless now: your forecast location.

Create `.env` in the project folder with your three real settings. Then write `.env.example` **by hand**, with the same names and placeholder values. That file **is** committed, so others know which settings to provide. The rule: **never copy `.env` into it.** From Week 3 your `.env` holds an API key, and a copied example file would push that key to GitHub. Install `python-dotenv`. Then change `weather_brief.py` so it calls `load_dotenv()` at the start of the main block and reads `HOME_LAT`, `HOME_LON` and `PLACE_NAME` with `os.environ.get(...)`, instead of using hard-coded values. Finally, run it and ask git what it's ignoring.

### Run
```
cd ~/code/agentic-ai-portfolio/week-01-weather-brief
```

```
printf "HOME_LAT=41.88\nHOME_LON=-87.63\nPLACE_NAME=Chicago\n" > .env
```

```
printf "HOME_LAT=0.0\nHOME_LON=0.0\nPLACE_NAME=Your town\n" > .env.example
```

```
cat .env.example
```

```
pip install python-dotenv && pip freeze > requirements.txt
```

```
python weather_brief.py
```

```
cd .. && git add . && git status --ignored
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `^HOME_LAT=0\.0$` |
| output_matches | - | `^HOME_LON=0\.0$` |
| output_matches | - | `^PLACE_NAME=Your town$` |
| output_matches | - | `^Forecast for ` |
| output_matches | - | `new file:\s+week-01-weather-brief/\.env\.example` |
| output_matches | - | `^Ignored files:` |
| output_matches | - | `^\s+week-01-weather-brief/\.env$` |

### Hints
1. `ModuleNotFoundError: No module named 'dotenv'` means `python-dotenv` went into a different Python. Is `(.venv)` still in your prompt?
2. `os.environ.get` returns **text**. Latitude and longitude still work as text in the request params, but a number you do math with would need `float(...)`.
3. If `.env` shows up under "Changes to be committed" instead of "Ignored files", your `.gitignore` is missing the `.env` line or is in the wrong folder. Run `git rm --cached week-01-weather-brief/.env`, fix the `.gitignore`, and run the last command again.
4. `.env.example` must show placeholders only: `HOME_LAT=0.0`, `HOME_LON=0.0`, `PLACE_NAME=Your town`. If `cat .env.example` shows your real values, it was copied from `.env`. Write it again by hand with the placeholder line above. Never `cp .env .env.example`.
5. Remember to explain in your README that people should copy `.env.example` to `.env` before running the program.

## Step: mac
Commit your first project and show the log.

### Run
```
git commit -m "Add week 1: weather-brief"
```

```
git log --oneline
```

### Checks
| type | call / input | expected |
|---|---|---|
| output_matches | - | `Add week 1: weather-brief` |

### Hints
1. If git asks who you are, set your name and email with `git config --global user.name "Your Name"` and `git config --global user.email "you@example.com"`, then commit again.

## Step: teach
That's a real project: it calls a live API, handles failure, saves its raw data, and is documented and committed. Your portfolio is local for now. Once your GitHub account is set up, you'll create an empty public repo named `agentic-ai-portfolio` on github.com and push this to it.

Homework is below. Next week: what's actually going on inside a large language model.

## Study guide
- One venv per project: `python3 -m venv .venv` once, then `source .venv/bin/activate` in every new Terminal window.
- `pip install package`, then `pip freeze > requirements.txt` records exactly what you installed.
- Look at the raw API response before writing code around it. Show me the trace.
- Parallel lists line up by index. `zip` walks them side by side.
- `"\n".join(lines)` builds a multi-line string from a list.
- Always pass `timeout=` to network calls and call `raise_for_status()`.
- `try:` / `except (KeyError, IndexError):` turns a crash into a clear fallback.
- `.gitignore` keeps `.venv/` and `.env` out of git. Every project gets a README.
- Machine-specific settings go in `.env` (never committed), read with `load_dotenv()` and `os.environ.get`. Commit a `.env.example` with the same names and placeholder values, written by hand. Never copy `.env` into it.
- The course needs Python 3.11 or newer. Build each venv with it.

## Flashcards
- What's a virtual environment for? :: A private set of packages for one project, so projects don't break each other.
- How do you know your venv is active? :: Your prompt starts with `(.venv)`, and `which python` points inside `.venv`.
- What does `pip freeze > requirements.txt` do? :: Writes the exact installed packages and versions to a file.
- `list(zip([1, 2], ["a", "b"]))`? :: `[(1, 'a'), (2, 'b')]`
- What does `r.raise_for_status()` do? :: Raises an error if the response status isn't a success.
- Why `timeout=10`? :: So a server that never answers can't hang your program forever.
- What goes in `.gitignore` for a Python project? :: `.venv/`, `__pycache__/`, `.env`
- What's `.env.example` for? :: It's committed, and shows which settings `.env` needs, with harmless placeholder values.
- What does `if __name__ == "__main__":` guard? :: Code that should run only when you run the file directly, not when it's imported.

## Homework

### Task
mode: python
Add a weather tip. Write `tip(high, low)` that **returns** `"Bring a jacket"` if the low is below 40, `"Shorts weather"` if the high is 75 or more, and `"Normal day"` otherwise. The jacket rule wins if both are true.

#### Starter
```python
# Write tip below.
```

#### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | tip(51.2, 38.1) | "Bring a jacket" |
| method_returns | tip(80, 61) | "Shorts weather" |
| method_returns | tip(80, 35) | "Bring a jacket" |
| method_returns | tip(60, 45) | "Normal day" |
| method_returns | tip(75, 40) | "Shorts weather" |

#### Hints
1. `if` / `elif` / `else`. Check the rule that should win first.
2. Read the boundaries carefully: "below 40" and "75 or more". Which comparison operators are those?

### Task
mode: python
Write `coldest(data)` that takes the same API shape as `SAMPLE` and **returns** the date with the lowest low.

#### Starter
```python
SAMPLE = {
    "daily": {
        "time": ["2026-11-12", "2026-11-13", "2026-11-14"],
        "temperature_2m_max": [51.2, 47.0, 55.8],
        "temperature_2m_min": [38.1, 35.6, 41.3],
    }
}

# Write coldest below.
```

#### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | coldest(SAMPLE) | "2026-11-13" |
| method_returns | coldest({"daily": {"time": ["a", "b"], "temperature_2m_max": [1, 2], "temperature_2m_min": [5.0, 6.0]}}) | "a" |

#### Hints
1. The lows and the dates line up by index.
2. One way: find the smallest low, then find its index with `.index(...)`, then use that index on the dates.

### Task
mode: python
**Judge it.** This parser is supposed to print each day's high, but it crashes. Run it, read the error's last line, and fix `highs` so the program prints the three highs, one per line.

#### Starter
```python
import json

RAW = '{"daily": {"time": ["2026-11-12", "2026-11-13", "2026-11-14"], "temperature_2m_max": [51.2, 47.0, 55.8]}}'

def highs(raw):
    return raw["daily"]["temperature_2m_max"]

for h in highs(RAW):
    print(h)
```

#### Checks
| type | call / input | expected |
|---|---|---|
| method_returns | highs(RAW) | [51.2, 47.0, 55.8] |
| stdout | - | `51.2\n47.0\n55.8\n` |
| source_includes | - | json.loads |

#### Hints
1. Read the error. What type is `raw` when it arrives in the function?
2. API bodies arrive as text. What turns JSON text into a dict?
