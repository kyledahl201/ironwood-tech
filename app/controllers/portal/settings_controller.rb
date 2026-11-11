module Portal
  class SettingsController < ApplicationController
    def update
      current_user.update!(params.require(:user).permit(:share_in_study_hall))
      redirect_to portal_path(anchor: "study-hall"), notice: current_user.share_in_study_hall? ? "You're in the study hall." : "You've left the study hall."
    end
  end
end
