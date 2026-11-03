# frozen_string_literal: true

# "Add page to set": the Works on a results page, added to one of the viewer's
# Sets after a confirmation that counts what is already there. See
# docs/sets.md ("Adding a page of results").
module SetPageAdd
  extend ActiveSupport::Concern

  # The picker's rows for a whole page rather than one item; each row leads to
  # the confirmation instead of adding at once.
  def page_picker
    @kind = 'page'
    @noid = 'page'
    @work_ids = Array(params[:work_ids]).first(SetPageAddition::MAX_WORKS)
    return head :bad_request if @work_ids.empty?

    @q = params[:q].to_s.strip
    @sets, @pagination = SetPicker.call(query: @q, page: params[:page], owner: impersonated_owner)
    render :picker, layout: false
  end

  def confirm_page_works
    @addition = page_addition
    render layout: false
  end

  # Counted again rather than trusted from the confirmation: the Set may have
  # changed in between, and only what is still missing is queued.
  def add_page_works
    to_add = page_addition.to_add
    return redirect_back_or_to(set_path(@set['id']), notice: "Nothing to add to “#{@set['title']}”.") if to_add.empty?

    SetBulkAddJob.perform_later(set_noid: @set['id'], work_ids: to_add)
    redirect_back_or_to(set_path(@set['id']),
                        notice: "Adding #{helpers.pluralize(to_add.size, 'work')} to “#{@set['title']}”. " \
                                'You will get an Inbox message when they are in.')
  end

  private

    def page_addition
      SetPageAddition.new(compilation: @set, noids: params[:work_ids], search_service: search_service)
    end
end
