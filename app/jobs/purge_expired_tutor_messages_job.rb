# Deletes tutor chats older than TutorMessage::RETENTION (stated on /privacy).
class PurgeExpiredTutorMessagesJob < ApplicationJob
  queue_as :default

  def perform
    TutorMessage.expired.in_batches(of: 1_000).delete_all
  end
end
