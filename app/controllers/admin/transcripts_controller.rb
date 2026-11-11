module Admin
  # The owner pastes TRANSCRIPT.md; only the parsed numbers are kept.
  class TranscriptsController < BaseController
    def show
      @snapshot = current_user.transcript_snapshot
      @records = current_user.course_records
    end

    def create
      TranscriptImport.call(params.require(:markdown), user: current_user)
      announce_badges Badges.award!(current_user)
      redirect_to portal_path, notice: "Transcript synced."
    rescue TranscriptImport::FormatError => e
      redirect_to admin_transcript_path, alert: "That doesn't look like TRANSCRIPT.md: #{e.message}"
    end
  end
end
