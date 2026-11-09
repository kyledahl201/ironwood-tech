# Ironwood Institute of Technology

The public website of Ironwood Tech, a personal, self-directed computer science and data science curriculum. Ironwood is not an accredited institution and does not grant degrees. Its faculty are fictional, and all data here is made up or is Kyle's own.

## What is in this repository

This is **static site v0**, built with Claude as a hobby project. It is plain HTML and CSS with no accounts, no tracking and no JavaScript. It is not part of Kyle's portfolio work.

The real site is a Rails 8 app with a student portal, a digital transcript and course records. **Kyle is writing that himself as App #2**, in a separate repository, during Stage 3 of the curriculum. When it ships, it replaces this site.

## Pages

| Page | File |
| --- | --- |
| Home | `docs/index.html` |
| How it works | `docs/about.html` |
| Academics and 10 department pages | `docs/academics/` |
| 32 public course summaries | `docs/courses/` |
| Faculty directory | `docs/faculty.html` |
| Athletics: the Sentinels | `docs/athletics.html` |
| News and the Sentinel Dispatch | `docs/news/` |
| Student login (placeholder until App #2) | `docs/login.html` |

## Not indexed yet

Every page carries `noindex, nofollow`, `docs/robots.txt` disallows all crawlers, and a "personal project" strip sits at the top of every page. Kyle decides when to opt in to search indexing.

## Build

The pages are generated from data so the catalog stays the single source. You need Python 3.10 or newer and nothing else.

```sh
python3 tools/build.py
```

- `tools/catalog.py`: departments, faculty and courses, the same data as the printed catalog.
- `content/news/*.md`: Office of Communications posts. Name new posts `YYYY-MM-DD-slug.md`.
- `docs/assets/`: the stylesheet and the brand masters (SVG), unchanged from the brand book.

## Publish with GitHub Pages

Settings → Pages → Build and deployment → Source: **Deploy from a branch**, Branch: **main**, folder **/docs**. The site appears at `https://kyledahl201.github.io/ironwood-tech/`.

## Design

The layout follows Prof. Camille Duarte's Phase 1 wireframes and UI notes, and the colors, type and marks come from Ironwood Brand Book edition 1. Copper is used only for large type, rules and focus rings. Small copper text on light grounds uses Copper Deep, so text meets WCAG AA contrast.
