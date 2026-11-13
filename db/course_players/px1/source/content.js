/* PX1 course content. Everything here is made up for practice: the Lindgrens,
   Cedar Hollow, every schedule, meal, price and budget. Draft 1, 2026-11-12.
   Lessons: Tomas Reyes (AI persona). Cold opens: Walt Pruitt (AI persona). */
window.COURSE = {
  title: "Life and Work, With Claude: AI 101",
  folder: "lindgren-home",
  promise: "In one weekend (about seven hours, in two sittings), set up Claude on your Mac, hire a family team of AI helpers, plan a real week, and build your own family hub app. No coding experience needed.",
  lessons: [
  {
    id: "welcome", n: 0, title: "Welcome: tour the finished hub", mins: 10,
    leave: "A clear picture of Sunday night, and the plan for your weekend.",
    walt: "Every family already has a chief of staff. It is whoever remembers the swim bag. This weekend, that person gets a team.",
    idea: { title: "Four things by Sunday night", svg: "weekend",
      text: "You will set up Claude, hire a family team, plan a real week, and build a family hub app. You do it first for the Lindgrens, a made-up family, because practice data can't embarrass anyone. Then you do it for your own home." },
    steps: [
      { k: "do", text: "Play with the finished Lindgren hub below. Find Tuesday. Why is it outlined? Then tap a dinner to open its recipe, and check one thing off the shopping list.", demo: "hub" },
      { k: "do", text: "Check what you need: a Mac, about seven hours (two sittings work best) and a paid Claude plan. Lessons 3 to 12 use Cowork and the Code tab, which are not on the free plan. As of November 2026, Pro is about $20 a month. Confirm today's price at claude.com/pricing before you buy. So the course plus one month of Pro is about $49." },
      { k: "note", text: "Be clear on the limit from the start: this hub lives on your Mac. Getting it onto everyone's phone, each with their own login, is the next course. Lesson 12 shows you that door." }
    ],
    check: "You know why Tuesday is outlined (soccer runs until 6:30, so it's a busy night), and you know which plan you need.",
    breaks: [],
    edge: { title: "The weekly review", body: "One habit many calm households share isn't a better app. It's fifteen minutes on Sunday looking at the week as a whole: who is where, what's for dinner, what money is going out. Productivity writers call this the weekly review. The hub you build is just a weekly review you can see. Claude does the gathering; you do the deciding.", try: "Before lesson 1, write down the three things that most often go wrong in your week. Missed pickups? Takeout on busy nights? Surprise bills? You'll aim your team at them." },
    quiz: [
      { q: "Why do you build the Lindgren hub before your own?", o: ["The Lindgren hub is the one you hand in", "Practice data is safe to make mistakes with", "Claude needs a demo before it works"], a: 1, why: "The Lindgrens are made up, so nothing you break matters and none of your family's details are exposed while you learn." },
      { q: "Where does the hub live when you finish this course?", o: ["On your Mac", "On everyone's phone with logins", "In iCloud"], a: 0, why: "It's a folder on your Mac. Phones and logins are the next course." }
    ]
  },
  {
    id: "setup", n: 1, title: "Set up Claude on your Mac", mins: 25,
    leave: "The Claude app, a paid plan, sensible privacy settings and the talk-back habit.",
    walt: "Most people's first AI conversation goes like their first conversation with a new neighbor. Polite, vague and over in a minute. Let's skip to the part where you borrow the ladder.",
    idea: { title: "Context in, useful out", svg: "context",
      text: "Claude knows a lot about the world and nothing about your house. The more you say about who you are and what you want, the better it does. Say it once, plainly, and push back when it misses." },
    steps: [
      { k: "do", text: "Download the Claude app for Mac from claude.com/download, open it and sign in. Choose a paid plan (Pro is enough for this course).", cos: "Download page, sign-in screen and plan picker" },
      { k: "do", text: "Open <b>Settings, then Privacy</b>. Read what each setting does, and choose whether your chats may be used to improve models. Either answer is fine for this course; the point is that you chose.", cos: "Privacy settings names" },
      { k: "type", text: "Ask something vague first, to see the difference context makes:", prompt: "What can you do to help a family?" },
      { k: "type", text: "Now give it context:", prompt: "I'm a parent of two kids, 11 and 7. Weeknights are chaos: soccer, swim and piano, and we end up with takeout twice a week. Give me three ideas for making weeknight dinners easier. Short bullets, no recipes yet." },
      { k: "tool", text: "Practice the shape with the prompt builder. Fill in the boxes and watch the prompt build itself.", tool: "builder" },
      { k: "type", text: "Then talk back. This is the habit that matters most:", prompt: "Too generic. We have 30 minutes on Tuesdays and Thursdays and one kid won't eat mushrooms. Try again for that." }
    ],
    check: "Claude's second answer fits your made-up week much better than its first, and you pushed back at least once.",
    breaks: [
      ["I can't find Cowork or the Code tab.", "Check you're on a paid plan and the latest app version (Claude menu, Check for Updates). Some features are still rolling out; lesson 8 has a fallback."],
      ["The answer is too long.", "Say so: \"Shorter. Three bullets.\" Claude doesn't mind."]
    ],
    edge: { title: "Decide ahead", body: "By dinnertime most parents have made hundreds of small decisions, and many people find they start choosing whatever is easiest: takeout, screens, yes. Psychologists call it decision fatigue; the research on it is mixed, but deciding ahead still helps. The fix isn't willpower; it's deciding ahead, when you're fresh. Every helper you hire this weekend moves a decision from 5:30 PM on Tuesday to Sunday night.", try: "Name one decision you make every single weekday (what's for dinner, who drives) and decide it for next Tuesday right now." },
    quiz: [
      { q: "Claude gives a generic answer. The best next move is:", o: ["Start a new chat", "Tell it what was wrong and add context", "Accept it; that's what AI does"], a: 1, why: "Talking back with specifics is the fastest way to a useful answer." },
      { q: "Which prompt will get the most useful answer?", o: ["Help with dinner", "Give me dinner ideas", "Two kids, 30 minutes on Tuesdays, no mushrooms: three dinner ideas"], a: 2, why: "It says who, what, and the limits." }
    ]
  },
  {
    id: "project", n: 2, title: "A Project for quick questions", mins: 20,
    leave: "A Home HQ Project with instructions, and a clear rule for when to use a Project and when to use a folder.",
    walt: "You have now explained your family to Claude twice. A third time and you'll start to sound like a holiday letter.",
    idea: { title: "A Project remembers who you are", svg: "project",
      text: "A Project is a saved space with standing instructions and a few reference files. Every chat inside it starts already knowing the basics. It's for quick questions from your phone or laptop. Real work on real files happens in a folder, starting next lesson." },
    steps: [
      { k: "do", text: "In the sidebar, choose <b>Projects</b>, then <b>New project</b>. Name it <b>Home HQ (practice)</b>.", cos: "Projects sidebar and New project button" },
      { k: "type", text: "Paste these instructions into the Project's instructions box:", prompt: "We are the Lindgrens, a made-up practice family: Sam and Jordan, Ava (11), Milo (7) and Biscuit the dog. Weeknight dinners must be under 30 minutes. Ava loves spicy food and hates mushrooms. Milo's school lunches must be nut-free. Thursday is leftover night. Keep answers short and in plain words." },
      { k: "type", text: "Start a chat inside the Project and ask:", prompt: "What's a good dinner for Thursday?" },
      { k: "note", text: "Claude should say leftovers, because the instructions say Thursday is leftover night. You didn't repeat it. That's the point of a Project." },
      { k: "do", text: "Open the Claude app on your iPhone (optional) and find the same Project. Quick questions on the go live here." }
    ],
    check: "A new chat in the Project answers \"leftovers\" for Thursday without you mentioning it.",
    breaks: [
      ["Claude ignored the instructions.", "Check you started the chat inside the Project, not a plain chat. The Project name shows at the top."]
    ],
    edge: { title: "Write it down once", body: "Families run on unwritten rules: who walks the dog, when screens go off, which kid gets the front seat. Unwritten rules cause a lot of household arguments, because everyone remembers a slightly different version. Writing them down once, for Claude, has a side effect: now your family has them written down too.", try: "Write three of your own family's unwritten rules in one sentence each. Keep them; you'll use them in lesson 11." },
    quiz: [
      { q: "When do you use a Project instead of a folder?", o: ["For quick questions that need the same background", "For building the hub app", "Never; folders replace Projects"], a: 0, why: "Projects are for quick questions with standing context. Folders are for work on real files." },
      { q: "What should never go into Project instructions?", o: ["Dinner rules", "Kids' first names", "Your bank password"], a: 2, why: "Passwords, account numbers and medical records never go into Claude." }
    ]
  },
  {
    id: "house", n: 3, title: "Your house file and the \"never put in\" list", mins: 30,
    leave: "Claude working inside the Lindgren folder, reading the house file every time, with safety rules it follows.",
    walt: "Until now Claude has been giving you advice. Advice is free and mostly ignored. Today it starts doing the work.",
    idea: { title: "A Project is a room you visit. A folder is a workshop.", svg: "folder",
      text: "With Cowork, you let Claude into one folder on your Mac, where it can read, make and change real files. A house file called CLAUDE.md tells it how your family works and what must never go in." },
    steps: [
      { k: "do", text: "Download the practice folder from the course page and unzip it. Move <b>lindgren-home</b> into your Documents folder." },
      { k: "do", text: "In the Claude app, choose <b>Cowork</b> in the message box. Then choose a folder and pick <b>lindgren-home</b> itself, not the folder above it.", cos: "Cowork mode and folder picker" },
      { k: "note", text: "Claude asks before it changes things. Read each request. Say yes for this folder only. This is the one safety habit to keep forever." },
      { k: "type", text: "This is your <b>start line</b>. Paste it as the first message of every new Cowork task in this folder:", prompt: "Before you do anything in this folder, read CLAUDE.md and follow it.", cos: "Whether Cowork reads CLAUDE.md on its own, or has a folder-instructions setting" },
      { k: "type", text: "Look around without touching anything:", prompt: "Tell me what is in this folder, in plain words. Do not change anything." },
      { k: "do", text: "Open <b>CLAUDE.md</b> in TextEdit (right-click, Open With, TextEdit) and read the <b>Never put in</b> list. Passwords, account numbers, SSNs, medical records, and kids' full names, schools, addresses or photos." },
      { k: "type", text: "Test the rule. Claude should refuse to save this and explain why:", prompt: "Save Milo's school name and our home address in a new file called contacts.md." },
      { k: "type", text: "Now add a house rule of your own:", prompt: "Add a line to the house rules in CLAUDE.md: \"Screens off at dinner. Suggest a table question for the kids with each dinner plan.\"" }
    ],
    check: "Claude refused the school-and-address request, pointed to the Never put in list, and your new house rule is in CLAUDE.md.",
    breaks: [
      ["Claude says it can't see the folder.", "You picked the folder above it. Choose again and pick lindgren-home itself."],
      ["Claude saved the address anyway.", "Tell it: \"Read the Never put in list in CLAUDE.md and undo that.\" Then check the start line is the first message of each task."],
      ["Claude asks to do something you don't understand.", "Say no. Then ask: \"Explain what you wanted to do and why, in plain words.\""]
    ],
    edge: { title: "Give keys, not the house", body: "You wouldn't hand a new babysitter the keys to every room and the safe. Give Claude the same treatment: one folder, the one it needs, and read what it asks before you say yes. Security people call this least privilege. At home it means one habit: keep your family's AI work in its own folder, and keep the sensitive stuff out of it entirely.", try: "Look at where your family's documents live now. Are tax returns sitting next to the soccer schedule? Plan a separate my-home folder that holds only what a helper should see." },
    quiz: [
      { q: "What's the difference between a Project and a folder in Cowork?", o: ["None", "A Project holds copies; in a folder Claude works on real files", "A Project can change files on your Mac"], a: 1, why: "In a folder, Claude can make and change the actual files on your Mac." },
      { q: "Claude asks to change a file outside lindgren-home. You should:", o: ["Say yes if it looks small", "Say no and ask it to explain", "Say yes once and check later"], a: 1, why: "Yes only inside your folder, and only when you understand the request." },
      { q: "Which of these is allowed in the hub?", o: ["Ava, soccer, Tuesday 5 PM", "Ava's school and teacher", "The family credit card number"], a: 0, why: "First name, activity and time only." }
    ]
  },
  {
    id: "team", n: 4, title: "Hire the family team", mins: 40,
    leave: "A Family CEO, CFO, Health and Fitness Coach, Home helper and Critic, and a first weekly review that went through all of them.",
    walt: "You are about to manage five new staff. They work Sundays, they never ask for the car, and one of them exists only to tell the others they're wrong. So, a normal family.",
    idea: { title: "Everyone has one job. Someone checks.", svg: "team",
      text: "One helper that plans meals, does the budget and grades its own work will tell you its work is great. Split the jobs. Write each one down as a plain job file, with its limits inside it. Then hire a Critic who never fixes its own findings." },
    steps: [
      { k: "start", text: "" },
      { k: "do", text: "Open the <b>helpers</b> folder in Finder. Read <b>ceo.md</b> and <b>critic.md</b>. Notice the <b>Limits</b> section in each file: the rules travel with the helper." },
      { k: "type", text: "Meet the team:", prompt: "Read every file in helpers/. In a short table, tell me each helper's job and its limits, in plain words." },
      { k: "type", text: "Give the CEO its first job:", prompt: "Work as the Family CEO from helpers/ceo.md. Read the calendar and tell me which nights next week are busy, and why. The week is Sunday, Nov 15 to Saturday, Nov 21, 2026." },
      { k: "quiz1", text: "Before Claude answers, work it out yourself from the hub in lesson 0. How many busy nights does the Lindgren week have?", answer: 2, unit: "", hint: "Tuesday (soccer until 6:30) and Thursday (soccer, and Jordan works until 7). The rule in ceo.md: A busy night is an evening (from 4 PM on) with two or more things, or one thing that ends at 6:30 PM or later." },
      { k: "type", text: "Now test a limit. The Coach should decline and say why:", prompt: "Work as the Coach. Milo should lose five pounds. Make him a diet." },
      { k: "type", text: "Write a sixth helper yourself, with limits:", prompt: "Write a new helper file, helpers/pet.md, for Biscuit's care: walks, food every other week, vet visits. Follow the same layout as the other helper files, including a Limits section." },
      { k: "type", text: "Then have the Critic check it:", prompt: "Have the Critic check helpers/pet.md against the other helper files. Score it out of 10 and list fixes." }
    ],
    check: "The CEO found two busy nights, the Coach refused the diet request, and the Critic scored your new pet helper.",
    breaks: [
      ["The Critic gives everything a 10.", "Ask: \"Be stricter. What would make Ava confused?\" Then check critic.md says it never fixes its own findings."],
      ["Claude blends all the helpers together.", "Name one helper per message: \"Work as the CFO from helpers/cfo.md.\""]
    ],
    edge: { title: "Delegating at home", body: "Most households don't have a work problem; they have a delegation problem. One person holds the whole week in their head, and everyone else waits to be told. Good delegation names three things: the outcome, the limits, and how you'll check it. Your helper files are practice at exactly that, and the same three things work on a teenager.", try: "Pick one recurring family job and write it like a helper file: outcome, limits, how you'll check. Hand it to a person this week." },
    quiz: [
      { q: "Why does the Critic never fix its own findings?", o: ["It's not allowed to edit files", "A checker that fixes its own work stops being a checker", "It's slower"], a: 1, why: "Separating making from checking is what makes the check honest." },
      { q: "Where do a helper's limits belong?", o: ["In your head", "Inside its job file", "In a separate rules folder"], a: 1, why: "Rules in the file travel with the helper and are followed every time." }
    ]
  },
  {
    id: "week", n: 5, title: "Plan a week: meals, recipes, shopping, activity", mins: 35,
    leave: "A full weekly plan with dinners, recipes, a shopping list by store section and one family activity.",
    walt: "At 5:30 on a Tuesday, the question \"what's for dinner\" has ended more marriages than money. Tonight we answer it on Sunday.",
    idea: { title: "The Sunday review", svg: "week",
      text: "The CEO reads the calendar. The Coach plans dinners around busy nights. Home builds the list minus the pantry. The CFO checks the money. The Critic checks it all. One sentence starts the whole chain, because it's written in the house file." },
    steps: [
      { k: "start", text: "" },
      { k: "type", text: "Run the whole review with one sentence:", prompt: "Run the Sunday review for the week of Sunday, Nov 15, 2026." },
      { k: "do", text: "Watch the helpers take turns. When it finishes, open <b>plans/week-of-2026-11-15.md</b> in TextEdit." },
      { k: "do", text: "Check it against the hub from lesson 0. Is Tuesday a slow-cooker night? Is Thursday leftovers? Are black beans left off the list (they're in the pantry)?" },
      { k: "type", text: "Change your mind like a real family does:", prompt: "Swap Wednesday's dinner for something without fish; Sam's out that night. Update the plan and the shopping list." },
      { k: "type", text: "Get a list you can actually shop from:", prompt: "Give me just the shopping list, grouped by store section, with checkboxes, ready to print." }
    ],
    check: "Your plan has seven dinners, Thursday is leftovers, black beans aren't on the list, and the Wednesday swap updated the list too.",
    breaks: [
      ["Claude only planned five days.", "Say: \"All seven days, Sunday to Saturday.\" Then add that to the Sunday review section of CLAUDE.md."],
      ["The list includes pantry items.", "Ask Home to re-read meals/pantry.md and redo the list."],
      ["Claude stopped partway through.", "You may have hit a usage limit. Wait for the reset time Claude shows, then say \"continue the Sunday review\"."]
    ],
    edge: { title: "Plan for your worst night", body: "Most meal plans fail on the hardest night of the week, because they were planned for an average night. Plan backwards: find your worst night first and give it the easiest dinner (slow cooker, leftovers, breakfast-for-dinner). Then plan everything else around it. The same rule works for any plan: protect the weakest point first.", try: "Name your family's worst night of the week, and pick its dinner for the next two weeks right now." },
    quiz: [
      { q: "Why does one sentence run the whole review?", o: ["Claude guesses the steps", "The steps are written in CLAUDE.md", "It's a built-in feature"], a: 1, why: "The house file spells out the review, so a short request is enough." },
      { q: "Which night should get the easiest dinner?", o: ["Sunday", "The busiest night", "Whichever night has the most time"], a: 1, why: "Plan for your worst night first." }
    ]
  },
  {
    id: "money", n: 6, title: "Money with the CFO", mins: 25,
    leave: "A weekly budget check on made-up numbers, and the habit of asking where you stand before you spend.",
    walt: "Most family budgets are a spreadsheet someone made in January and opened once, in February, with regret.",
    idea: { title: "Plan, spent, left", svg: "money",
      text: "The CFO reads your monthly plan and each week's spending, then tells you three numbers per category: the plan, what's spent and what's left. It does arithmetic on your numbers. It never gives financial advice." },
    steps: [
      { k: "start", text: "" },
      { k: "type", text: "Ask where the month stands:", prompt: "Ask the CFO: how are we doing this month? Show a small table." },
      { k: "quiz1", text: "Work it out first. Groceries are budgeted at $900. The Lindgrens spent $186 and $214. How many dollars are left for groceries?", answer: 500, unit: "$", hint: "186 + 214 = 400. 900 − 400 = 500." },
      { k: "type", text: "Ask a real question:", prompt: "Ask the CFO: Milo has a birthday party Saturday and we want to spend about $20 on a gift. Which category does it come from, and what's left there after?" },
      { k: "type", text: "Test the limit. The CFO should do the math but decline the advice:", prompt: "Ask the CFO: should we move our savings into stocks?" },
      { k: "do", text: "Open <b>money/spending-week-2026-11-09.csv</b> in Numbers. Add a row: <b>2026-11-15, Eating Out, 38, Tacos</b>. Save it as CSV, then ask the CFO again how Eating Out looks." }
    ],
    check: "The CFO says $500 left for groceries, puts the gift under Gifts with $75 left, and declines the stocks question.",
    breaks: [
      ["The numbers don't match.", "Ask: \"Show the math line by line from the CSV files.\" Check it read every spending file."],
      ["Numbers saved the file in its own format.", "Use File, Export To, CSV, and keep the same file name."]
    ],
    edge: { title: "Pay yourself first", body: "The most reliable money habit isn't tracking every coffee. It's deciding what goes to savings first, automatically, and spending what's left. Financial writers call it paying yourself first. A weekly check-in with real numbers makes it stick, because surprises get caught on Sunday instead of at the end of the month.", try: "Look up what percent of your take-home pay goes to savings now. Just the number. Knowing it is step one." },
    quiz: [
      { q: "The CFO's job is:", o: ["Advice on investing", "Arithmetic on your own numbers", "Paying your bills"], a: 1, why: "It does the math and explains it. Licensed advisors give advice." },
      { q: "What should never go in the money folder?", o: ["Category budgets", "Weekly spending totals", "Your card number"], a: 2, why: "Never put account or card numbers in." }
    ]
  },
  {
    id: "calendar", n: 7, title: "Bring in a calendar", mins: 30,
    leave: "The Lindgren calendar file turned into the hub's schedule file, following the calendar rules.",
    walt: "A family calendar is a historical document. It records what everyone meant to do, written by the one person who remembered.",
    idea: { title: "No links. Just a weekly file.", svg: "calendar",
      text: "Claude reads the calendar and writes a small schedule file for the hub. The hub never holds a calendar link, so nothing private is exposed. Today you practice on the Lindgrens' exported calendar file. In lesson 11 you connect your own." },
    steps: [
      { k: "start", text: "" },
      { k: "do", text: "Open <b>calendar/README.md</b>. Note the three traps: repeating events, notes you don't need, and Thanksgiving week." },
      { k: "type", text: "Turn the calendar into the week:", prompt: "Work as the Family CEO. Read calendar/lindgren-family.ics and list every event from Sunday, Nov 15 to Saturday, Nov 21, 2026, day by day. Follow the calendar rules in CLAUDE.md." },
      { k: "do", text: "Check: Ava's soccer appears on <b>both</b> Tuesday and Thursday (it's a repeating event). The note about Coach Rivera and the carpool family is <b>gone</b>." },
      { k: "type", text: "Write the hub's schedule file:", prompt: "Save that week as hub/schedule.js, as a JavaScript file that sets window.HUB_WEEK, with each day's events as time, first name and activity only. Mark busy nights using the rule in helpers/ceo.md." },
      { k: "type", text: "Try the hard week:", prompt: "Now list the week of Sunday, Nov 22. What changes because of Thanksgiving, and what should the Coach plan differently?" }
    ],
    check: "The week shows soccer on Tuesday and Thursday, no other people's names or places, and hub/schedule.js exists.",
    breaks: [
      ["Soccer shows only once.", "Say: \"Soccer repeats every Tuesday and Thursday until Dec 11. Expand repeating events.\""],
      ["Coach Rivera or the carpool family appear.", "Say: \"Follow the calendar rules: first name, activity and time only.\""]
    ],
    edge: { title: "The two-minute rule", body: "Calendars get messy because small things don't get entered: the vet, the bill, the early release. A popular productivity rule says if a task takes less than two minutes, do it now. Adding an event takes thirty seconds. The family that enters things the moment they hear about them is the family whose Sunday review is right.", try: "Ask everyone in your house to add one thing to the family calendar the moment they hear about it this week. See how many you catch." },
    quiz: [
      { q: "Why does the hub use a schedule file instead of a calendar link?", o: ["Links are slower", "A private link can leak your whole calendar", "Calendars don't allow links"], a: 1, why: "A schedule file holds only first name, activity and time for one week." },
      { q: "A repeating event appears only once. The fix is:", o: ["Enter it again by hand", "Tell Claude to expand repeating events", "Delete it"], a: 1, why: "Repeating events are written once with a rule; Claude must count each week." }
    ]
  },
  {
    id: "code", n: 8, title: "Meet Claude Code", mins: 40,
    leave: "First-run prompts handled, and a tiny page that opens on your Mac.",
    walt: "You are about to build software. Nobody will ask to see your degree. Software has never once asked.",
    idea: { title: "You describe. Claude writes the files.", svg: "code",
      text: "The Code tab is Claude built for making software. You describe what you want in plain words; it writes the files, opens them and fixes what breaks. You never type code, but you do read what it asks before you say yes." },
    steps: [
      { k: "do", text: "In the Claude app, open the <b>Code</b> tab. Choose the <b>lindgren-home</b> folder.", cos: "Code tab location and folder picker on Pro" },
      { k: "note", text: "The first time, your Mac may ask to install Apple's command line developer tools. Say <b>Install</b>. It can take 5 to 15 minutes. This is normal and only happens once." },
      { k: "type", text: "Start small:", prompt: "Read CLAUDE.md. Then make hub/hello.html: one page that says \"The Lindgren Family Hub\" in big friendly letters, Midnight blue (#14213D) background, linen text (#F5F3EF). Open it in my browser when done." },
      { k: "do", text: "Look at the page in your browser. Then find <b>hub/hello.html</b> in Finder and double-click it. Same page. It's just a file on your Mac." },
      { k: "type", text: "Change it by asking:", prompt: "Add a line under the title that shows today's date, and a little dog emoji for Biscuit." },
      { k: "type", text: "Learn what you made:", prompt: "Explain hub/hello.html to me like I'm new: what are the three main parts of the file?" }
    ],
    check: "hub/hello.html opens by double-clicking and shows the title, today's date and Biscuit.",
    breaks: [
      ["I don't see the Code tab.", "It's still rolling out to some Pro accounts. Use the Terminal fallback in When it breaks: install Claude Code with the one-line command on Anthropic's Claude Code setup page (copy it from that page on the day), then type claude in Terminal and follow the same steps."],
      ["It asks to install command line tools and it's taking forever.", "Let it finish. It's a one-time Apple download of several hundred megabytes."],
      ["Claude paused with a usage message.", "Paid plans share limits between chat and Code. Wait for the reset time shown, then say \"continue\"."]
    ],
    edge: { title: "Read before you say yes", body: "The Code tab asks permission before running commands or changing files. The temptation is to click yes on everything. Don't. You don't need to understand every word, but you should understand the verb: read, write, delete, install. When you see delete or install and didn't ask for it, say no and ask why. This one habit prevents most mistakes.", try: "For the rest of the course, before every yes, say out loud which verb it is." },
    quiz: [
      { q: "The Code tab asks to delete a file you didn't mention. You:", o: ["Say yes; it knows best", "Say no and ask why", "Close the app"], a: 1, why: "Understand the verb before you say yes." },
      { q: "Where does hub/hello.html live?", o: ["On a website", "In your lindgren-home folder on your Mac", "Inside the Claude app"], a: 1, why: "It's a file in your folder that opens in your browser." }
    ]
  },
  {
    id: "hub1", n: 9, title: "Build the family hub, part 1", mins: 45,
    leave: "One page that shows this week's schedule and dinners, in the fridge-door look.",
    walt: "Every family has a fridge door. Yours is about to get a sequel.",
    idea: { title: "Data files in, one page out", svg: "hub",
      text: "The hub reads small data files: schedule.js from the calendar, meals.js from the plan, budget.js from the CFO. Keep the data separate from the page, and next Sunday Claude only has to refresh the data." },
    steps: [
      { k: "do", text: "Open the <b>Code</b> tab on <b>lindgren-home</b>." },
      { k: "type", text: "Describe the hub. Copy this whole prompt:", prompt: "Read CLAUDE.md. Build hub/index.html, a family hub that opens by double-clicking with no internet. It loads hub/schedule.js (window.HUB_WEEK) and a new hub/meals.js you'll make from plans/week-of-2026-11-15.md (window.HUB_MEALS with each day's dinner and recipe). Look: like a fridge door. Linen background, paper-white sheets held by round copper magnets, Midnight blue header with a small drawing of a dog named Biscuit. Show a seven-day week with each person's events in their own color, busy nights outlined in copper, and each day's dinner at the bottom. Big readable text. Works on a phone-sized window too." },
      { k: "do", text: "When it opens, check every day against the plan. Then make the browser window narrow, like a phone. Does it still read?" },
      { k: "type", text: "Fix what you see, in plain words:", prompt: "The day boxes are cramped on a narrow window. Stack them two across on small screens, one across on very small." },
      { k: "type", text: "Make dinners useful:", prompt: "Make each dinner a button that opens its recipe: ingredients and how to make it." }
    ],
    check: "hub/index.html shows all seven days, outlines Tuesday and Thursday, and a dinner opens its recipe.",
    breaks: [
      ["The page is blank.", "Tell Claude exactly that: \"hub/index.html shows a blank page. Find out why and fix it.\" It can read the error itself."],
      ["The schedule doesn't match the calendar.", "Ask Claude to compare hub/schedule.js to the week list from lesson 7, line by line."]
    ],
    edge: { title: "Make the right thing easy", body: "Behavior research suggests people often do what's easy and visible, more than what they intended. That's why fruit on the counter gets eaten and fruit in the drawer rots. Your hub is the same trick for your week: if the plan is visible on one page, people follow it without being told.", try: "Move one thing in your kitchen this week to make a good habit easier: water bottles at eye level, the shopping list on the fridge." },
    quiz: [
      { q: "Why keep data files separate from the page?", o: ["It looks nicer", "Next Sunday Claude only refreshes the data", "Browsers require it"], a: 1, why: "The page stays the same; only the week's data changes." },
      { q: "The hub shows a blank page. Best first move:", o: ["Start over", "Tell Claude exactly what you see and ask it to fix it", "Search the internet"], a: 1, why: "Describe the problem plainly; Claude can investigate the error." }
    ]
  },
  {
    id: "hub2", n: 10, title: "Build the family hub, part 2", mins: 45,
    leave: "A shopping list you check off, the budget at a glance, and a Critic pass before anyone sees it.",
    walt: "A shopping list on paper has one flaw. It is always in the other jacket.",
    idea: { title: "Someone makes. Someone checks.", svg: "loop",
      text: "Add the shopping list and the budget, then send the whole hub to the Critic. The Critic scores it and lists fixes; Claude fixes them; the Critic checks again. The score usually goes up." },
    steps: [
      { k: "type", text: "Add the list:", prompt: "Add a shopping list section to the hub from the plan's list, grouped by store section, with checkboxes. Remember what's checked off in this browser, and say so on the page: \"Check-offs stay on this device only.\"" },
      { k: "type", text: "Add the money:", prompt: "Ask the CFO to write hub/budget.js (window.HUB_BUDGET) from the money folder. Then add a Budget at a glance section: one bar per category showing spent of budget, with a line where we'd be if spending were even across the month." },
      { k: "type", text: "Send it to the Critic:", prompt: "Have the Critic check the whole hub against CLAUDE.md and the plan. Score it out of 10 and list fixes, most important first. Don't fix anything yet." },
      { k: "type", text: "Then fix and check again:", prompt: "Fix the Critic's top three findings. Then have the Critic score it again." },
      { k: "do", text: "Compare your hub to the finished one in lesson 0. Yours doesn't have to match. It has to be right, clear and safe." }
    ],
    check: "Your hub has a check-off list that remembers, a budget section, and a Critic score that went up after fixes.",
    breaks: [
      ["Check-offs disappear when I reopen the page.", "Some browsers block saving for files opened from your Mac. Try Safari or Chrome, or ask Claude to explain the setting."],
      ["The Critic's score didn't go up.", "Ask the Critic which finding matters most, and fix only that one first."]
    ],
    edge: { title: "Why a critic beats willpower", body: "Everyone believes their own plan is fine. That's not arrogance; it's how brains work. We're bad at spotting our own mistakes and good at spotting other people's. Families, companies and surgeons all use the same fix: a second set of eyes with a checklist. You just built one that works on Sunday nights.", try: "Before the next big family decision, ask one person to find the weakest part of the plan. Thank them." },
    quiz: [
      { q: "Where are check-offs saved?", o: ["In iCloud, on every phone", "In this browser on this Mac", "In the calendar"], a: 1, why: "Browser storage stays on that device. Syncing is the next course." },
      { q: "The Critic finds problems. Who fixes them?", o: ["The Critic", "The builder, then the Critic checks again", "Nobody"], a: 1, why: "The maker fixes; the checker re-checks." }
    ]
  },
  {
    id: "yours", n: 11, title: "Make it yours", mins: 60,
    leave: "Your own my-home folder, your real calendar coming in under the calendar rules, and your own hub.",
    walt: "Practice is over. The Lindgrens thank you for your service. Biscuit would like a treat.",
    idea: { title: "Same team, your house", svg: "yours",
      text: "Copy the team and the hub into a fresh my-home folder with your family's details. Then connect your real calendar the safe way: Claude reads it on your Mac and writes the hub's weekly schedule file. Your calendar rules come with you." },
    steps: [
      { k: "note", text: "<b>Before any real family detail goes in:</b> what you type and the files Claude reads are sent to Anthropic under your own account and its settings. Open <b>Settings, Privacy</b> again and check your choice from lesson 1. Practice data was made up; from here on it is yours." },
      { k: "do", text: "In <b>Finder</b>, make a new folder in Documents, next to lindgren-home, called <b>my-home</b>. Drag in copies (hold Option while dragging) of <b>CLAUDE.md</b>, the <b>helpers</b> folder and <b>hub/index.html</b> (make a <b>hub</b> folder for it). Leave the Lindgren calendar, meals, money and plans behind." },
      { k: "start", text: "", folder: "my-home" },
      { k: "type", text: "Let Claude interview you and set up your house:", prompt: "This is my own family's folder. Ask me questions one at a time, then: (1) rewrite CLAUDE.md for my family, first names only, keeping the Never put in list, the calendar rules and the busy-night rule; (2) rewrite step 1 of the Sunday review for how my calendar comes in (Apple Calendar through the Mac's built-in scripting, Google through the connector, or an exported file in calendar/); (3) write meals/likes.md, meals/pantry.md and three starter recipes in meals/recipes/ with rough prices; (4) if I want a budget, write money/budget-YYYY-MM.csv with category totals only; (5) remove every Lindgren name and file from the helpers." },
      { k: "note", text: "Stop and check the Never put in list before you answer. First names, activities and times. No schools, addresses, account numbers, diagnoses or medications." },
      { k: "do", text: "<b>Calendar, Apple users:</b> in Calendar, make or pick one calendar called <b>Family</b>. Then open the <b>Code</b> tab on <b>my-home</b>.", cos: "Code tab folder picker" },
      { k: "type", text: "Apple Calendar, in the Code tab:", prompt: "Read CLAUDE.md. Read my Apple Calendar's Family calendar only, for next Sunday through Saturday, using the Mac's built-in tools. Include every occurrence of repeating events; if your method can't, tell me and use another way, or tell me to use the export route. Follow the calendar rules. Write hub/schedule.js as first name, activity and time only. Tell me what permissions you need before you ask for them." },
      { k: "note", text: "Expect up to two Mac prompts: one to let the app access <b>Calendars</b>, and one to let it <b>control Calendar</b> (Automation). Be clear on what the first covers: <b>all</b> of your calendars, not just Family. \"Family calendar only\" is a rule you give Claude in CLAUDE.md, not a lock. Turn either off any time in <b>System Settings, Privacy and Security</b>, under Calendars and Automation.", cos: "Calendars and Automation prompt wording" },
      { k: "do", text: "<b>Google Calendar users:</b> in Settings, Connectors, add Anthropic's Google Calendar connector. It can see every calendar on your account. \"Family calendar only\" is an instruction to Claude, not a technical limit, so tell it plainly. <b>Can't connect?</b> Export a file: Calendar, File, Export, and drop it in my-home/calendar/.", cos: "Connectors menu and Google Calendar connector name" },
      { k: "type", text: "Run your first real review:", prompt: "Run the Sunday review for next week, using my-home. Then have the Critic check it for anything on the Never put in list." }
    ],
    check: "my-home has your own CLAUDE.md, meals files and helpers with no Lindgren names; your hub shows your real week with first names and activities only; and you know how to turn the calendar permissions off.",
    breaks: [
      ["Claude can't read Apple Calendar.", "Check System Settings, Privacy and Security, under Calendars and Automation, and allow it. If that's not offered, use the exported-file route; it always works."],
      ["Repeating events are missing.", "Say: \"Expand repeating events for that week.\""],
      ["Claude copied Lindgren meals or money into my-home.", "Say: \"Remove any Lindgren data from my-home.\" Then check the folder yourself."],
      ["my-home ended up inside lindgren-home.", "In Finder, drag my-home out to Documents so the two sit side by side. Then choose my-home again in Cowork."],
      ["Scripting only shows the first soccer practice, not every week.", "Calendar scripting may not list each repeat (to test). Ask Claude to try another way, or use the export route; Claude can expand repeats in a file."]
    ],
    edge: { title: "Defaults run your life", body: "Most of what happens in a household isn't decided; it's defaulted. The same five dinners, the same Saturday, the same budget leaks. Research on defaults suggests that changing the default often changes behavior more than reminders do. The house file you just wrote is a set of defaults you chose on purpose.", try: "Find one default in your week that nobody chose (the Friday takeout, the Saturday errand run) and decide whether to keep it." },
    quiz: [
      { q: "Which calendar should Claude read?", o: ["All of them", "Your Family calendar only", "Your work calendar"], a: 1, why: "One Family calendar only. That's rule one." },
      { q: "How do you turn off Claude's access to Apple Calendar?", o: ["Delete Calendar", "System Settings, Privacy and Security: Calendars and Automation", "You can't"], a: 1, why: "Know how to disconnect before you connect." }
    ]
  },
  {
    id: "next", n: 12, title: "Your Sunday routine, and what comes next", mins: 15,
    leave: "A weekly routine of about ten minutes (to test), and a clear picture of what comes next.",
    walt: "You started this course with a vague feeling that AI should help. You end it with a fridge door that updates itself. Write that down for your grandchildren.",
    idea: { title: "Every Sunday", svg: "sunday",
      text: "Open Claude on my-home, paste the start line, say \"run the Sunday review\", glance at the Critic's score and open the hub. That's the routine. Apple Calendar users use the Code tab; Google or file users can use Cowork." },
    steps: [
      { k: "type", text: "Your whole Sunday, in one message:", prompt: "Before you do anything in this folder, read CLAUDE.md and follow it. Then run the Sunday review for next week, refresh hub/schedule.js, hub/meals.js and hub/budget.js, and open the hub." },
      { k: "do", text: "Set a repeating reminder on your phone for Sunday at 7 PM: <b>Sunday review</b>. Time how long it takes next week." },
      { k: "note", text: "Want to stop? Turn off Calendars and Automation access in System Settings, Privacy and Security, remove any connectors in Claude's Settings, and delete the my-home folder. That's everything." },
      { k: "do", text: "Look at the ladder below. You're on the first rung." }
    ],
    check: "You ran the full Sunday routine from one message, Claude made a plan without asking you anything, and you set a reminder for next week.",
    breaks: [
      ["It took far longer than ten minutes.", "Normal the first time. Ask Claude: \"What slowed this review down? Suggest one change to CLAUDE.md.\""]
    ],
    edge: { title: "Systems beat goals", body: "Goals are about the result you want; systems are what you do every week. A family that \"wants to eat better\" usually doesn't. A family with a Sunday review that plans dinners usually does. You didn't build an app this weekend. You built a system, and the app is just how you see it.", try: "Write one sentence about what you want your Sundays to feel like in a month. Check back." },
    quiz: [
      { q: "The Sunday routine starts with:", o: ["Opening the hub", "The start line, then \"run the Sunday review\"", "Exporting your calendar"], a: 1, why: "The start line makes Claude read your house file first." },
      { q: "To stop completely, you:", o: ["Uninstall your Mac", "Turn off Calendars and Automation access, remove connectors, delete my-home", "Nothing; it stops on its own"], a: 1, why: "Knowing how to stop is part of being in control." }
    ]
  },
  {
    id: "bonus-work", n: 13, bonus: true, title: "Bonus: your work week next to your home week", mins: 15,
    leave: "A Project for your work week that stays separate from home, and the employer-policy rule.",
    walt: "Your job and your family share one calendar and one brain. They should not share one folder.",
    idea: { title: "Two rooms, one person", svg: "project",
      text: "Make a separate Project for your work week, with nothing from home in it. Before any work information goes into Claude, check your employer's AI policy. Some allow it, some don't, and it's their call." },
    steps: [
      { k: "note", text: "<b>Check your employer's AI policy first.</b> If it says no, or you're not sure, skip this lesson or use only made-up examples. Never put customer, coworker or company data into a personal account, and never connect a work calendar or work email to your personal Claude." },
      { k: "type", text: "Make a Work Week Project and give it instructions in your own words, like this:", prompt: "I work Monday to Friday, 8 to 5. I want help planning my week: what to do first, how to protect focus time, and how to leave on time for family nights. Don't ask for or store anything about my employer, customers or coworkers." },
      { k: "type", text: "Plan around home. <b>Replace the brackets with your busy nights from your hub.</b>", prompt: "My family's busy nights are [your busy nights]. Help me plan a work week that protects leaving by 4:45 on those days. Three bullets." }
    ],
    check: "You have a Work Week Project with no home or employer data in it, and you checked your employer's policy.",
    breaks: [],
    edge: { title: "Protect the edges", body: "Work expands to fill the time it's given. People who leave on time usually don't work less; they decide ahead which days have hard stops and protect them. The busy nights your CEO marks are the perfect hard stops.", try: "Put a recurring 4:45 PM \"leave\" block on your work calendar for your family's busiest night." },
    quiz: [
      { q: "Before work information goes into Claude, you:", o: ["Ask a coworker", "Check your employer's AI policy", "Just use made-up names"], a: 1, why: "It's your employer's call." }
    ]
  },
  {
    id: "bonus-gmail", n: 14, bonus: true, title: "Bonus: Gmail, one sender only", mins: 10,
    leave: "Claude finding dates in one activity's emails, with tight limits.",
    walt: "Your inbox is where good intentions go to be marked unread.",
    idea: { title: "One sender. Date, activity, first name.", svg: "calendar",
      text: "Anthropic offers a Gmail connector. The connector may be able to reach your whole inbox; \"one sender\" is a rule you give Claude, not a lock. So we ask narrowly: one named sender or label, such as the soccer league. Claude keeps date, activity and first name only. No forwarding, no drafts. Whether the connector is read-only is to be confirmed on screen." },
    steps: [
      { k: "do", text: "In Claude's Settings, Connectors, add Gmail. Read what access it asks for before you allow it.", cos: "Connectors menu, Gmail connector name, and whether access is read-only" },
      { k: "do", text: "Open one email from the activity you care about (for example, the soccer league) and copy the sender's email address." },
      { k: "type", text: "Ask narrowly. <b>Replace the brackets with that address before you send.</b>", prompt: "Search my Gmail for emails from one sender only: [paste the address here]. List any game or practice changes for the next two weeks as date, activity and first name only. Don't forward, draft or reply to anything, and don't keep any coach's or other parents' names." },
      { k: "note", text: "Done? You can remove the connector in Settings, Connectors any time." }
    ],
    check: "Claude listed changes from one sender only, with date, activity and first name, and nothing was sent.",
    breaks: [],
    edge: { title: "Less input, better output", body: "It's tempting to give AI everything and hope it sorts it out. Narrow requests get better answers and leak less. One sender, one question, one week.", try: "Unsubscribe from three emails you never read. Your future Sunday review will thank you." },
    quiz: [
      { q: "The Gmail rule is:", o: ["Let Claude read everything", "One named sender or label, date, activity and first name only", "Forward school emails to Claude"], a: 1, why: "Narrow access, minimal details." }
    ]
  },
  {
    id: "bonus-notes", n: 15, bonus: true, title: "Bonus: Apple Notes for the family", mins: 10,
    leave: "The shopping list in an Apple Note you can open on your phone at the store.",
    walt: "The shopping list is now on your phone. It's still in the other jacket, but the jacket is in your pocket.",
    idea: { title: "Your list, in your pocket", svg: "hub",
      text: "Anthropic's Read and Write Apple Notes extension lets Claude put this week's list into a note that syncs to your iPhone through iCloud. That means it also lives in your iCloud account, and the extension can reach your other notes too. Practice on a Lindgren note first, and keep the list to groceries." },
    steps: [
      { k: "do", text: "In Claude's Settings, find and turn on the <b>Apple Notes</b> extension. Read what it can do.", cos: "Extension name and where it's turned on" },
      { k: "note", text: "Turn the extension on before you start the task." },
      { k: "start", text: "" },
      { k: "type", text: "Practice with the Lindgrens:", prompt: "Make an Apple Note called \"Lindgren list (practice)\" with this week's shopping list from lindgren-home, grouped by store section." },
      { k: "do", text: "Open Notes on your iPhone. The list is there. Delete the practice note when you're done." }
    ],
    check: "The practice note appeared on your phone, and you deleted it afterwards.",
    breaks: [],
    edge: { title: "Capture everywhere, review in one place", body: "The best personal systems let you capture anywhere (a note, a text, a voice memo) and review in one place. Your hub is the one place. Notes is a pocket.", try: "Pick one capture spot for family to-dos this week. Just one." },
    quiz: [
      { q: "Why practice on a Lindgren note first?", o: ["It's required", "So a mistake doesn't touch your real notes", "Notes needs a demo"], a: 1, why: "Practice data first, every time." }
    ]
  }
  ],
  ladder: [
    ["You are here", "PX1: a family hub on your Mac, refreshed by your family team every Sunday."],
    ["Launch Your Family App", "The next course: your hub online, on everyone's phone, each with their own login, synced lists and a private calendar feed. $29 off for PX1 students."],
    ["Courses for your field", "Mid-tier courses for specific jobs, like leading a sales team or launching an App Store app."],
    ["The flagship", "A full AI-agents program for business, at a fraction of big-program prices."]
  ]
};
