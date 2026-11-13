class GiftMailer < ApplicationMailer
  # gift.token is only in memory right after the gift is made or a new link
  # is issued, so the token is passed in by the caller.
  def claim(gift, token)
    @gift = gift
    @course = gift.course
    @from = gift.purchaser&.name
    @url = gift_claim_url(token)
    mail to: gift.recipient_email, subject: "#{@from || brand_name} gave you #{@course.title}"
  end

  private
    def brand_name = Rails.configuration.x.brand.name
end
