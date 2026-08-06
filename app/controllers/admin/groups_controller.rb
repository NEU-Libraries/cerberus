# frozen_string_literal: true

module Admin
  # CRUD for Group display names — the cosmetic label paired with a Grouper
  # group's raw colon-separated identifier. A row renames the group
  # everywhere ApplicationController#pretty_group resolves it; deleting a row is
  # safe (pretty_group falls back to the raw string), so unlike the Loader
  # registry this surface keeps destroy. :admin-only — deliberately kept out
  # of the devolved-admin tier (librarian call: naming/renaming groups
  # system-wide stays a full-admin action even though it has no Atlas
  # dependency either way).
  class GroupsController < BaseController
    PER_PAGE = 25

    breadcrumb_for 'Group names', :admin_groups_path

    before_action :set_group, only: %i[edit update destroy]

    # `@total` is the unfiltered size, carried separately from
    # `@groups.total_count` so the header can read "3 of 159 entries" during a
    # search. A bare filtered count leaves an admin unable to tell a narrow
    # match from a registry that has lost rows.
    def index
      @query  = params[:q].to_s.strip
      @total  = Group.count
      @groups = Group.search(@query).page(params[:page]).per(PER_PAGE)
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
