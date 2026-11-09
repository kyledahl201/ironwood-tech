# Agentic AI Bootcamp, 14 weeks (from the AI 360 syllabus; all material original).
BOOTCAMP_WEEKS = [
  [ "Python for AI work",
   "Functions, dicts and lists, JSON, calling a web API with `requests`, virtual environments, `pip`, and keeping keys in a `.env` file.",
   "Set up Python 3 and a virtual environment, write a few functions, fetch a free public API that needs no key, and parse the JSON.",
   "weather-brief", "A command-line tool that fetches a forecast from a free public API and prints a clean summary, plus a saved JSON file." ],
  [ "How LLMs work",
   "Tokens, next-token prediction, the context window, temperature and sampling, pricing per token, and latency.",
   "Count tokens on sample text, run the same prompt at different temperatures and record the differences.",
   "token-cost-estimator", "A script that estimates the cost of a prompt across model sizes, with a short write-up of what temperature does." ],
  [ "Calling a model and designing prompts",
   "Your first call with an official model SDK. Prompt design: role, context, examples, output format, system prompts and iteration.",
   "Make your first API call, then improve one prompt over four versions and compare the results.",
   "notes-cleaner", "Turns messy, made-up job notes into a clean customer summary. The README shows prompt v1 to v4." ],
  [ "Structured output and tool use",
   "JSON schemas, the tool-use loop, and validating the model's arguments before you run anything.",
   "Let the model call your Python functions (`check_calendar`, `book_slot`) on fake data.",
   "booking-assistant", "A command-line assistant that books appointments on a made-up calendar through tool calls and extracts a structured quote from free text." ],
  [ "Memory and conversation state",
   "Message history, context limits, summarizing old turns, and saving state to disk with JSON or SQLite.",
   "Build a chat loop, then add summarization when the history gets long.",
   "study-buddy", "A chat tutor that remembers your progress between runs." ],
  [ "Retrieval (RAG) with cited answers",
   "Chunking, embeddings, vector search, citing sources, and when retrieval fails.",
   "Embed your own notes, search them, and answer questions with citations.",
   "notes-qa", "Ask questions over your own course notes, or a made-up product manual, and get cited answers." ],
  [ "LangChain basics and swapping models",
   "Prompt templates, models, tools, chains, output parsers, and switching models with one line.",
   "Rebuild your Week 4 assistant in LangChain, then swap the model.",
   "model-swap-report", "The same task on two or three models, compared on quality, speed and cost." ],
  [ "A single agent that plans and uses tools",
   "The agent loop (think, act, observe), stop conditions, maximum steps and error recovery. Built from scratch first.",
   "Write an agent loop with no framework, then compare it with a framework version.",
   "research-agent", "Answers multi-step questions using a calculator, your notes search and a public API, and prints its full trace." ],
  [ "LangGraph: state, branches, loops and human approval",
   "State, nodes, edges, conditional branches, loops, checkpoints and human-in-the-loop approval.",
   "Draw the flowchart first, then build it as a graph.",
   "ticket-triage-graph", "Routes made-up customer tickets: classify, draft a reply, escalate, or ask a human to approve." ],
  [ "Multi-agent systems, and when they're overkill",
   "Roles, handoffs, supervisor and peer patterns, reviewer agents, and when one agent is enough.",
   "Build planner, writer and reviewer agents with a revise loop.",
   "study-guide-crew", "Three agents turn a topic into a reviewed study guide, with the reviewer's comments shown." ],
  [ "Testing and evaluating agents",
   "Test sets, code-based checks, model-graded checks, regression runs and tracking failures.",
   "Write a 20-case test set and a grader for your Week 9 or Week 10 project.",
   "agent-evals", "An eval suite with a results table and a \"what broke and why\" section." ],
  [ "Guardrails, prompt injection, privacy and cost limits",
   "Prompt injection, input and output checks, redacting personal data (on fake data), tool permissions, rate and spend limits, and logging.",
   "Attack your own Week 9 agent, then harden it.",
   "hardened-agent", "A before-and-after red-team report with the fixes." ],
  [ "Deploying an agent behind an API",
   "A small API with FastAPI, environment secrets, Docker basics, a cloud free tier, and monitoring cost and errors.",
   "Wrap an earlier agent in an API and deploy it.",
   "live-agent", "Your agent at a public URL, with a short note on cost per request and how you monitor errors." ],
  [ "Capstone: your own multi-agent system",
   "Put it together: a design doc, the build, evals, guardrails and a live deployment.",
   "Write the design doc, build it, test it, harden it and deploy it.",
   "capstone", "A full portfolio write-up: the problem, an architecture diagram, trace examples, eval results, cost per run and what you'd do next." ]
].freeze

AGENTIC_AI_BOOTCAMP = {
  slug: "agentic-ai-bootcamp",
  title: "Agentic AI Bootcamp",
  tagline: "Build, test and deploy AI agents in Python over 14 weeks.",
  level: "Intermediate, basic Python needed",
  hours: "14 weeks, about 6 hours a week (about 84 hours)",
  price_cents: nil, # Kyle sets the price in the owner area; listed as "Price coming soon" until then.
  position: 2,
  tutor_name: "Prof. Tomas Reyes",
  tutor_bio: "You are a builder at heart and a little impatient with hype. Your rule is \"Show me the trace\": " \
             "you won't believe an agent works until you see exactly what the model was sent and what it sent back. " \
             "You make the student type every line themselves and you push for tests and evals.",
  outcomes: <<~TXT,
    Call models from Python with structured output and tool use.
    Give an agent memory and retrieval with cited answers.
    Build single agents from scratch, then with LangChain and LangGraph.
    Design multi-agent systems, and know when they're overkill.
    Test agents with evals, harden them against prompt injection, and set cost limits.
    Deploy an agent behind an API.
  TXT
  description: <<~MD,
    ## "Show me the trace."
    That's Prof. Reyes's rule. He won't believe an agent works until he sees what the model was sent and what it sent back. By the end of this bootcamp, you won't either.

    ## How each week works
    | Part | Time | What happens |
    |---|---|---|
    | Lesson | ~45 min | One idea in plain language, then the real term, then a worked example |
    | Lab | ~2 hrs | You type every line. Your tutor gives one step at a time and waits for your result |
    | Quiz | ~20 min | 5 questions |
    | Judge it | ~15 min | Find what's wrong in a short broken snippet |
    | Project | ~2.5 hrs | A small project for your portfolio, code-reviewed like a real pull request |

    Your tutor reviews each project against the course's published rubric. You can redo any lesson, and the tutor will tell you honestly when work isn't there yet.

    ## What you'll finish with
    A public portfolio of 14 projects, each with a README, a sample trace and what you learned. You'll also get a certificate of completion. It shows what you built. It is not academic credit or a degree.

    ## What it costs to run
    You'll use your own model API key for your projects. Set a monthly spend limit before Week 3. Using the smallest model for labs usually keeps the whole course to a few dollars of API usage. Your actual cost depends on how you use it. The in-site tutor is included.

    ## Is this for me?
    Yes, if you can write a Python function and want to build agents you can test and trust. If you've never coded, start with AI Workflow Fundamentals.
  MD
  rubric: <<~MD,
    Prof. Reyes reviews every weekly project like a pull request, on five criteria. Each is **there** or **not yet**, with the one most useful fix.

    | Criterion | There | Not yet |
    |---|---|---|
    | **It runs** | Clear setup steps; it runs from a fresh clone with only a `.env` file added. | Missing steps, hard-coded paths, or it only runs on your machine. |
    | **Show me the trace** | The README includes a real sample run: what the model was sent and what it sent back. | No trace, or a trace that doesn't match the code. |
    | **Your own code** | You can explain every line, and the commits show the steps. | Pasted code you can't explain. |
    | **Safe** | No keys or secrets committed (`.env` ignored, `.env.example` included). Only made-up data. | A key in the repo or history, or real personal or employer data. |
    | **Honest README** | What it does, how to run it, the sample trace, what you learned, and known limits. | Missing sections, or limits glossed over. |

    From Week 11 on, projects also need **evals**: a test set and a result you report honestly, failures included.
  MD
  lessons: BOOTCAMP_WEEKS.each_with_index.map do |(title, concepts, lab, project, project_desc), i|
    week = i + 1
    {
      title: "Week #{week}: #{title}",
      body: <<~MD
        ## Lesson (about 45 minutes)
        #{concepts}

        Ask Prof. Reyes to walk you through this week's idea: plain language first, then the real term, then one worked example.

        ## Lab (about 2 hours)
        #{lab}

        You type every line. Tell Prof. Reyes you're starting the lab and he'll give you one step at a time, then wait for your pasted result. Hints first; ask for the answer only after you've tried.

        ## Quiz (about 20 minutes)
        When the lab is done, press **Quiz me**. You'll get 5 questions on this week, one at a time.

        ## Judge it (about 15 minutes)
        Press **Judge it** for a short broken snippet. Find what's wrong and say how you'd fix it.

        ## Project: `week-#{week.to_s.rjust(2, '0')}-#{project}` (about 2.5 hours)
        #{project_desc}

        Push it to your portfolio repo with its own README: what it does, how to run it, a sample trace, what you learned, and known limits. Keep keys in `.env` (never committed) and ship a `.env.example`. Paste the README and your key code to Prof. Reyes for a review against the rubric, then mark this week complete.
      MD
    }
  end
}.freeze
