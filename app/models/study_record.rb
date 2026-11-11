# What a student studied for one lesson outside class: flashcards sorted into
# "got it" and "again later", and the class questions retried. Kept apart from
# ClassProgress so retry scores never overwrite first-try scores from class.
class StudyRecord < ApplicationRecord
  belongs_to :user
  belongs_to :class_lesson

  def card_count = class_lesson.flashcards.size
  def cards_known = known_cards.size
  def deck_done? = card_count.positive? && cards_known >= card_count

  # One flashcard was sorted. Finishing the deck is counted once per pass.
  def sort_card!(index, known:)
    return unless index.between?(0, card_count - 1)
    if known
      return if known_cards.include?(index)
      self.known_cards = known_cards + [ index ]
      if deck_done?
        self.decks_finished += 1
        self.deck_finished_at = Time.current
      end
    else
      self.cards_again += 1
    end
    save!
  end

  def restart_deck! = update!(known_cards: [])

  def retry_total = retry_first.size
  def retry_right = retry_first.values.count(true)

  def record_retry!(step, right)
    return if retry_first.key?(step.to_s)
    update!(retry_first: retry_first.merge(step.to_s => right), retried_at: Time.current)
  end

  def restart_questions! = update!(retry_first: {})

  # One line for lists: "Flashcards 5 of 8 known · Questions 2 of 3 on retry".
  def summary
    parts = []
    parts << (deck_done? ? "Flashcards done#{" (#{decks_finished} times)" if decks_finished > 1}" : "Flashcards #{cards_known} of #{card_count} known") if card_count.positive? && (cards_known.positive? || decks_finished.positive?)
    parts << "Deck finished #{decks_finished} #{'time'.pluralize(decks_finished)}" if !deck_done? && decks_finished.positive?
    parts << "Questions #{retry_right} of #{retry_total} right on retry" if retry_total.positive?
    parts.join(" · ")
  end
end
