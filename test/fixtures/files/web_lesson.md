---
id: zz-web
course: WD 110
lesson: 1
title: "Made up: a web page"
professor: Prof. Example
minutes: 5
---

## Step: teach
Made up for the tests.

## Step: try
mode: web
Add a made-up thing.

### Starter
```html
<!DOCTYPE html>
<p>Start</p>
```

### Checks
| type | call / input | expected |
|---|---|---|
| page_has | `nav a` | `2` (the menu has two links) |
| page_has | `footer` | - |
| page_has | `main` | `any` (there is a main part) |
| text_is | `h2` | `Made up` |
| style_is | `h2 { font-size }` | `2em` |
| style_is | `.box { background-color }` | `#F5F3EF` (the box is linen) |
| source_matches | - | `(?i)<!doctype html>` (the page starts with a doctype) |

### Hints
1. A hint.
