# frozen_string_literal: true

require 'rails_helper'

# The picker's "New set" link has to carry the item and the page it was opened
# on; without them the new set came out empty and the user did not come back.
describe 'sets/_picker_modal.html.haml' do
  it 'links New set with the item and a return to this page' do
    allow(view.request).to receive(:fullpath).and_return('/catalog?q=boats')

    render partial: 'sets/picker_modal', locals: { kind: 'work', noid: 'abc123' }

    link = Capybara.string(rendered).find_link('New set')
    expect(link[:href]).to eq(new_set_path(work_id: 'abc123', return_to: '/catalog?q=boats'))
    expect(link['data-turbo-frame']).to eq('_top')
  end
end
