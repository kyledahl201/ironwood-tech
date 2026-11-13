# PX1 course player ("Life and Work, With Claude")

This folder is the finished PX1 course, copied as built. It is deliberately
**not** under `public/`: `CoursePlayersController` sends `index.html` only to
the owner and to students with an active enrollment in the `px1` course
(`/learn/px1/player`), and zips `downloads/` for the same people
(`/learn/px1/downloads`).

| Path | What it is |
| --- | --- |
| `index.html` | The built player: one self-contained page fragment (styles, images, lessons and script inline). `CoursePlayer#html` wraps it in a document. |
| `source/` | What `index.html` is built from: `shell.html`, `content.js` (the lessons), `assets.js` (inline images), `build.py`, `test.js` (a Playwright smoke test) and `make-recording-script.js`. Kept for reference; the portal reads only `index.html`. |
| `downloads/lindgren-home/` | The practice folder students work in. |
| `downloads/reference-hub/` | The finished hub, for reference. `source/build.py` also reads its `.js` data files. |

## Where it came from

Copied on 2026-11-13 from the project's shared files:
`university/px1/build/course-player/` (`index.html` and `source/`),
`university/px1/build/lindgren-home/` and `university/px1/build/reference-hub/`.
Nothing was edited. The lessons are not in the portal's lesson tables.

## How to refresh it

1. Edit the course where it is written (`source/content.js`, `source/shell.html`) and rebuild there.
   `build.py` expects `reference-hub/` two folders above `source/`, as it is in the project's shared files,
   so build in the original folder: `python3 build.py .` from `course-player/source/`.
2. Copy the new `index.html` and `source/` over the ones here, and the two practice folders over `downloads/`.
3. Run `bin/rails test` and commit.

Everything in the course (the Lindgrens, Cedar Hollow, schedules, meals, prices and budgets) is made up.
