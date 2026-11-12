# The course list: every course, what it covers, and a button into it.
class CoursesController < ApplicationController
  def index
    @entries = Catalog.new(current_user).entries
  end

  def show
    @entry = Catalog.new(current_user).find(params[:id]) or raise ActiveRecord::RecordNotFound
    @course = @entry.course
    @lessons = @course&.lessons || []
    @enrollment = @entry.enrollment
    return unless @entry.classroom?
    ids = @entry.lessons.map(&:id)
    @progress = current_user.class_progresses.where(class_lesson_id: ids).index_by(&:class_lesson_id)
    @handed_in = current_user.homework_submissions.where(class_lesson_id: ids).group(:class_lesson_id).count
    @studied = current_user.study_records.where(class_lesson_id: ids).index_by(&:class_lesson_id)
    @kit = TutorKit.for(@entry.code)
  end

  def rubric
    @course = Course.published.find_by!(slug: params[:id])
  end
end
