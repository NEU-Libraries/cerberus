class UsersController < ApplicationController

  rescue_from Exceptions::SecurityTamperingError do |exception|
    flash[:error] = exception.message
    email_handled_exception(exception)
    redirect_to root_path and return
  end

  def switch_user
    email = params[:email]
    if current_user.blank?
      # Invalid, notify of account tampering
      raise Exceptions::SecurityTamperingError
    elsif current_user.multiple_accounts
      user = User.find_by_email(email)
      if user.nuid == current_user.nuid
        # Valid choice
        sign_in user, :event => :authentication
        flash[:notice] = "#{t('drs.multiple_accounts.switched_user')} #{email}"
        redirect_to select_account_path and return
      else
        # Invalid, notify of account tampering
        raise Exceptions::SecurityTamperingError
      end
    else
      # Invalid, notify of account tampering
      raise Exceptions::SecurityTamperingError
    end
  end

  def set_preferred_user
    if current_user.multiple_accounts
      users = User.where(:nuid => current_user.nuid)

      users.map do |u|
        u.account_pref = current_user.email
        u.save!
      end

      flash[:notice] = "#{t('drs.multiple_accounts.set_confirmation')} #{current_user.email}"
      redirect_to select_account_path and return
    end
  end

  # Process changes from profile form
  def update

    @user = current_user

    if params[:view_pref].present? || params[:per_page_pref]
      view_pref  = params[:view_pref]
      per_page_pref = params[:per_page_pref]

      #make sure it is only one of these strings
      if view_pref == 'grid' || view_pref == 'list'

        if @user
          unless @user.view_pref == view_pref
            @user.view_pref = view_pref
            @user.save!
          end
        else
          session[:view_pref] = view_pref
        end

      else
        flash[:error] = t('drs.multiple_accounts.preferred_failure')
      end

      if per_page_pref == '10' || per_page_pref == '20' || per_page_pref == '50' || per_page_pref == '100'

        if @user
          unless @user.per_page_pref == per_page_pref
            @user.per_page_pref = per_page_pref
            @user.save!
          end
        else
          session[:per_page_pref] = per_page_pref
        end

      else
        flash[:error] = t('drs.multiple_accounts.preferred_failure')
      end
    end

    respond_to do |format|
      format.html
      format.js
    end

  end

end
