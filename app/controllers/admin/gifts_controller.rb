module Admin
  # "Gift a course": the owner sends any course (sold or not, published or
  # not) to an email address. The recipient gets the same one-time claim link
  # as a bought gift, even when they already have an account, so every gift
  # works the same way. When email isn't set up, the link is shown here once
  # for the owner to send by hand.
  class GiftsController < BaseController
    def index
      load_page
    end

    def create
      course = Course.find(params[:course_id])
      gift = Gift.new(course: course, recipient_email: params[:recipient_email].to_s, created_by: current_user)
      if gift.save
        send_link(gift, "Gift made: #{course.title} for #{gift.recipient_email}.")
      else
        flash.now[:alert] = "That gift couldn't be made: #{gift.errors.full_messages.to_sentence}."
        load_page
        render :index, status: :unprocessable_entity
      end
    end

    # A fresh link for a gift that hasn't been claimed. The old link stops working.
    def reissue
      gift = Gift.find(params[:id])
      return redirect_to admin_gifts_path, alert: "Only a gift that's still waiting can get a new link." if gift.redeemed? || gift.revoked?
      gift.reissue!
      send_link(gift, "New link made for #{gift.recipient_email}. The old link no longer works.")
    end

    # Ends the gift, and the access it gave if it was claimed. No money moves:
    # refund a bought gift in the Stripe dashboard.
    def revoke
      gift = Gift.find(params[:id])
      gift.revoke!("owner")
      redirect_to admin_gifts_path, notice: "The gift of #{gift.course.title} to #{gift.recipient_email} has ended."
    end

    private
      def load_page
        @gifts = Gift.includes(:course, :purchaser, :redeemed_by).newest_first.limit(200)
        @courses = Course.order(:position)
      end

      def send_link(gift, done)
        if EmailDelivery.deliver(GiftMailer.claim(gift, gift.token))
          gift.update!(emailed_at: Time.current)
          redirect_to admin_gifts_path, notice: "#{done} We emailed the link."
        else
          # The token exists only now, so the page is drawn here instead of redirecting.
          @claim_link = gift_claim_url(gift.token)
          @claim_gift = gift
          flash.now[:notice] = "#{done} #{EmailDelivery.enabled? ? "The email didn't go out" : "Email isn't set up yet, so nothing was sent"}. Send the link below yourself."
          load_page
          render :index
        end
      end
  end
end
