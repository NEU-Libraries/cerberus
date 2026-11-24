# frozen_string_literal: true

require 'rails_helper'

# The apply script holds every Turbo render until the deferred stylesheets have
# settled. The page's own copy ran before the spec could watch it, and against
# files the browser may have cached, so each example runs a fresh copy over two
# probe links that have to come from the network. docs/critical-css.md covers
# the script.
RSpec.describe 'The deferred layout stylesheets', :browser, :critical_css, type: :system do
  before do
    allow(Rails.application.config.x.cerberus).to receive(:terms_document_url).and_return(nil)
  end

  # Hands the deferred marker from the page's links to uncached copies, then
  # runs the apply script over them, as a full page load would.
  def run_apply_script_over_probes
    page.execute_script(<<~JS, StylesheetsHelper::APPLY_DEFERRED)
      const marked = [...document.querySelectorAll('link[data-deferred-stylesheet]')];
      marked.forEach((link) => {
        link.removeAttribute('data-deferred-stylesheet');
        const href = `${link.href}?probe=${Date.now()}`;
        const probe = Object.assign(document.createElement('link'), { rel: 'stylesheet', media: 'print', href });
        probe.dataset.deferredStylesheet = 'true';
        document.head.appendChild(probe);
      });
      const script = document.createElement('script');
      script.textContent = arguments[0];
      document.head.appendChild(script);
    JS
    expect(page).to have_css('link[data-deferred-stylesheet][media="all"]', count: 2, visible: :all)
  end

  def turbo_visit(path)
    page.execute_script('Turbo.visit(arguments[0])', path)
  end

  it 'releases a Turbo render once the stylesheets have loaded' do
    visit terms_path
    run_apply_script_over_probes

    turbo_visit('/atlas/login')

    expect(page).to have_field('user[nuid]')
  end

  # Firefox fires load again when the script switches a link's media to all.
  # Counted twice, the count passed zero and every later render stayed held.
  it 'releases a Turbo render when a stylesheet fires load twice' do
    visit terms_path
    run_apply_script_over_probes
    page.execute_script(<<~JS)
      document.querySelectorAll('link[data-deferred-stylesheet]').forEach((link) => {
        link.dispatchEvent(new Event('load'));
      });
    JS

    turbo_visit('/atlas/login')

    expect(page).to have_field('user[nuid]')
  end
end
