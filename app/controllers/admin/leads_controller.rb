module Admin
  class LeadsController < BaseController
    def index
      @leads = Lead.recent
      @leads = @leads.where(kind: params[:kind]) if Lead::KINDS.include?(params[:kind])
    end

    def update
      lead = Lead.find(params[:id])
      lead.update!(status: params.require(:lead).permit(:status)[:status])
      redirect_to admin_leads_path, notice: "Lead updated."
    end
  end
end
