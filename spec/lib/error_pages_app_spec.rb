# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ErrorPagesApp do
  def call(app, status)
    app.call(Rack::MockRequest.env_for("/#{status}"))
  end

  it 'serves the routed page when it renders' do
    app = described_class.new(->(_env) { [404, {}, ['routed']] })

    expect(call(app, 404)).to eq [404, {}, ['routed']]
  end

  # The case this exists for: the database is down, so the routed page's own
  # sign-in raises and Rails would otherwise answer in plain text.
  it 'serves the static page when the routed one fails' do
    app = described_class.new(->(_env) { raise ActiveRecord::ConnectionNotEstablished })

    status, headers, body = call(app, 503)

    expect(status).to eq 503
    expect(headers['content-type']).to start_with 'text/html'
    expect(body.join).to include Outage::CAPABILITIES[:repository].title
  end

  it 'keeps the original status when it has no page for it' do
    app = described_class.new(->(_env) { raise ActiveRecord::ConnectionNotEstablished })

    status, _headers, body = call(app, 404)

    expect(status).to eq 404
    expect(body.join).to include 'temporarily unavailable'
  end

  it 'has a page for the generic server error' do
    expect(described_class.page(500).read).to include 'system error'
  end

  # Rails serves public/ ahead of the routes, so a page there would shadow the
  # routed error page at the same path.
  it 'keeps the static pages out of public/' do
    expect(Rails.public_path.glob('{403,404,410,500,503}.html')).to be_empty
  end
end
