# One-click newsletter unsubscribe. GET shows a button (so link scanners can't
# unsubscribe people); POST does it.
class UnsubscribesController < ApplicationController
  allow_unauthenticated_access
  before_action :set_lead

  def show; end

  def create
    @lead.update!(status: "unsubscribed")
    redirect_to root_path, notice: "You're unsubscribed. Sorry to see you go."
  end

  private
    def set_lead
      @lead = Lead.find_signed!(params[:token], purpose: :unsubscribe)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to root_path, alert: "That unsubscribe link isn't valid. Email #{brand.contact_email} and we'll remove you."
    end
end
