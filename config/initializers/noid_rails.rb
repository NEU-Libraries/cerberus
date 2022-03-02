# frozen_string_literal: true

Noid::Rails.configure do |config|
  # will default to file instead of db
  # couldn't make service play nice
  # so using this guard plus a global minter
  if !Rails.env.test?
    config.minter_class = Noid::Rails::Minter::Db
    config.template = '.reeeeeek'
  end
end

::Minter = Noid::Rails::Service.new
