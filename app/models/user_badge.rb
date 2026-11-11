class UserBadge < ApplicationRecord
  belongs_to :user

  validates :key, inclusion: { in: ->(_) { Badges::ALL.keys } }, uniqueness: { scope: :user_id }

  scope :unseen, -> { where(seen_at: nil) }

  def definition = Badges::ALL.fetch(key)
end
