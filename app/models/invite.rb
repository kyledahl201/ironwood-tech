# Accounts are invite-only. The owner creates a link; one person uses it once.
class Invite < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :used_by, class_name: "User", optional: true

  has_secure_token :token, length: 32
  before_validation -> { self.expires_at ||= 14.days.from_now }, on: :create

  scope :open, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def usable? = used_at.nil? && expires_at.future?

  def self.find_usable(token)
    return nil if token.blank?
    invite = find_by(token: token.to_s)
    invite if invite&.usable?
  end

  def redeem!(user)
    update!(used_by: user, used_at: Time.current)
  end
end
