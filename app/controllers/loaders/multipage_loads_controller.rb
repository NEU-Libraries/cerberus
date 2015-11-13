class Loaders::MultipageLoadsController < Loaders::LoadsController
  before_filter :verify_group

  def new
    query_result = ActiveFedora::SolrService.query("active_fedora_model_ssi:\"Collection\"", :fl => "id, title_tesim", :rows => 999999999)
    @collections_options = Array.new()
    query_result.each do |c|
      if current_user.can?(:edit, c['id'])
        @collections_options << {'label' => c['title_tesim'][0], 'value' => c['id']}
      end
    end
    @loader_name = t('drs.loaders.'+t('drs.loaders.multipage.short_name')+'.long_name')
    @loader_short_name = t('drs.loaders.multipage.short_name')
    @page_title = @loader_name + " Loader"
    render 'loaders/new', locals: { collections_options: @collections_options}
  end

  def create
    permissions = {"CoreFile" => {"read"  => ["public"], "edit" => ["northeastern:drs:repository:staff"]}}
    process_create(permissions, t('drs.loaders.multipage.short_name'), "MultipageLoadsController")
  end

  private

    def verify_group
      redirect_to new_user_session_path if current_user.nil?
      redirect_to root_path unless current_user.multipage_loader?
    end
end
