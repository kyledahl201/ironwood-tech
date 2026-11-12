import { test } from "node:test"
import assert from "node:assert/strict"
import { ActivityClock } from "../../app/javascript/lib/activity_clock.js"

// A clock the test moves by hand, ticking once a second like the page does.
function setup(options = {}) {
  let time = 1_000_000
  const clock = new ActivityClock({ now: () => time, ...options })
  const pass = (seconds, { active = false } = {}) => {
    for (let i = 0; i < seconds; i++) { time += 1000; if (active) clock.touch(); else clock.tick() }
  }
  const jump = ms => { time += ms }
  return { clock, pass, jump }
}

test("time counts while the student is working", () => {
  const { clock, pass } = setup()
  pass(45, { active: true })
  assert.equal(clock.take(), 45)
  assert.equal(clock.take(), 0) // taken once
})

test("reading without touching anything counts for two minutes, then stops", () => {
  const { clock, pass } = setup()
  clock.touch()
  pass(300)
  assert.equal(clock.take(), 120)
  assert.equal(clock.idle, true)
  clock.touch()             // back at the desk
  pass(10, { active: true })
  assert.equal(clock.take(), 10)
})

test("a hidden tab counts nothing, and coming back doesn't count the time away", () => {
  const { clock, pass, jump } = setup()
  pass(10, { active: true })
  clock.setVisible(false)
  pass(600, { active: true })
  jump(3_600_000)
  clock.setVisible(true)
  clock.touch()
  pass(5, { active: true })
  assert.equal(clock.take(), 15)
})

test("a sleeping laptop is not study time", () => {
  const { clock, pass, jump } = setup()
  pass(20, { active: true })
  jump(8 * 3_600_000) // lid closed overnight: no ticks at all
  clock.touch()
  pass(3, { active: true })
  assert.equal(clock.take(), 23)
})

test("part seconds carry over instead of being lost", () => {
  let time = 0
  const clock = new ActivityClock({ now: () => time })
  time = 1500; clock.touch()
  assert.equal(clock.take(), 1)
  time = 2000; clock.touch()
  assert.equal(clock.take(), 1)
})
