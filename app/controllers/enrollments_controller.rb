# Every course is free: starting one just creates the enrollment.
class EnrollmentsController < ApplicationController
  def create
    course = Course.published.find_by!(slug: params[:course_id])
    current_user.enrollments.find_or_create_by!(course: course) { |e| e.source = "self" }
    redirect_to learn_lesson_path(course, 1), notice: "#{course.title}: lesson 1. Take it one step at a time."
  end
end
