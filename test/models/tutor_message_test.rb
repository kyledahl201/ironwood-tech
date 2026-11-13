require "test_helper"
require "rake"

class TutorMessageTest < ActiveSupport::TestCase
  # The container runs this task at every start (bin/docker-entrypoint).
  test "tutor:purge_expired deletes chats past retention and keeps the rest" do
    old = TutorMessage.create!(user: users(:one), lesson: lessons(:free_one), role: "user", content: "old",
                               created_at: (TutorMessage::RETENTION + 1.day).ago)
    recent = TutorMessage.create!(user: users(:one), lesson: lessons(:free_one), role: "user", content: "recent")

    Rails.application.load_tasks unless Rake::Task.task_defined?("tutor:purge_expired")
    Rake::Task["tutor:purge_expired"].reenable
    Rake::Task["tutor:purge_expired"].invoke

    assert_not TutorMessage.exists?(old.id)
    assert TutorMessage.exists?(recent.id)
  end
end
