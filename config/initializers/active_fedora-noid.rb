require 'active_fedora/noid'

ActiveFedora::Noid.configure do |config|
  config.minter_class = ActiveFedora::Noid::Minter::Db
  config.template = 'neu.reeeeeeee'
  # config.template = '.zd'
end
