# Generates the tutor's reply off the request and streams it into the page.
class TutorReplyJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(placeholder_id)
    placeholder = TutorMessage.find(placeholder_id)
    return unless placeholder.pending?

    lesson = placeholder.lesson
    reply = Tutor.new(course: lesson.course, lesson: lesson, user: placeholder.user).reply
    placeholder.update!(content: reply, pending: false)
    placeholder.broadcast_replace_to [ placeholder.user, lesson ],
      partial: "learn/tutor_messages/tutor_message", locals: { tutor_message: placeholder }
  end
end
