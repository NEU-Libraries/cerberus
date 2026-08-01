# frozen_string_literal: true

require 'rails_helper'

describe 'shared/_group_permissions.html.haml' do
  def grant(group_id, ability, revocable)
    Permissions::GrantRow.new(group_id: group_id, label: group_id.titleize,
                              ability: ability, revocable: revocable)
  end

  def render_with(*rows, picker: [%w[librarians Librarians]])
    assign(:permissions, rows)
    assign(:groups, picker)
    render partial: 'shared/group_permissions', locals: { resource: 'work' }
  end

  context 'with a revocable grant' do
    before { render_with(grant('librarians', 'read', true)) }

    it 'renders both selects and a remove button' do
      expect(rendered).to have_css('select.groups[name="work[permissions][1][group_id]"]')
      expect(rendered).to have_css('select.ability[name="work[permissions][1][ability]"]')
      expect(rendered).to have_css('button[aria-label="Remove group"]')
    end

    it 'preselects the row’s current ability' do
      expect(rendered).to have_css('select.ability option[value="read"][selected]', text: 'View')
    end

    it 'omits the locked-grant footnote' do
      expect(rendered).not_to include('granted access by someone else')
    end
  end

  context 'with a non-revocable grant' do
    before { render_with(grant('curators', 'edit', false)) }

    # The three ways the form could otherwise attempt a removal Atlas would undo:
    # the remove button, swapping the row's group, and flipping its ability.
    # Scoped to the row — the form's own "add a group" entry row keeps its
    # selects and the template keeps its button, which is correct.
    it 'renders no remove button on the row' do
      expect(rendered).not_to have_css('#group-list_1 button[aria-label="Remove group"]', visible: :all)
    end

    it 'renders neither select, so the group and ability cannot be swapped' do
      expect(rendered).not_to have_css('#group-list_1 select.groups', visible: :all)
      expect(rendered).not_to have_css('#group-list_1 select.ability', visible: :all)
    end

    it 'never exposes the locked group as an option in any select' do
      expect(rendered).not_to have_css('option[value="curators"]', visible: :all)
    end

    # Submitting the grant as displayed keeps the wire payload honest, rather
    # than relying on Atlas to merge an omitted grant back in.
    it 'submits the grant as hidden fields under the row’s index' do
      expect(rendered).to have_css(
        '#group-list_1 input[type=hidden][name="work[permissions][1][group_id]"][value="curators"]',
        visible: :all
      )
      expect(rendered).to have_css(
        '#group-list_1 input[type=hidden][name="work[permissions][1][ability]"][value="edit"]',
        visible: :all
      )
    end

    it 'states the group, its ability, and the locked marker as text' do
      expect(rendered).to include('Curators')
      expect(rendered).to include('Manage')
      expect(rendered).to include('Locked')
      expect(rendered).to have_css('i.fa-lock')
    end

    it 'explains once who can remove it' do
      expect(rendered).to include('Some groups above were granted access by someone else.')
    end
  end

  context 'with a mix of revocable and locked grants' do
    before { render_with(grant('librarians', 'read', true), grant('curators', 'edit', false)) }

    # Row indices are positional over every row, and the Stimulus controller
    # seeds its next index from the rendered row count — so a locked row must
    # still occupy both an index and a "row" target or a JS-added row collides.
    it 'indexes locked and editable rows in one positional sequence' do
      expect(rendered).to have_css('select.groups[name="work[permissions][1][group_id]"]')
      expect(rendered).to have_css(
        'input[type=hidden][name="work[permissions][2][group_id]"]', visible: :all
      )
    end

    it 'counts both rows as Stimulus row targets' do
      expect(rendered).to have_css("[data-group-permissions-target='row']", count: 2, visible: :all)
    end

    it 'shows the footnote once, not per locked row' do
      expect(rendered.scan('granted access by someone else').length).to eq(1)
    end
  end
end
