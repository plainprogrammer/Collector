class Admin::UsersController < ApplicationController
  include AdminOnly

  before_action :set_user, only: %i[edit update destroy]

  def index
    @users = User.order(:name)
    # Admin-only cross-account read (spec 004 AC-5.1): copies per account, in one grouped query.
    @copies = Lot.group(:account_id).sum(:quantity)
    @setting = InstanceSetting.current
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    assign_admin
    if @user.save
      redirect_to admin_users_path, notice: "Added #{@user.name}.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    attributes = user_params
    attributes = attributes.except(:password) if attributes[:password].blank?
    @user.assign_attributes(attributes)
    assign_admin
    if @user.save
      @user.end_sessions! if attributes.key?(:password)
      redirect_to admin_users_path, notice: "Saved.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @user == Current.user
      redirect_to admin_users_path, alert: "You can't delete your own account.", status: :see_other
    else
      @user.destroy!
      redirect_to admin_users_path, notice: "Deleted #{@user.name}'s account.", status: :see_other
    end
  end

  private
    def set_user = @user = User.find(params[:id])

    def user_params = params.expect(user: %i[name email_address password])

    def assign_admin
      @user.admin = params[:user][:admin] == "1" if params[:user]&.key?(:admin)
    end
end
