class Admin::UsersController < AdminController

  before_filter :authenticate_user!
  before_filter :verify_admin

  def index
    @users = User.paginate(:page => params[:page], :per_page => 10)
  end
end
