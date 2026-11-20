# frozen_string_literal: true

require 'rails_helper'

# Puma sizes any body it can (an array, a file, anything with #size) and sends
# that size as Content-Length. After Rack::Head empties a HEAD body, that size
# is 0, which HTTP forbids when GET would send something else. The request specs
# run without Puma, so this checks the body Puma would be handed.
describe HeadWithoutLength do
  def call(method, headers: {})
    app = ->(_env) { [200, headers, []] }
    described_class.new(app).call(Rack::MockRequest.env_for('/', method: method))
  end

  it 'hands a HEAD response a body Puma cannot size' do
    _, _, body = call('HEAD')

    expect(body).to respond_to(:each)
    expect(body).not_to respond_to(:to_ary)
    expect(body).not_to respond_to(:to_path)
    expect(body).not_to respond_to(:size)
  end

  it 'keeps a Content-Length the app set itself, as media does' do
    _, headers, = call('HEAD', headers: { 'content-length' => '1000' })

    expect(headers['content-length']).to eq('1000')
  end

  it 'leaves every other method alone' do
    _, _, body = call('GET')

    expect(body).to eq([])
  end

  it 'sits outside Rack::Head, so it sees the emptied body' do
    stack = Rails.application.middleware.map(&:klass)

    expect(stack.index(described_class)).to be < stack.index(Rack::Head)
  end
end
