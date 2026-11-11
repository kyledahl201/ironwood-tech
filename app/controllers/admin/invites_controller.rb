module Admin
  class InvitesController < BaseController
    def index
      @invites = Invite.order(created_at: :desc).includes(:used_by)
      @invite = Invite.new
    end

    def create
      invite = Invite.create!(created_by: current_user, note: params.dig(:invite, :note).to_s.first(100))
      redirect_to admin_invites_path(new: invite.id), notice: "Invite created. Copy the link and send it to your friend."
    end

    def destroy
      Invite.open.find(params[:id]).update!(expires_at: Time.current)
      redirect_to admin_invites_path, notice: "Invite cancelled."
    end
  end
end
