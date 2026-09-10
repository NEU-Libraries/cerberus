# frozen_string_literal: true

require 'rails_helper'

# The guard in front of a Collection permissions save that takes audience away.
# It earns a browser spec on stakes rather than on complexity: the save cascades
# to everything inside the collection and cannot be undone, so a confirmation
# that silently stops appearing is a data-loss bug that no server-side spec
# would notice. The server applies the same rule either way, so what is under
# test here is the warning, not the outcome.
RSpec.describe 'Narrowing a collection asks first', :browser, type: :system do
  before(:all) do
    Current.nuid = admin_nuid
    @collection = public_collection_holding_a_work
  end

  before do
    sign_in_as(admin_nuid)
    visit "#{edit_collection_path(@collection.id)}#permissions"
    expect(page).to have_css('#permissions.active')
  end

  it 'leaves a public collection alone while nothing has narrowed' do
    expect(page).to have_select('mass', selected: 'Public')
    expect(confirm_message).to be_nil
  end

  it 'arms the confirmation as soon as the audience narrows' do
    select 'Private', from: 'mass'

    expect(confirm_message).to include('will be restricted to match it')
    expect(confirm_message).to include('Re-opening the collection later will not undo this')
  end

  it 'blocks the save behind the confirmation dialog' do
    select 'Private', from: 'mass'
    submit_permissions

    wait_for_confirm_dialog
    expect(page).to have_content('Restrict this collection?')
    expect(page).to have_button('Restrict')
  end

  it 'stays on the form when the confirmation is declined' do
    select 'Private', from: 'mass'
    submit_permissions
    wait_for_confirm_dialog

    click_button 'Cancel'

    expect(page).to have_no_css('.modal.show')
    # Still on the edit page with the choice as it was left, which is what
    # "declined" has to mean: the cascade never started.
    expect(page).to have_select('mass', selected: 'Private')
  end

  # --- helpers ---------------------------------------------------------------

  # The visibility select only renders when the parent allows public. The Work
  # inside is what gives the warning something to count.
  def public_collection_holding_a_work
    collection = create_collection(create_community(public: true).id, public: true)
    create_work(collection.id, public: true)
    collection
  end

  # The controller arms the guard by writing data-turbo-confirm onto the form,
  # so reading the attribute is how a spec sees the decision it made.
  def confirm_message
    page.evaluate_script(
      "document.querySelector(\"form[data-narrowing-confirm-target='form']\").dataset.turboConfirm || null"
    )
  end

  def submit_permissions
    find("form[data-narrowing-confirm-target='form'] [type='submit']").click
  end

  # Bootstrap ignores hide() while the show transition is still running, so a
  # dismissal sent too early is dropped and the dialog just stays open. The
  # confirm button takes focus on shown.bs.modal, which makes it the signal that
  # the transition has finished and the dialog is ready to be answered.
  def wait_for_confirm_dialog
    expect(page).to have_css('.modal.show')
    expect(page).to have_css('.modal.show .modal-footer .btn:not(.btn-secondary):focus')
  end
end
