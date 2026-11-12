---
id: demo-web
course: TOUR
lesson: 5
title: A tour of web pages in the classroom
professor: Sentry
minutes: 10
---

## Step: teach
Every web page is built from two languages. **HTML** says what is on the page: a heading, a paragraph, a list. **CSS** says how it looks: colours, sizes, spacing.

The bench has a **web page editor** for both. You type on one side, and the **preview** shows your page as you type, the way a browser tab would.

It's a safe sandbox: scripts don't run, links don't go anywhere, and nothing is fetched from the internet.

## Step: try
mode: web
HTML is made of **tags**. A tag opens like `<p>` and closes like `</p>`, and what sits between them is its content.

The page below has a body with nothing in it. Inside the body, add a main heading, which is the `h1` tag, that says `Ironwood Tech`.

### Starter
```html
<!DOCTYPE html>
<html>
  <head>
    <title>My first page</title>
  </head>
  <body>

  </body>
</html>
```

### Checks
| type | call / input | expected |
|---|---|---|
| page_has | `body h1` | `1` (the page has one main heading) |
| text_is | `h1` | `Ironwood Tech` |

### Hints
1. A heading opens with its tag name in angle brackets and closes with the same name after a slash.
2. Put it on the empty line between the body's opening and closing tags.
3. Spelling, the space and the capital letters count. Watch the preview: it should show the words in big bold type.

## Step: try
mode: web
Now give the heading company. Under it, add a paragraph (the `p` tag) with any sentence you like, and then a list of three things you want to learn.

A list is an outer `ul` tag with one `li` tag inside it for each item.

### Checks
| type | call / input | expected |
|---|---|---|
| page_has | `body p` | `any` (the page has a paragraph) |
| page_has | `ul li` | `3` (the list has three items) |

### Hints
1. The paragraph goes after the heading's closing tag, still inside the body.
2. The list has two levels: one tag that wraps the whole list, and inside it a tag around each item.
3. If the preview shows fewer than three bullets, count your `li` tags. Each needs its own opening and closing tag.

## Step: quiz
Which part of this is the **content**?

`<h1>Ironwood Tech</h1>`

- [ ] `<h1>`
- [x] `Ironwood Tech`
- [ ] `</h1>`

> The tags mark where the heading starts and stops. The words between them are what the reader sees.

## Step: teach
CSS is a list of **rules**. A rule names what to style, then says how, inside curly brackets:

```css
p {
  color: gray;
}
```

`p` is the **selector**: every paragraph. `color` is the **property**, and `gray` is its **value**. Each line inside ends with a semicolon.

For now, rules live inside a `style` tag in the page's `head`.

## Step: try
mode: web
Add a `style` tag inside your page's head, under the title. In it, write a rule that makes the main heading Ironwood copper. The colour's code is `#B87333`.

### Checks
| type | call / input | expected |
|---|---|---|
| page_has | `head style` | `1` (the rules are in a style tag in the head) |
| style_is | `h1 { color }` | `#B87333` (the heading is copper) |

### Hints
1. The `style` tag opens and closes like any other tag, and the rules go between. It belongs in the head, not the body.
2. The rule has the same shape as the one in the last step. Only the selector and the value change.
3. The selector is the tag name of the thing you're styling, with no angle brackets. The colour code starts with a `#`.

## Step: teach
A tag selector styles every tag of that kind. To style just one thing, give it a **class**, a name you make up:

```html
<p class="motto">Built to last.</p>
```

In CSS, a class selector starts with a dot: `.motto { ... }`.

## Step: try
mode: web
Give your paragraph the class `note`. Then add a rule for that class that centres its text. The property is `text-align`.

### Checks
| type | call / input | expected |
|---|---|---|
| page_has | `p.note` | `any` (a paragraph has the class note) |
| source_matches | - | `\.note\s*\{` (there is a rule for the class) |
| style_is | `.note { text-align }` | `center` (its text is centred) |

### Hints
1. The class goes inside the paragraph's opening tag, as `class` then an equals sign then the name in quotes.
2. In the style tag, a class selector is a dot followed by the class name.
3. CSS uses the American spelling for the value.

## Step: teach
That's the web page editor. A few things to know:

- The preview redraws as you type. **Check** is what looks at your page against the task.
- **Reset** puts back the step's starting code.
- **Copy for my tutor** copies your page and the checks, to paste into a chat with your professor.

Real projects keep CSS in its own file and add JavaScript. Those come later, on your Mac, where a real browser and real files are waiting.
