# Hands a student who owns the course its tutor kit: the whole kit as one
# .zip, or one of its files (for the notes of a week that has just opened).
class TutorKitsController < ApplicationController
  allow_customer_accounts
  before_action :set_kit

  def show
    send_data @kit.zip, filename: @kit.filename, type: "application/zip", disposition: "attachment"
  end

  def file
    text = @kit.read(params[:file]) or return head :not_found
    send_data text, filename: params[:file], type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  private
    def set_kit
      @kit = TutorKit.find(params[:course]) or return head :not_found
      head :forbidden unless current_user.can_open_code?(@kit.course_code)
    end
end
