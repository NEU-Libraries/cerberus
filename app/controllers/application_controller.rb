class ApplicationController < ActionController::Base
  include ApplicationHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  # Adds Drs behaviors into the application controller
  include Cerberus::Controller
  # Solr Escape group values
  include Cerberus::ControllerHelpers::SolrEscapeGroups
  include Blacklight::CatalogHelperBehavior

  unless Rails.application.config.consider_all_requests_local
    rescue_from Exception, with: lambda { |exception| render_500(exception) }
    rescue_from ActionController::RoutingError, ActionController::UnknownController, ::AbstractController::ActionNotFound, ActiveRecord::RecordNotFound, with: lambda { |exception| render_404(exception, request.fullpath) }
  end
  # Please be sure to impelement current_user and user_session. Blacklight depends on
  # these methods in order to perform user specific actions.

  layout "homepage"

  protect_from_forgery
  before_filter :impersonate_warning
  before_filter :store_location
  after_filter :redirect_blacklight_overrun

  # around_filter :profile

  # def send_file(path, options = {})
  #   if options[:range]
  #     send_file_with_range(path, options)
  #   else
  #     super(path, options)
  #   end
  # end
  #
  # def send_file_with_range(path, options = {})
  #   if File.exist?(path)
  #     size = File.size(path)
  #     if !request.headers["Range"]
  #       status_code = 200 # 200 OK
  #       offset = 0
  #       length = File.size(path)
  #     else
  #       status_code = 206 # 206 Partial Content
  #       bytes = Rack::Utils.byte_ranges(request.headers, size)[0]
  #       offset = bytes.begin
  #       length = bytes.end - bytes.begin
  #     end
  #     options[:status] = status_code
  #     response.header["Accept-Ranges"] = "bytes"
  #     response.header["Content-Range"] = "bytes #{bytes.begin}-#{bytes.end}/#{size}" if bytes
  #     # response.header["Content-Length"] = (bytes.end.to_i - bytes.begin.to_i + 1).to_s if bytes
  #
  #     send_data IO.binread(path, length, offset), options
  #   else
  #     raise ActionController::MissingFile, "Cannot read file #{path}."
  #   end
  # end

  def profile
    if params[:profile] && result = RubyProf.profile { yield }

      out = StringIO.new
      RubyProf::GraphHtmlPrinter.new(result).print out, :min_percent => 0
      self.response_body = out.string

    else
      yield
    end
  end

  def email_handled_exception(exception)
    if !current_user.nil?
      name = current_user.name
    else
      name = "Not Logged In"
    end

    ExceptionNotifier.notify_exception(exception, :env => request.env, :data => {:user => "#{name}"})
  end

  def mint_unique_pid
    Cerberus::Noid.namespaceize(Cerberus::IdService.mint)
  end

  def fetch_core_hash(options = {})
    options = options.with_indifferent_access

    fetch = Proc.new do |pid|
      q = ActiveFedora::SolrService.query("id:\"#{pid}\"").first
      raise ActiveFedora::ObjectNotFoundError if q.nil?
      @core_doc = SolrDocument.new(q)

      result_hsh = Hash.new
      if !params[:solr_only].blank? && params[:solr_only].downcase == "true"
        result_hsh = @core_doc
      else
        if !Rails.cache.exist?("/api/#{@core_doc.pid}-#{@core_doc.updated_at}")
          result_hsh = Rails.cache.fetch("/api/#{@core_doc.pid}-#{@core_doc.updated_at}", :expires_in => 12.hours) do
            @core_file = ActiveFedora::Base.find(pid, cast: true)
            @core_file.to_hash(true) # True is public_only flag - making it adaptable if we move forward with private API access. Feasible now we have auth tokens
          end
        else
          result_hsh = Rails.cache.fetch("/api/#{@core_doc.pid}-#{@core_doc.updated_at}")
        end
      end
      return result_hsh
    end

    if options[:id]
      fetch.call(options[:id])
    else
      fetch.call(params[:id])
    end
  end

  def fetch_solr_document(options = {})
    options = options.with_indifferent_access

    fetch = Proc.new do |x|
      q = ActiveFedora::SolrService.query("id:\"#{x}\"").first
      raise ActiveFedora::ObjectNotFoundError if q.nil?

      return SolrDocument.new(q)
    end

    if options[:id]
      fetch.call(options[:id])
    else
      fetch.call(params[:id])
    end
  end

  def impersonate_warning
    if !session[:impersonate].blank?
      flash[:error] = "#{session[:impersonate]}"
    end
  end

  def store_location
    # store last url - this is needed for post-login redirect to whatever the user last visited.
    return unless request.get?
    if (request.path != "/users/sign_in" &&
        request.path != "/users/sign_up" &&
        request.path != "/users/password/new" &&
        request.path != "/users/sign_out" &&
        request.path != "/users/auth/shibboleth" &&
        request.path != "/users/auth/shibboleth/callback" &&
        !(request.path.include? "/downloads/") &&
        !request.xhr?) # don't store ajax calls
      session[:previous_url] = request.fullpath
    end
  end

  def redirect_blacklight_overrun
    if !@response.blank?
      page_params = paginate_params(@response)
      if !(page_params.num_pages == 0) && page_params.current_page > page_params.num_pages
        # change page param to 1, redirect with response.location and 302
        response.location = request.base_url + request.path + "?" + params.except(:action, :controller).merge(page: 1).to_query
        response.status = 302
      end
    end
  end

  helper_method :current_user_can?

  def current_user_can?(perm_level, record)
    if current_user
      current_user.can? perm_level, record
    elsif perm_level != :read
      false
    else
      record.read_groups.include? 'public'
    end
  end

  def after_sign_in_path_for(resource)
    session[:previous_url] || root_path
  end

  # Some useful helpers for seeing the filters defined on given controllers
  # Taken from: http://scottwb.com/blog/2012/02/16/enumerate-rails-3-controller-filters/
  def self.filters(kind = nil)
    all_filters = _process_action_callbacks
    all_filters = all_filters.select{|f| f.kind == kind} if kind
    all_filters.map(&:filter)
  end

  def self.before_filters
    filters(:before)
  end

  def self.after_filters
    filters(:after)
  end

  def self.around_filters
    filters(:around)
  end

  def apply_per_page_limit(solr_parameters, user_parameters)
    solr_parameters[:rows] = drs_per_page
    user_parameters[:rows] = drs_per_page
  end

  protected
    def authenticate_request!
      # unless user_id_in_token?
      #   render json: { errors: ['Not Authenticated'] }, status: :unauthorized
      #   return
      # end
      if user_id_in_token?
        sign_in(User.find(auth_token[:user_id]))
      end
    rescue JWT::VerificationError, JWT::DecodeError
      render json: { errors: ['Not Authenticated'] }, status: :unauthorized
    end

  private
    def http_token
      # @http_token ||= if request.headers['Authorization'].present?
      #   request.headers['Authorization'].split(' ').last
      # end
      @http_token ||= if params[:token].present?
        params[:token]
      end
    end

    def auth_token
      @auth_token ||= JsonWebToken.decode(http_token)
    end

    def user_id_in_token?
      http_token && auth_token && auth_token[:user_id].to_i
    end
end
