# A class's page (a Course): what it covers, and for its owner, every lesson
# in it. Anyone can read what a class covers; its lessons, rubric and content
# open only for its owner (User#can_open?). The list of classes is the
# Programs page now (ProgramsController).
class CoursesController < ApplicationController
  allow_unauthenticated_access only: :show
  allow_customer_accounts

  def show
    @entry = Catalog.new(current_user).find(params[:id]) or raise ActiveRecord::RecordNotFound
    @course = @entry.course
    @lessons = @course&.lessons || []
    @enrollment = @entry.enrollment
    return unless @entry.owned? && @entry.classroom?
    ids = @entry.lessons.map(&:id)
    @progress = current_user.class_progresses.where(class_lesson_id: ids).index_by(&:class_lesson_id)
    @handed_in = current_user.homework_submissions.where(class_lesson_id: ids).group(:class_lesson_id).count
    @studied = current_user.study_records.where(class_lesson_id: ids).index_by(&:class_lesson_id)
    @kit = TutorKit.for(@entry.code)
  end

  def rubric
    @course = Course.published.find_by!(slug: params[:id])
    refuse_course_access(course_path(@course)) unless current_user.can_open?(@course)
  end
end
