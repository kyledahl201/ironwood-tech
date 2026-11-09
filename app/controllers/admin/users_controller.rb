module Admin
  class UsersController < BaseController
    def index
      @users = User.order(created_at: :desc).includes(enrollments: :course)
    end

    def show
      @user = User.find(params[:id])
      @courses = Course.order(:position)
    end
  end
end
