import { Controller } from "@hotwired/stimulus"
import { postJSON } from "lib/ui"
import { Deck } from "lib/deck"

// The study page: flashcards the student sorts into "got it" and "again
// later", and the questions from class, checked on the server like in class.
export default class extends Controller {
  static targets = ["source", "deck", "card", "side", "text", "tip", "tally", "flipButton", "againButton", "knownButton", "done"]
  static values = { quizUrl: String }

  connect() {
    if (this.hasCardTarget) this.restart()
  }

  // Flashcards ------------------------------------------------------------------

  restart() {
    this.cards = new Deck(this.sourceTargets.length)
    this.deckTarget.hidden = false
    this.doneTarget.hidden = true
    this.show(false)
  }

  show(flipped) {
    this.flipped = flipped
    const [front, back] = this.sourceTargets[this.cards.current].children
    this.textTarget.innerHTML = (flipped ? back : front).innerHTML // server-sanitized Markdown
    this.sideTarget.textContent = flipped ? "Answer" : "Question"
    this.tipTarget.textContent = flipped ? "Did you have it?" : "Say the answer out loud, then flip"
    this.cardTarget.classList.toggle("is-flipped", flipped)
    this.flipButtonTarget.hidden = flipped
    this.againButtonTarget.hidden = this.knownButtonTarget.hidden = !flipped
    this.tallyTarget.textContent = this.cards.tally
  }

  flip() { this.show(!this.flipped) }

  again() {
    this.cards.again()
    this.show(false)
    this.cardTarget.focus({ preventScroll: true })
  }

  gotIt() {
    this.cards.gotIt()
    this.tallyTarget.textContent = this.cards.tally
    if (this.cards.done) {
      this.deckTarget.hidden = true
      this.doneTarget.hidden = false
      return
    }
    this.show(false)
    this.cardTarget.focus({ preventScroll: true })
  }

  async copy(event) {
    const button = event.currentTarget
    const label = button.textContent
    try {
      await navigator.clipboard.writeText(button.dataset.copy)
      button.textContent = "Copied"
    } catch (_) {
      button.textContent = "Select the text above and copy it"
    }
    setTimeout(() => { button.textContent = label }, 1800)
  }

  // Questions from class ------------------------------------------------------------

  async answer(event) {
    const button = event.currentTarget
    const question = button.closest(".study-question")
    let data
    try {
      data = await postJSON(this.quizUrlValue, { step: Number(question.dataset.step), choice: Number(button.dataset.choice) })
    } catch (_) {
      return
    }
    button.disabled = true
    button.classList.add(data.right ? "is-right" : "is-wrong")
    button.querySelector(".quiz-mark").textContent = data.right ? "✓" : "✗"
    button.querySelector(".quiz-word").textContent = data.right ? "Right" : "Not this one"
    const explain = question.querySelector("[data-role=explain]")
    explain.hidden = false
    if (data.right) {
      question.querySelectorAll(".quiz-option").forEach(b => { b.disabled = true })
      explain.innerHTML = data.explain || "Right." // server-sanitized Markdown
    } else {
      explain.textContent = "Not this one. Pick again."
    }
  }
}
