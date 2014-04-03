class CompilationsController < ApplicationController
  include Drs::ControllerHelpers::EditableObjects

  before_filter :authenticate_user!

  before_filter :can_edit?, only: [:edit, :update, :destroy, :add_file, :delete_file]
  before_filter :can_read?, only: [:show, :show_download, :download]

  load_resource
  before_filter :remove_dead_entries, only: [:show, :show_download]

  def index
    @compilations = Compilation.users_compilations(current_user)
    @page_title = "My " + t('drs.compilations.name').capitalize + "s"
  end

  def new
    @compilation = Compilation.new
    @page_title = "New " + t('drs.compilations.name').capitalize
  end

  def create
    @compilation = Compilation.new(params[:compilation].merge(pid: mint_unique_pid))
    @compilation.depositor = current_user.nuid

    save_or_bust @compilation
  end

  def edit
    @page_title = "Edit #{@compilation.title}"
  end

  def update
    if @compilation.update_attributes(params[:compilation])
      flash[:notice] = "#{t('drs.compilations.name').capitalize} successfully updated."
      redirect_to @compilation
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} failed to update."
    end

  end

  def show
    @page_title = "#{@compilation.title}"

    respond_to do |format|
      format.html{ render action: "show" }
      format.json{ render json: @compilation  }

    end
  end

  def destroy
    if @compilation.destroy
      flash[:notice] = "#{t('drs.compilations.name').capitalize} was successfully destroyed"
      redirect_to compilations_path
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} #{@compilation.title} was not successfully destroyed"
    end
  end

  def add_file
    @compilation.add_entry(params[:entry_id])
    save_or_bust @compilation
  end

  def delete_file
    @compilation.remove_entry(params[:entry_id])
    save_or_bust @compilation
  end

  def ping_download
    respond_to do |format|

      format.js do
        attempts = 25

        until attempts == 0 do
          sleep(2)

          if download_is_ready?(@compilation.pid)
            render("ping_download")
            break
          else
            attempts -= 1
          end
        end
        return
      end
    end
  end

  def show_download
    Sufia.queue.push(ZipCompilationJob.new(current_user, @compilation))
    @page_title = "Download #{@compilation.title}"
  end

  def download
    path_to_dl = Dir["#{Rails.root}/tmp/#{params[:id]}/*"].first
    send_file path_to_dl
  end

  private

  def remove_dead_entries
    dead_entries = @compilation.remove_dead_entries

    if dead_entries.length > 0
      flash.now[:error] = "The following items no longer exist in the repository and have been removed from your #{ t('drs.compilations.name') }: #{dead_entries.join(', ')}"
    end
  end

  def save_or_bust(compilation)
    if compilation.save!
      flash[:notice] = "#{t('drs.compilations.name').capitalize} successfully updated"
      redirect_to compilation
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} was not successfully updated"
    end
  end

  def download_is_ready?(pid)
    path_to_dl = "#{Rails.root}/tmp/#{pid}"
    # check that the directory exists
    if File.directory?(path_to_dl)
      return !Dir["#{path_to_dl}/*"].empty?
    end
  end
end
