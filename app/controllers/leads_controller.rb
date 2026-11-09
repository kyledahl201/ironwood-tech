class LeadsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to root_path, alert: "Too many submissions. Try again later." }

  def new
    @lead = Lead.new(kind: "consulting")
  end

  def create
    @lead = Lead.new(lead_params)
    if @lead.save
      notice = @lead.kind == "newsletter" ? "You're on the list. Watch your inbox." : "Thanks. #{brand.founder} will reply within #{brand.reply_days} business days."
      redirect_to(@lead.kind == "newsletter" ? root_path : consulting_path, notice: notice)
    elsif @lead.kind == "newsletter"
      redirect_to root_path(anchor: "newsletter"), alert: "Please enter a valid email address."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def lead_params
      params.require(:lead).permit(:name, :email, :company, :job_title, :message, :kind)
    end
end
