module Cerberus::Controller
  extend ActiveSupport::Concern

  included do
    # Adds Hydra behaviors into the application controller
    include Hydra::Controller::ControllerBehavior

    before_filter :notifications_number
    helper_method :groups

  end

  def current_ability
    if !current_api_user.blank?
      current_api_user.ability
    else
      user_signed_in? ? current_user.ability : super
    end
  end

  def groups
    @groups ||= user_signed_in? ? current_user.groups : []
  end

  def render_403
    if current_user.nil?
      redirect_to new_user_session_path
    else
      render :template => '/error/403', :layout => "error", :formats => [:html], :status => 403
    end
  end

  def render_404(exception, path="")
    logger.error("Rendering 404 page for #{path if path != ""} due to exception: #{exception.inspect} - #{exception.backtrace if exception.respond_to? :backtrace}")
    render :template => '/error/404', :layout => "error", :formats => [:html], :status => 404
  end

  def render_410(exception)
    @page_title = "File Removed"
    logger.error("Rendering the 410 page due to exception: #{exception.inspect} - #{exception.backtrace if exception.respond_to? :backtrace}")
    if !params[:id].blank?
      record = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{params[:id]}\"").first)
    end
    render :template => '/error/410', :layout => "error", :formats => [:html], :status => 410, locals: {record:record}
  end

  def render_500(exception)
    logger.error("Rendering 500 page due to exception: #{exception.inspect} - #{exception.backtrace if exception.respond_to? :backtrace}")
    if !current_user.nil?
      ExceptionNotifier.notify_exception(exception, :env => request.env, :data => {:user => "#{current_user.name}"})
    end
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
    !params[:q].blank? or !params[:f].blank? or !params[:search_field].blank? or !(params[:q] == "*" && current_user.nil?)
  end

end
