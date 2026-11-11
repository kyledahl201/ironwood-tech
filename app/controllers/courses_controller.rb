class CoursesController < ApplicationController
  def index
    @courses = Course.published.includes(:lessons)
    @enrollments = current_user.enrollments.includes(:lesson_completions).index_by(&:course_id)
  end

  def show
    @course = Course.published.find_by!(slug: params[:id])
    @lessons = @course.lessons
    @enrollment = current_user.enrollments.includes(:lesson_completions).find_by(course: @course)
  end

  def rubric
    @course = Course.published.find_by!(slug: params[:id])
  end
end
