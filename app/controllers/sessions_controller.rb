class SessionsController < ApplicationController
  skip_before_filter :require_login
  
  def new
  end
  
  def create
    user = User.find_by(name: params[:session][:username])
    if user && user.authenticate(params[:session][:password])
      log_in user
      redirect_to root_path
    else
      flash[:alert] = 'Credenziali errate.'
      render 'new'
    end
  end
  
  def destroy
    log_out
    redirect_to login_path
  end
end
