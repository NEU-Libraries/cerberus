# frozen_string_literal: true

module Admin
  # Admin CRUD for the Loader registry. Each row defines a per-team
  # loader entry point: its Grouper group (members see this loader),
  # its root_collection (where the picker queries children), and
  # display name. Destroy is intentionally omitted in this pass —
  # retiring a loader needs a soft-delete + dangling-LoadReport
  # decision that's out of scope for piece 4.
  class LoadersController < BaseController
    before_action :set_loader, only: [:edit, :update]

    def index
      @loaders = Loader.all
    end

    def new
      @loader = Loader.new
    end

    def edit; end

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

    private

      def set_loader
        @loader = Loader.find_by!(slug: params[:slug])
      end

      def loader_params
        params.require(:loader).permit(:slug, :display_name, :group, :root_collection)
      end
  end
end
