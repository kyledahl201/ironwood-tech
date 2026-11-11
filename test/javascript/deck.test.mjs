import { test } from "node:test"
import assert from "node:assert/strict"
import { Deck } from "../../app/javascript/lib/deck.js"

test("got it removes a card, again later sends it to the back", () => {
  const deck = new Deck(3, () => 0.999) // this "random" leaves the order as 0, 1, 2
  assert.deepEqual([deck.current, deck.tally, deck.done], [0, "0 of 3 known", false])
  deck.again()
  assert.equal(deck.current, 1)
  deck.gotIt()
  assert.deepEqual([deck.current, deck.tally], [2, "1 of 3 known"])
  deck.gotIt()
  assert.equal(deck.current, 0) // the card set aside comes round again
  deck.gotIt()
  assert.deepEqual([deck.done, deck.tally], [true, "3 of 3 known"])
  deck.gotIt(); deck.again() // nothing left: no change, no error
  assert.equal(deck.known, 3)
})

test("shuffling keeps every card exactly once", () => {
  const deck = new Deck(8)
  assert.deepEqual([...deck.pile].sort((a, b) => a - b), [0, 1, 2, 3, 4, 5, 6, 7])
})

test("a deck you never get right never finishes", () => {
  const deck = new Deck(2)
  for (let i = 0; i < 10; i++) deck.again()
  assert.deepEqual([deck.done, deck.known], [false, 0])
})
