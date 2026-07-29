# frozen_string_literal: true

module Admin
  # CRUD for Group display names — the cosmetic label paired with a Grouper
  # group's raw colon-separated identifier. A row renames the group
  # everywhere ApplicationController#pretty_group resolves it; deleting a row is
  # safe (pretty_group falls back to the raw string), so unlike the Loader
  # registry this surface keeps destroy. Reachable by :admin and by the
  # devolved-admin tier (User#admin_delegate?) — purely local ActiveRecord
  # CRUD, no Atlas dependency either way.
  class GroupsController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    PER_PAGE = 25

    breadcrumb_for 'Group names', :admin_groups_path

    before_action :set_group, only: %i[edit update destroy]

    def index
      @groups = Group.page(params[:page]).per(PER_PAGE)
    end

    def new
      @group = Group.new
      breadcrumb 'New', new_admin_group_path
    end

    def edit
      breadcrumb 'Edit', edit_admin_group_path(@group)
    end

    def create
      @group = Group.new(group_params)
      if @group.save
        redirect_to admin_groups_path, notice: "Display name for '#{@group.raw}' created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @group.update(group_params)
        redirect_to admin_groups_path, notice: "Display name for '#{@group.raw}' updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @group.destroy
      redirect_to admin_groups_path, notice: "Display name for '#{@group.raw}' removed."
    end

    private

      def set_group
        @group = Group.find(params[:id])
      end

      def group_params
        params.require(:group).permit(:raw, :cosmetic)
      end
  end
end
