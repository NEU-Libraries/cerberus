class Loaders::MarcomController < ApplicationController
  before_filter :authenticate_user!
  before_filter :verify_group

  def new
    @parent = Community.find("neu:8s45qc00v")
    @collections_options = Array.new
    cols = @parent.child_collections.sort_by{|c| c.title}
    cols.each do |child|
      @collections_options.push([child.title, child.pid])
      children = child.child_collections.sort_by{|c| c.title}
      children.each do |c|
        @collections_options.push([" - #{c.title}", c.pid])
      end
    end
    render 'loaders/new', locals: { collections_options: @collections_options }
  end

  def create
  end

  def show
  end

  private

    def verify_group
      # if user is not part of the marcom_loader grouper group, bounce them
    end
end
