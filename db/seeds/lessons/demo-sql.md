---
id: demo-sql
course: TOUR
lesson: 3
title: A tour of SQL in the classroom
professor: Sentry
minutes: 10
---

## Step: teach
The bench speaks SQL, the language for asking a database questions. Courses that use databases get two more tools:

- **SQL console**: type one statement, press Enter, see the rows that come back.
- **SQL editor**: write a longer query, then run it.

Both work on a practice database that lives in your browser: a small made-up library with three tables, `books`, `members` and `loans`. Nothing here touches a real database.

## Step: try
mode: sqlrepl
Start in the SQL console. Lines that begin with a dot are console commands, not SQL. Type `.tables` to list the tables.

### Checks
| type | call / input | expected |
|---|---|---|
| command_matches | - | `^\.tables` (you asked for the tables) |
| output_matches | - | `^members$` (the console listed them) |

### Hints
1. Type a dot, then the word tables, with no space between them. Then press Enter.

## Step: teach
A question in SQL is called a **query**. The simplest one reads like a sentence:

```sql
SELECT * FROM books;
```

`SELECT *` means "give me every column". `FROM books` says which table. The **semicolon** ends the statement. Until you type one, the prompt changes to `...>` and the console waits for the rest.

## Step: try
mode: sqlrepl
Show every column of every row in the `members` table.

### Checks
| type | call / input | expected |
|---|---|---|
| columns_are | - | id, name, town, joined_on |
| rows_any_order | `SELECT count(*) FROM members` | `[[6]]` (all six members are still there) |
| output_matches | - | `^\(6 rows\)$` (six rows came back) |

### Hints
1. Use the same sentence as the example, with the other table's name.
2. Nothing happening and the prompt shows `...>`? The console is waiting for the semicolon.

## Step: teach
Two more pieces. Name the columns you want instead of `*`, and add `WHERE` to keep only some rows:

```sql
SELECT name FROM members WHERE town = 'Oakdale';
```

Text goes in **single quotes**. SQL keywords can be capitals or small letters; capitals just make them easier to spot.

## Step: try
mode: sqlrepl
List only the `title` of every book whose `genre` is mystery.

### Checks
| type | call / input | expected |
|---|---|---|
| columns_are | - | title |
| rows_any_order | - | `[["Rivers Under Glass"], ["The Long Division"], ["Night Trains to Avery"]]` |

### Hints
1. Start from the example: change the column, the table, and what `WHERE` compares.
2. The genre is text, so it needs single quotes, and it's written in small letters in the table.
3. Seeing more than one column? Name just `title` after `SELECT`.

## Step: try
mode: sqlrepl
SQL changes data too. Finn Abara has moved to Avery. Change his `town` with an `UPDATE` statement, which has this shape:

```sql
UPDATE table SET column = value WHERE which rows;
```

### Checks
| type | call / input | expected |
|---|---|---|
| rows_are | `SELECT town FROM members WHERE name = 'Finn Abara'` | `[["Avery"]]` (Finn lives in Avery now) |
| rows_are | `SELECT count(*) FROM members WHERE town = 'Avery'` | `[[2]]` (and nobody else moved) |

### Hints
1. Fill in the shape: the table is `members`, the column is `town`, the value is text.
2. The `WHERE` part picks Finn's row. Compare `name` with his full name in single quotes.
3. If everyone moved to Avery, the `WHERE` was missing. Press **Reset** to get a fresh database and try again.

## Step: quiz
You press Enter in the SQL console, nothing runs, and the prompt shows `...>`. What is it waiting for?
- [ ] For you to type `end`
- [x] For the semicolon that ends the statement
- [ ] For the database to finish loading
> A statement isn't finished until its semicolon. That lets you spread a long query over several lines.

## Step: teach
Now the **SQL editor**, for queries too long for one line. Two things to know:

- `ORDER BY year` sorts the rows by a column. Add `DESC` to put the biggest first.
- Every run starts from a **fresh copy** of the library, so nothing you change in the editor sticks.

## Step: try
mode: sql
Finish this query so it shows the title and year of books published **after 2015**, newest first. Then press **Check**.

### Starter
```sql
SELECT title, year
FROM books
-- your code here
```

### Checks
| type | call / input | expected |
|---|---|---|
| columns_are | - | title, year |
| rows_are | - | `[["Salt and Signal", 2022], ["A Field Guide to Quiet", 2021], ["How Maps Lie", 2020], ["The Copper Lantern", 2019]]` |

### Hints
1. You need two more lines: one that keeps only some rows, one that sorts them.
2. `WHERE` goes before `ORDER BY`. Numbers are compared with `>` and need no quotes.
3. Right rows but in the wrong order? Sort by `year`, biggest first.

## Step: teach
SQL can count as well as list. `COUNT(*)` gives the number of rows, and `AS` names the column in the result:

```sql
SELECT COUNT(*) AS total FROM books;
```

An empty value in a table is called `NULL`. You can't compare it with `=`. Ask with `IS NULL` instead. In `loans`, a book that hasn't come back yet has a `NULL` in `returned_on`.

## Step: try
mode: sql
How many loans are still out? Write a query that gives one row with one column named `still_out`.

### Starter
```sql
-- Count the loans that haven't been returned.
```

### Checks
| type | call / input | expected |
|---|---|---|
| columns_are | - | still_out |
| rows_are | - | `[[5]]` |
| source_matches | - | `(?i)is\s+null` (you asked which rows are empty) |

### Hints
1. Start from the counting example. Change the table and the name after `AS`.
2. Add a `WHERE` that keeps only the loans with nothing in `returned_on`.
3. Got 0? `= NULL` never matches anything. Use `IS NULL`.

## Step: teach
That's SQL in the classroom. The database here is SQLite. Rails apps usually run on PostgreSQL, and the basics you just used are the same in both.

## Study guide
- The SQL console runs one statement at a time on a practice library database. Changes last until you reset it.
- A statement ends with a semicolon. `...>` means the console is waiting for it.
- `.tables` lists the tables and `.schema books` shows a table's columns. These are console commands, not SQL.
- `SELECT columns FROM table WHERE condition ORDER BY column` is the shape of most queries.
- Text goes in single quotes. Empty values are `NULL`, tested with `IS NULL`.
- The SQL editor starts from a fresh copy of the database on every run.

## Flashcards
- What ends a SQL statement? :: A semicolon.
- What does `SELECT *` mean? :: Give me every column.
- Which part of a query keeps only some rows? :: `WHERE`
- How do you sort results, biggest first? :: `ORDER BY column DESC`
- How do you test for an empty value? :: `IS NULL` (never `= NULL`)
- What does `.tables` do in the SQL console? :: Lists the tables. It's a console command, not SQL.
