# AI Workflow Fundamentals. Module list is a draft for Kyle to confirm (copy 03).
AI_WORKFLOW_FUNDAMENTALS = {
  slug: "ai-workflow-fundamentals",
  title: "AI Workflow Fundamentals",
  tagline: "Put AI to work on real tasks in your week, safely and repeatably.",
  level: "Beginner, no coding required",
  hours: "about 6 hours, self-paced",
  price_cents: 0,
  position: 1,
  tutor_name: "Ironwood Tech tutor",
  tutor_bio: "You are patient, practical and plain-spoken. You teach busy professionals who are not programmers. " \
             "You favor concrete before-and-after examples from ordinary office work.",
  outcomes: <<~TXT,
    Write prompts that give the same quality of answer every time: role, context, examples and output format.
    Turn a messy task, such as notes, email or a report, into a repeatable AI workflow.
    Check AI output for mistakes before you rely on it.
    Keep private and company data out of tools that shouldn't have it.
    Choose a tool for a job, and know when not to use AI at all.
  TXT
  description: <<~MD,
    ## How it works
    Short lessons, then a hands-on exercise for each one. Your tutor reviews every exercise against a published rubric and tells you exactly what to fix.

    ## What you'll finish with
    One documented workflow you can reuse, plus a certificate of completion. It's not academic credit.

    ## Is this for me?
    Yes, if you use AI tools now and the results feel hit or miss. If you want to build agents in code, take this first, then the Agentic AI Bootcamp.
  MD
  rubric: <<~MD,
    Your tutor reviews each exercise on four things. Each one is either **there** or **not yet**, with one specific fix.

    | Criterion | There | Not yet |
    |---|---|---|
    | **Clear ask** | The prompt states the role, the context, the task and the output format. | The model has to guess what you want or what "good" looks like. |
    | **Repeatable** | Someone else could run your prompt or workflow next week and get the same quality. | It only works with your memory of the conversation. |
    | **Checked** | You show how you verified the output, and you caught at least one error or confirmed there were none. | The output is used as-is. |
    | **Safe** | Only made-up data or your own personal information. No passwords, keys, or employer or client data. | Real company, client or personal data appears. |

    The final project also needs a short write-up: the task, the before and after, how long it took, and what you'd change.
  MD
  lessons: [
    { title: "How AI models actually work, in plain English", body: <<~MD },
      A large language model predicts the next piece of text, over and over, based on patterns in a huge amount of writing. That one idea explains most of what surprises people.

      - **It's fluent, not a database.** It writes what *sounds* right. That's why it can state a wrong fact confidently.
      - **It only knows what's in the conversation.** Each chat starts fresh unless the tool adds memory. Context you leave out simply isn't there.
      - **More context, better answers.** Who it's for, why, what good looks like, and an example all change the result.
      - **It has a knowledge cutoff.** Recent events may be missing unless the tool can search.

      ### Words you'll hear
      *Token*: a chunk of text, roughly ¾ of a word. *Context window*: how much text the model can consider at once. *Hallucination*: a confident answer that isn't true.

      ### Exercise
      Ask any AI tool the same question three ways: with no context, with one sentence of context, and with a full paragraph saying who you are, what you need and what format you want. Paste all three answers to your tutor and say which was best and why.
    MD
    { title: "Prompt design that holds up", body: <<~MD },
      A good prompt has four parts. Use them every time and your results stop feeling random.

      1. **Role:** who the model should act as. *"You are an editor for a busy operations team."*
      2. **Context:** the situation and the audience. *"These notes are from a 30-minute vendor call. The reader is my manager, who wasn't there."*
      3. **Task:** one clear job. *"Write a summary of decisions and open questions."*
      4. **Format:** what the answer should look like. *"Three headings, bullets only, under 150 words."*

      Add an **example** of a good answer when you can. One example often beats a paragraph of instructions.

      ### Before and after
      > Before: "Summarize these notes."
      >
      > After: "You're an editor for an operations team. Summarize these vendor-call notes for my manager, who wasn't on the call. Use three headings (Decisions, Open questions, Next steps), bullets only, under 150 words."

      ### Exercise
      Take a task you do every week. Write a "before" prompt and an "after" prompt using all four parts, run both on **made-up** input, and paste both prompts and results to your tutor.
    MD
    { title: "Workflows: from a one-off chat to a repeatable process", body: <<~MD },
      A workflow is a prompt you can reuse, plus the steps around it. It turns "I asked the AI once" into "this is how we do it."

      ### The workflow card
      Write each workflow as a short card:

      - **Name:** what it does.
      - **When to use it:** the trigger, such as "after every client call."
      - **Input:** what you paste in and where it comes from.
      - **Prompt:** the full prompt, with `[PLACEHOLDERS]` for what changes.
      - **Check:** what you look at before you use the output.
      - **Output:** where the result goes.

      Break big jobs into steps. "Extract the action items" then "draft the follow-up email" works better than one giant prompt.

      ### Exercise
      Write a workflow card for one task from your week. Run it twice on two different made-up inputs and paste the card and both results to your tutor.
    MD
    { title: "Checking the output: errors, made-up facts and how to catch them", body: <<~MD },
      AI output needs a check before anyone relies on it. The check scales with the stakes: a brainstorm needs a glance, a number in a board report needs a source.

      ### What to look for
      - **Made-up facts:** names, dates, numbers, quotes and citations that look real but aren't.
      - **Dropped details:** something important from your input that's missing.
      - **Drift:** the answer quietly changes the question.
      - **Tone:** right facts, wrong voice for the reader.

      ### Simple techniques
      1. Compare against the source, line by line, for anything that matters.
      2. Ask the model to list every factual claim it made, then check that list.
      3. Ask for quotes from your input that support each point.
      4. For numbers, recompute them yourself.

      ### Exercise
      Ask your tutor for this lesson's **Judge it** sample: a short AI-written summary with problems in it. Find as many as you can and explain how you'd catch each one in real work.
    MD
    { title: "Privacy, safety and your company's rules", body: <<~MD },
      The fastest way to get in trouble with AI is to paste the wrong thing into the wrong tool.

      ### Rules of thumb
      - **Know your tool's data policy.** Some consumer tools may use your chats for training unless you turn that off. Business plans usually don't.
      - **Follow your organization's AI policy.** If there isn't one, ask before using AI on work data.
      - **Never paste** passwords, API keys, customer personal data, health or financial records, or anything under NDA.
      - **Use made-up data to practice.** Swap real names, numbers and details for realistic fakes.
      - **Keep a human in the loop** for anything sent to customers, money decisions, or anything about a person.

      ### When not to use AI
      When the cost of a subtle error is high and you can't check the result; when the data isn't yours to share; or when doing it yourself is faster.

      ### Exercise
      Take the workflow card from Lesson 3 and add a **Safety** section: what data it touches, what must be removed or faked first, and who reviews the output. Paste it to your tutor.
    MD
    { title: "Your workflow project", body: <<~MD }
      Put it all together: automate one real task from your week, using made-up data where the real data isn't yours to share.

      ### Deliverables
      1. **The workflow card**, with role, context, task, format, an example, and a safety section.
      2. **Two runs** on different inputs, with the outputs.
      3. **Your check**: what you verified and anything you caught.
      4. **A short write-up**: the task, before and after, time saved (an honest estimate), and what you'd change next.

      Paste your project to your tutor. You'll get a review against the course rubric. Redo any part as often as you like. When you're happy with it, mark this lesson complete to unlock your certificate.
    MD
  ]
}.freeze
