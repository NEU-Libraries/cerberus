module Cerberus::ModsExtensions::Darwin
  extend ActiveSupport::Concern

  included do
    def self.dwr(pth, hsh={})
      return { path: pth, namespace_prefix: "dwr"}.merge(hsh)
    end

    def self.dwc(pth, hsh={})
      return { path: pth, namespace_prefix: "dwc"}.merge(hsh)
    end

    extend_terminology do |t|
      t.darwin_extension(path: "extension", namespace_prefix: "mods"){
        t.darwin(dwr "SimpleDarwinRecord"){
          t.darwin_institution_id(dwc "institutionID")
        }
      }
    end

    private_class_method :dwr
    private_class_method :dwc
  end
end
