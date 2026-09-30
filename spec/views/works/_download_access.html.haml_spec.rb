# frozen_string_literal: true

require 'rails_helper'

# A collection's derivative policy reaches a Work at ingest, but nothing on the
# Work's own Edit page showed it, so a tester checking there concluded it had
# not arrived. The section is read-only: the policy is changed where it is set.
RSpec.describe 'works/_download_access', type: :view do
  def render_policy(policy)
    render partial: 'works/download_access', locals: { policy: policy }
    Capybara.string(rendered)
  end

  it 'lists each limited file type, in ladder order, with who may download it' do
    page = render_policy('large' => ['northeastern:drs:nupd:media'], 'small' => ['public'])

    expect(page.all('dt').map(&:text)).to eq(['Small image', 'Large image'])
    expect(page).to have_css('dd', text: 'Public')
  end

  it 'says a tier limited to no one is withheld, rather than drawing an empty cell' do
    expect(render_policy('original' => [])).to have_css('dd', text: 'Withheld from everyone')
  end

  it 'says every file follows the general permissions when there is no policy' do
    expect(render_policy(nil)).to have_text('Every file follows this work')
  end

  it 'offers no control to edit it' do
    expect(render_policy('small' => ['public'])).to have_no_css('input, select, button')
  end
end
