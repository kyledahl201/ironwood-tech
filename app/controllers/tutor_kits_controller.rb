# Hands a signed-in student a course's tutor kit: the whole kit as one .zip,
# or one of its files (for the notes of a week that has just opened).
class TutorKitsController < ApplicationController
  before_action :set_kit

  def show
    send_data @kit.zip, filename: @kit.filename, type: "application/zip", disposition: "attachment"
  end

  def file
    path = @kit.files.find { |candidate| File.basename(candidate) == params[:file] } or return head :not_found
    send_data File.read(path), filename: File.basename(path), type: "text/markdown; charset=utf-8", disposition: "attachment"
  end

  private
    def set_kit
      @kit = TutorKit.find(params[:course]) or head :not_found
    end
end
