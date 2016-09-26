class Loaders::XmlLoadsController < Loaders::LoadsController
  before_filter :verify_group
  require 'stanford-mods'
  include ModsDisplay::ControllerExtension
  configure_mods_display do
    subject do
      delimiter " -- "
    end
  end


  def new
    @loader_name = t('loaders.'+t('loaders.xml.short_name')+'.long_name')
    @loader_short_name = t('loaders.xml.short_name')
    @page_title = @loader_name + " Loader"
    u_groups = current_user.groups
    groups = u_groups.map! { |g| "\"#{g}\""}.join(" OR ")
    query_result = solr_query("(depositor_tesim:\"#{current_user.nuid}\" OR edit_access_group_ssim:(#{groups})) AND has_model_ssim:\"#{ActiveFedora::SolrService.escape_uri_for_query "info:fedora/afmodel:Collection"}\"")
    @collections_options = Array.new()
    query_result.each do |c|
      @collections_options << {'label' => "#{c['id']} - #{c['title_info_title_tesim'][0]}", 'value' => c['id']}
    end
    @new = "true"
    @new_form = render_to_string(:partial=>'/loaders/new', locals: {collections_options: @collections_options, new: @new})
    @new = "false"
    @existing_form = render_to_string(:partial=>'/loaders/new', locals: {collections_options: [], new: @new})
    render 'loaders/load_choices', locals: { collections_options: @collections_options }
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
    if params[:new] == "true"
      existing_files = false
    else
      existing_files = true
    end
    process_create(permissions, t('loaders.xml.short_name'), "XmlLoadsController", existing_files)
  end

  def preview
    @report = Loaders::LoadReport.find(params[:id])

    @core_file = CoreFile.find(@report.preview_file_pid)
    @mods_html = CoreFilesController.new.render_mods_display(@core_file).to_html.html_safe

    @user = User.find_by_nuid(@report.nuid)
    @collection = fetch_solr_document({:id=>@report.collection})
    collection_depositor = !@collection.true_depositor.blank? ? User.find_by_nuid("#{@collection.true_depositor}").name : nil
    @depositor_options = [["System User", "000000000"]]
    if !collection_depositor.blank? && @collection.true_depositor != "000000000"
      @depositor_options << [collection_depositor, @collection.true_depositor]
    end

    @loader_short_name = t('loaders.xml.short_name')

    render 'loaders/preview'
  end

  def preview_compare
    @report = Loaders::LoadReport.find(params[:id])

    @core_file = CoreFile.find(@report.preview_file_pid)
    old_core = CoreFile.find(@report.comparison_file_pid)

    @diff = mods_diff(old_core, @core_file)
    @diff_css = Diffy::CSS
    @mods_html = CoreFilesController.new.render_mods_display(@core_file).to_html.html_safe

    @user = User.find_by_nuid(@report.nuid)
    @collection = fetch_solr_document({:id=>@report.collection})
    collection_depositor = !@collection.true_depositor.blank? ? User.find_by_nuid("#{@collection.true_depositor}").name : nil
    @depositor_options = [["System User", "000000000"]]
    if !collection_depositor.blank? && @collection.true_depositor != "000000000"
      @depositor_options << [collection_depositor, @collection.true_depositor]
    end

    @loader_short_name = t('loaders.xml.short_name')

    render 'loaders/preview'
  end

  def cancel_load
    @report = Loaders::LoadReport.find(params[:id])
    if !@report.preview_file_pid.blank?
      cf = CoreFile.find(@report.preview_file_pid)
      FileUtils.rm(cf.tmp_path)
      cf.destroy
    end
    @report.destroy
    session[:flash_success] = "Your load has been cancelled."
    redirect_to "/my_loaders"
  end

  def proceed_load
    @report = Loaders::LoadReport.find(params[:id])
    @loader_name = t('loaders.xml.long_name')
    if !@report.preview_file_pid.blank?
      cf = CoreFile.find(@report.preview_file_pid)
      spreadsheet_file_path = cf.tmp_path
    elsif !@report.comparison_file_pid.blank?
      cf = CoreFile.find(@report.comparison_file_pid)
      spreadsheet_file_path = cf.tmp_path
    end
    copyright = t('loaders.xml.copyright')
    if params[:depositor]
      depositor = params[:depositor]
      existing_files = false
    else
      depositor = nil
      existing_files = true
    end
    Cerberus::Application::Queue.push(ProcessXmlZipJob.new(@loader_name, spreadsheet_file_path, @report.collection, copyright, current_user, @report.id, existing_files, depositor, nil))
    flash[:notice] = "Your spreadsheet is being processed. The information on this page will be updated periodically until the processing is completed."
    redirect_to "/loaders/xml/report/#{@report.id}"
  end

  def show_mods
    @item = Loaders::ItemReport.find(params[:id])
    @load = Loaders::LoadReport.find(@item.load_report_id)
    @page_title = @item.original_file
    render 'loaders/mods_xml', locals: {item: @item, load: @load}
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.xml_loader?
    end

    def mods_diff(core_file_a, core_file_b)
      mods_a = Nokogiri::XML(core_file_a.mods.content).to_s
      mods_b = Nokogiri::XML(core_file_b.mods.content).to_s
      return Diffy::Diff.new(mods_a, mods_b, :include_plus_and_minus_in_html => true, :context => 1).to_s(:html).html_safe
    end

end
