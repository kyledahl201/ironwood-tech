# AI 360: Agentic AI Bootcamp: syllabus

**Tutor:** Prof. Tomas Reyes (an AI tutor persona) · **Length:** 14 weeks, about 6 hours a week · **Language:** Python
**Prerequisite:** You can write a basic Python function. Week 1 is a refresher, not a first course.
Ironwood Tech is a self-directed curriculum, not an accredited school. The certificate shows what you built. It isn't academic credit.

## Each week
| Part | Time | What happens |
|---|---|---|
| Lesson | ~45 min | On the portal: one idea in plain words, then the real term, then you try it |
| Lab | ~2 hrs | On the portal and your Mac: you type every line, one step at a time |
| Quiz | ~20 min | 5 questions across the lesson and lab |
| Judge it | ~15 min | Find and fix the bug in a short broken snippet (homework) |
| Project | ~2.5 hrs | A small portfolio project with a README, reviewed by your tutor |

Grading is in `RUBRIC.md`.

## Materials
- A MacBook with Terminal and VS Code
- Claude Pro (for your tutor project)
- From Week 3: a model API key with a monthly spend limit. Using the smallest model for labs usually keeps the whole course to a few dollars.
- A free GitHub account for your public portfolio repo, `agentic-ai-portfolio`

## The 14 weeks
| Wk | Topic | You'll learn | Portfolio project |
|---|---|---|---|
| 1 | Python for AI work | Dicts, functions that return, f-strings, JSON in and out, calling a web API, virtual environments, pip, error handling | **weather-brief**: calls a free weather API, prints a 3-day summary, saves the raw JSON |
| 2 | How LLMs work | Tokens, next-token prediction, context windows, temperature and sampling, cost per token, latency | **token-cost-estimator**: estimates tokens and cost across model sizes, plus a temperature experiment |
| 3 | Calling a model, and prompt design | Your first API call with the Anthropic SDK, system prompts, roles, examples, output format, iterating on a prompt | **job-notes-cleaner**: turns messy made-up job notes into a clean summary, with prompt v1 to v4 in the README |
| 4 | Structured output and tool use | JSON schemas, the tool-use loop, validating what the model asks for | **booking-assistant**: books appointments on a made-up calendar through tool calls |
| 5 | Memory and conversation state | Message history, context limits, summarizing old turns, saving state to disk | **study-buddy**: a chat tutor that remembers your progress between runs |
| 6 | Retrieval (RAG) | Chunking, embeddings, vector search, citing sources, when retrieval fails | **notes-qa**: answers questions over your own notes, with citations |
| 7 | LangChain basics | Prompt templates, models, tools, chains, output parsers, swapping models | **model-swap-report**: one task on two or three models, compared on quality, speed and cost |
| 8 | A single agent | The agent loop (think, act, observe), stop conditions, step limits, error recovery. Built from scratch first | **research-agent**: answers multi-step questions with tools and prints its full trace |
| 9 | LangGraph | State, nodes, edges, branches, loops, checkpoints, human approval | **ticket-triage-graph**: routes made-up support tickets, with a human approval step |
| 10 | Multi-agent systems | Roles, handoffs, supervisor vs peer patterns, a reviewer agent, when it's overkill | **study-guide-crew**: planner, writer and reviewer agents build a reviewed study guide |
| 11 | Testing and evaluating agents | Test sets, code-based checks, LLM-as-judge, regression runs | **agent-evals**: an eval suite with a results table and a "what broke and why" section |
| 12 | Guardrails, safety, privacy and cost | Prompt injection, input and output checks, redacting personal data, tool permissions, spend limits, logging | **hardened-agent**: a before-and-after red-team report on your Week 9 agent |
| 13 | Deploying an agent | A small API (FastAPI), secrets in production, Docker basics, a cloud free tier, watching cost and errors | **live-agent**: an earlier agent at a public URL |
| 14 | Capstone | Design doc, build, evals, guardrails, deploy, write-up | **capstone**: a multi-agent system of your choice, written up as a portfolio piece |

## Your portfolio repo
```
agentic-ai-portfolio/
  README.md          # who you are, plus a table of projects with one-line summaries
  .gitignore         # .venv/  __pycache__/  .env
  week-01-weather-brief/
    README.md        # what it does, how to run it, a sample trace, what you learned, known limits
    ...
  week-14-capstone/
```
Rules: made-up data only, no secrets in git, one clear commit per meaningful step.
