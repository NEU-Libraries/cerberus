module File::Pathing
  def fedora_file_path
    # self.checksum.value
    # "42f6afc7eb22d4cf8d8fd008b2ca8bc5326162fe"
    # "/home/vagrant/cerberus/tmp/fcrepo4-development-data/fcrepo.binary.directory"
    # "/42/f6/af/42f6afc7eb22d4cf8d8fd008b2ca8bc5326162fe"
    # checksum.first(6).scan(/.{2}/).join("/")
    # "42/f6/af"
    fedora_binary_path = Rails.application.config.fedora_binary_path
    checksum = self.checksum.value
    pair_tree = checksum.first(6).scan(/.{2}/).join("/")
    return "#{fedora_binary_path}/#{pair_tree}/#{checksum}"
  end
end
