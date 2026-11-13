# A course given to someone by email: bought as a gift in the store (after
# Stripe confirms the payment), or given by the owner. The recipient gets a
# one-time link. Claiming it, signed in, makes an enrollment with source
# "gift". Only a digest of the link's token is stored, so the database alone
# can't be used to claim anything. A gift can be forwarded: whoever claims it
# first gets the course, and is recorded.
class Gift < ApplicationRecord
  LIFETIME = 30.days

  belongs_to :course
  belongs_to :purchaser, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :redeemed_by, class_name: "User", optional: true
  has_one :enrollment, dependent: :nullify

  normalizes :recipient_email, with: ->(e) { e.strip.downcase }
  validates :recipient_email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token_digest, presence: true, uniqueness: true

  before_validation :issue_token, on: :create

  scope :newest_first, -> { order(created_at: :desc) }

  # The link's token, only in memory, right after the gift is made or a new
  # link is issued. It is never stored.
  attr_reader :token

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)

  def self.find_by_token(token)
    token = token.to_s
    return nil unless token.match?(/\A[A-Za-z0-9_-]{20,100}\z/)
    find_by(token_digest: digest(token))
  end

  def purchase? = stripe_session_id.present?
  def redeemed? = redeemed_at.present?
  def revoked? = revoked_at.present?
  def expired? = !redeemed? && expires_at.past?
  def claimable? = !redeemed? && !revoked? && !expired?

  def status
    if revoked? then :revoked
    elsif redeemed? then :claimed
    elsif expired? then :expired
    else :waiting
    end
  end

  # Gives the course to user. Returns the enrollment, or nil when the gift
  # can't be claimed (already claimed, ended or expired) or the user already
  # owns the course (the gift then stays unclaimed, so it can go to someone else).
  def redeem!(user)
    with_lock do
      return nil unless claimable?
      return nil if user.enrolled_in?(course)
      enrollment = user.enrollments.find_or_initialize_by(course: course)
      if enrollment.new_record?
        enrollment.update!(source: "gift", gift: self)
      else
        enrollment.reinstate!(source: "gift", gift: self) # access had ended (a refund, or the owner)
      end
      update!(redeemed_at: Time.current, redeemed_by: user)
      enrollment
    end
  end

  # A refund, a dispute or the owner ends the gift, and the access it gave.
  def revoke!(reason)
    transaction do
      update!(revoked_at: Time.current, revoke_reason: reason) unless revoked?
      enrollment&.revoke!(reason)
    end
  end

  # A fresh link for an unclaimed gift (the email was lost, or never sent).
  # The old link stops working.
  def reissue!
    issue_token(force: true)
    self.expires_at = LIFETIME.from_now
    save!
  end

  private
    def issue_token(force: false)
      return if token_digest.present? && !force
      @token = SecureRandom.urlsafe_base64(32)
      self.token_digest = self.class.digest(@token)
      self.expires_at = LIFETIME.from_now if force || expires_at.nil?
    end
end
