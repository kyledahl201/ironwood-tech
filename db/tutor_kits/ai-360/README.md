# Agentic AI Bootcamp: tutor kit

This kit turns your own Claude project into Prof. Reyes, the bootcamp's AI tutor. The lessons, labs and auto-checks live on the Ironwood portal. Your tutor lives in Claude: it coaches you one step at a time, answers questions, and reviews your projects against the rubric.

Prof. Reyes is an AI tutor persona, not a real person. Ironwood Tech is a self-directed curriculum, not an accredited school, and the certificate isn't academic credit.

## What you need
- **A MacBook.** The labs use the Mac's Terminal and VS Code, with Python 3.11 or newer (Week 1 shows you how to install it if your Mac has an older one).
- **A Claude Pro account** (or any plan that includes Projects).
- **From Week 3 on: a model API key** with a monthly spend limit set before you make your first call. With the smallest model, the whole course usually costs a few dollars of API usage. Weeks 1 and 2 need no key.
- About 6 hours a week.

## Set up your tutor (10 minutes)
1. Download the kit from the portal and unzip it. You'll have these files:
   `README.md`, `PROJECT-INSTRUCTIONS.md`, `SYLLABUS.md`, `RUBRIC.md`, `WEEK-01.md`, `WEEK-02.md`, `PROGRESS.md`
2. Open claude.ai, go to **Projects**, and create a new project. Name it something like `Agentic AI Bootcamp`.
3. Open the project's **instructions** (sometimes labeled "Set project instructions"). Open `PROJECT-INSTRUCTIONS.md` in any text editor, copy everything, and paste it in. Save.
4. Add these files to the project's **knowledge** (the files area): `SYLLABUS.md`, `RUBRIC.md`, `WEEK-01.md`, `WEEK-02.md`, `PROGRESS.md`. You don't need to add this README.
5. Start a new chat inside the project and say:
   > Hi Prof. Reyes. I'm starting Week 1. My name is ___ and my Python experience is ___.

   He'll introduce himself, check your setup, and point you to the first portal lesson.

## How a week goes
1. Do the lesson and lab on the portal. The portal's checks are your official record.
2. Stuck on a step? Press **Copy for my tutor** on the portal and paste it into your Claude project chat. Prof. Reyes sees the course, the lesson, the task, your code, your output and which checks pass, and gives you a hint, not the answer.
3. When your project is pushed, paste your README and code (or the repo link, if your plan can read links) and ask for a review. You'll get an honest A to F grade with reasons.
4. At the end of each session, ask for a **progress note**. Paste it at the bottom of your `PROGRESS.md`, then re-upload the file to the project's knowledge, replacing the old one. That's how your tutor remembers where you are next time.

## New weeks
Each time a new week opens, download its `WEEK-NN.md` tutor notes from the portal and add them to the project's knowledge.

## Ground rules you agree to
- Made-up data and your own personal projects only. Never paste code, data, screenshots or documents from an employer or client.
- Never paste an API key into the chat. Keys belong in a `.env` file that's never committed.
- You write your own code. Your tutor won't write your labs or projects for you, and that's on purpose.
