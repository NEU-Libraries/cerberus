class Loaders::ModsSpreadsheetLoadsController < Loaders::LoadsController
  before_filter :verify_group
  require 'stanford-mods'
  include ModsDisplay::ControllerExtension

  def new
    query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:\"Collection\"", :fl => "id, title_tesim", :rows => 999999999, :sort => "id asc")
    @collections_options = Array.new()
    query_result.each do |c|
      if current_user.can?(:edit, c['id'])
        @collections_options << {'label' => "#{c['id']} - #{c['title_tesim'][0]}", 'value' => c['id']}
      end
    end
    @loader_name = t('drs.loaders.'+t('drs.loaders.mods_spreadsheet.short_name')+'.long_name')
    @loader_short_name = t('drs.loaders.mods_spreadsheet.short_name')
    @page_title = @loader_name + " Loader"
    render 'loaders/new', locals: { collections_options: @collections_options}
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
    process_create(permissions, t('drs.loaders.mods_spreadsheet.short_name'), "ModsSpreadsheetLoadsController")
  end

  def preview
    @core_file = CoreFile.first #TODO: hook this in the with the job, just hardcoded for now
    @mods_html = render_mods_display(CoreFile.find(@core_file.pid)).to_html.html_safe
    @report = Loaders::LoadReport.find(params[:id])
    @user = User.find_by_nuid(@report.nuid)
    @collection_title = ActiveFedora::SolrService.query("id:\"#{@report.collection}\"", :fl=>"title_tesim")
    @collection_title = @collection_title[0]['title_tesim'][0]
    if @collection_title.blank?
      @collection_title = "N/A"
    end
    render 'loaders/preview'
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.mods_spreadsheet_loader?
    end
end
