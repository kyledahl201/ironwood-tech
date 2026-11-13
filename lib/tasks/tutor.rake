namespace :tutor do
  desc "Delete tutor chats older than TutorMessage::RETENTION (the promise on /privacy)"
  task purge_expired: :environment do
    PurgeExpiredTutorMessagesJob.perform_now
  end
end
