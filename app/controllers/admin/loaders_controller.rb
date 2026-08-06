# frozen_string_literal: true

module Admin
  # Admin CRUD for the Loader registry. Each row defines a per-team
  # loader entry point: its Grouper group (members see this loader),
  # its root_collection (where the picker queries children), and
  # display name.
  #
  # Destroy is allowed only for a loader that has never run. Its LoadReports are
  # the audit trail for everything it deposited, and the Work rows they describe
  # outlive the registry entry, so a loader with history is kept rather than
  # soft-deleted — Loader's restrict_with_error is what draws that line. A row
  # created to try the documented steps and never used has nothing to protect.
  class LoadersController < BaseController
    breadcrumb_for 'Loader definitions', :admin_loaders_path

    before_action :set_loader, only: [:edit, :update, :destroy]

    def index
      @loaders = Loader.all
    end

    def new
      @loader = Loader.new
      breadcrumb 'New', new_admin_loader_path
    end

    def edit
      breadcrumb 'Edit', edit_admin_loader_path(@loader)
    end

    def create
      @loader = Loader.new(loader_params)
      if @loader.save
        redirect_to admin_loaders_path, notice: "Loader '#{@loader.slug}' created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @loader.update(loader_params)
        redirect_to admin_loaders_path, notice: "Loader '#{@loader.slug}' updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      slug = @loader.slug
      if @loader.destroy
        redirect_to admin_loaders_path, notice: "Loader '#{slug}' deleted."
      else
        redirect_to admin_loaders_path, alert: undeletable_message(slug)
      end
    end

    private

      def set_loader
        @loader = Loader.find_by!(slug: params[:slug])
      end

      # Say what is holding the loader and why, rather than passing on the
      # association's own "dependent load reports exist" wording.
      def undeletable_message(slug)
        loads = helpers.pluralize(@loader.load_reports.count, 'load')
        "Loader '#{slug}' has #{loads} on record and cannot be deleted. Its load " \
          'history is the audit trail for what it deposited.'
      end

      def loader_params
        params.require(:loader).permit(:slug, :display_name, :group, :root_collection, :kind)
      end
  end
end
