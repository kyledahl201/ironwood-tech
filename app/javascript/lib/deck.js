// A pile of flashcards. "Got it" takes the top card out; "again later" sends
// it to the back so it comes round again. The deck is done when the pile is empty.
export class Deck {
  constructor(count, random = Math.random) {
    this.count = count
    this.pile = Array.from({ length: count }, (_, i) => i)
    for (let i = this.pile.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));
      [this.pile[i], this.pile[j]] = [this.pile[j], this.pile[i]]
    }
    this.known = 0
  }

  get current() { return this.pile[0] }
  get done() { return this.pile.length === 0 }
  get tally() { return `${this.known} of ${this.count} known` }

  again() { if (!this.done) this.pile.push(this.pile.shift()) }
  gotIt() { if (!this.done) { this.pile.shift(); this.known += 1 } }
}
