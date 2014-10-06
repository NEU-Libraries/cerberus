module Cerberus::ModsExtensions::NIEC
  extend ActiveSupport::Concern

  included do
    def self.niec_proxy(array_of_keys)
      return [:niec_extension, :niec].push(*array_of_keys)
    end

    extend_terminology do |t|
      t.niec_extension(path: "extension", namespace_prefix: 'mods'){
        t.niec(path: "niec", namespace_prefix: "niec"){
          t.niec_identifier(path: "identifier", namespace_prefix: "niec"){
            t.type(path: { attribute: 'type'})
          }
          t.niec_title(path: "title", namespace_prefix: "niec")
          t.niec_name(path: "name", namespace_prefix: "niec"){
            t.niec_full_name(path: "fullName", namespace_prefix: "niec"){
              t.authority(path: {attribute: 'authority'})
              t.type(path: { attribute: 'type'})
            }
            t.niec_role(path: "role", namespace_prefix: "niec",
                        attributes: { authority: "marcrelator" })
            t.niec_speaker_information(path: "speakerInformation", namespace_prefix: "niec"){
              t.niec_gender(path: "gender", namespace_prefix: "niec")
              t.niec_age(path: "age", namespace_prefix: "niec")
              t.niec_race(path: "race", namespace_prefix: "niec")
            }
          }
        }
      }

      t.niec_identifier(proxy: niec_proxy([:niec_identifier]))
      t.niec_identifier_type(proxy: niec_proxy([:niec_identifier, :type]))
      t.niec_title(proxy: niec_proxy([:niec_title]))
      t.niec_full_name(proxy: niec_proxy([:niec_name, :niec_full_name]))
      t.niec_full_name_authority(proxy: niec_proxy([:niec_name,
                                                    :niec_full_name,
                                                    :authority]))
      t.niec_full_name_type(proxy: niec_proxy([:niec_name,
                                               :niec_full_name,
                                               :type]))
      t.niec_role(proxy: niec_proxy([:niec_name, :niec_role]))
      t.niec_gender(proxy: niec_proxy([:niec_name,
                                       :niec_speaker_information,
                                       :niec_gender]))
      t.niec_age(proxy: niec_proxy([:niec_name,
                                    :niec_speaker_information,
                                    :niec_age]))
      t.niec_race(proxy: niec_proxy([:niec_name,
                                     :niec_speaker_information,
                                     :niec_race]))
    end
  end

  # Q: Why not use the proxies defined above to do assignment?
  # A: Unless the xml_template explicitly defines empty nodes with the
  # appropriate nesting for every proxied element, the proxy assignment
  # writes the element as a direct child of the tree root.

  def niec_identifier=(val)
    path_to_niec.niec_identifier = val
  end

  def niec_identifier_type=(val)
    path_to_niec.niec_identifier.type = val
  end

  def niec_title=(val)
    path_to_niec.niec_title = val
  end

  def niec_full_name=(val)
    path_to_niec.niec_name.niec_full_name = val
  end

  def niec_full_name_authority=(val)
    path_to_niec.niec_name.niec_full_name.authority = val
  end

  def niec_full_name_type=(val)
    path_to_niec.niec_name.niec_full_name.type = val
  end

  def niec_role=(val)
    path_to_niec.niec_name.niec_role = val
  end

  def niec_gender=(val)
    path_to_niec.niec_name.niec_speaker_information.niec_gender = val
  end

  def niec_age=(val)
    path_to_niec.niec_name.niec_speaker_information.niec_age = val
  end

  def niec_race=(val)
    path_to_niec.niec_name.niec_speaker_information.niec_race = val
  end

  private

  def path_to_niec
    self.niec_extension.niec
  end
end
