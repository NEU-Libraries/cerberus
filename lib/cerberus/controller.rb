module Cerberus::Controller
  extend ActiveSupport::Concern

  included do
    # Adds Hydra behaviors into the application controller
    include Hydra::Controller::ControllerBehavior

    before_filter :notifications_number
    helper_method :groups

  end

  def current_ability
    user_signed_in? ? current_user.ability : super
  end

  def groups
    @groups ||= user_signed_in? ? current_user.groups : []
  end

  def render_403
    render :template => '/error/403', :layout => "error", :formats => [:html], :status => 403
  end

  def render_404(exception, path="")
    logger.error("Rendering 404 page for #{path if path != ""} due to exception: #{exception.inspect} - #{exception.backtrace if exception.respond_to? :backtrace}")
    render :template => '/error/404', :layout => "error", :formats => [:html], :status => 404
  end

  def render_410(exception)
    logger.error("Rendering the 410 page due to exception: #{exception.inspect} - #{exception.backtrace if exception.respond_to? :backtrace}")
    render :template => '/error/410', :layout => "error", :formats => [:html], :status => 410
  end

  def render_500(exception)
    logger.error("Rendering 500 page due to exception: #{exception.inspect} - #{exception.backtrace if exception.respond_to? :backtrace}")
    ExceptionNotifier.notify_exception(exception, :env => request.env)
    render :template => '/error/500', :layout => "error", :formats => [:html], :status => 500
  end

  def notifications_number
    @notify_number=0
    @batches=[]
    return if action_name == "index" && controller_name == "mailbox"
    if user_signed_in?
      @notify_number= current_user.mailbox.inbox(:unread => true).count
      @batches=current_user.mailbox.inbox.map {|msg| msg.last_message.body[/<span class="batchid ui-helper-hidden">(.*)<\/span>The file(.*)/,1]}.select{|val| !val.blank?}
    end
  end

  # This repeats has_search_parameters? method from Blacklight::CatalogHelperBehavior
  def has_search_parameters?
    !params[:q].blank? or !params[:f].blank? or !params[:search_field].blank?
  end

end
