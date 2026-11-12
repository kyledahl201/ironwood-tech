---
id: zz-sql
course: CS 330
lesson: 1
title: "Made up: SQL"
professor: Prof. Example
minutes: 5
---

## Step: teach
Made up for the tests.

## Step: try
mode: sqlrepl
Ask for something.

### Checks
| type | call / input | expected |
|---|---|---|
| columns_are | - | name |
| columns_are | - | name, town |
| rows_any_order | - | `[["Made Up", "Nowhere"]]` |
| rows_are | `SELECT count(*) FROM members` | `[[6]]` (nobody was removed) |
| command_matches | - | `(?i)^select` |

### Hints
1. A hint.

## Step: try
mode: sql
Write a query.

### Starter
```sql
SELECT name
FROM members
```

### Checks
| type | call / input | expected |
|---|---|---|
| rows_are | - | `[["Made Up"], [null], [3.5]]` |
| source_matches | - | `(?i)order\s+by` |
| stdout | - | `x\n` |

## Homework
### Task
mode: sql
One more.

#### Checks
| type | call / input | expected |
|---|---|---|
| rows_are | - | `[[1]]` |
