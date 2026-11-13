module Admin
  class UsersController < BaseController
    def index
      @users = User.order(created_at: :desc).includes(enrollments: :course)
    end

    def show
      @user = User.find(params[:id])
      @courses = Course.order(:position)
    end

    # The one thing the owner changes here: whether an account made by buying
    # a course may use the whole portal, like an invited student.
    def update
      user = User.find(params[:id])
      user.update!(customer_only: params.dig(:user, :customer_only) == "1")
      redirect_to admin_user_path(user), notice: "#{user.name}: #{user.customer_only? ? 'store and purchases only' : 'the whole portal'}."
    end
  end
end
