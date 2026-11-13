# Starting a free course just creates the enrollment. A sold course is bought
# in the store instead (CheckoutsController).
class EnrollmentsController < ApplicationController
  def create
    course = Course.published.find_by!(slug: params[:course_id])
    return redirect_to store_course_path(course) if course.paid?
    enrollment = current_user.enrollments.find_or_create_by!(course: course) { |e| e.source = "self" }
    return redirect_to course_path(course), alert: "Your access to #{course.title} has ended." unless enrollment.active?
    redirect_to learn_lesson_path(course, 1), notice: "#{course.title}: lesson 1. Take it one step at a time."
  end
end
