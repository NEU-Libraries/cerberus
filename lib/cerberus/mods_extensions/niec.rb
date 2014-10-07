module Cerberus::ModsExtensions::NIEC
  extend ActiveSupport::Concern

  included do
    def self.niec_proxy(keys = [])
      return [:niec_extension, :niec].push(*keys)
    end

    def self.niec_full_name_proxy(keys = [])
      return [:niec_extension, :niec, :niec_name, :niec_full_name].push(*keys)
    end

    def self.niec_speaker_proxy(keys = [])
      return [:niec_extension, :niec, :niec_name, :niec_speaker_information].push(*keys)
    end

    def self.niec_publisher_proxy(keys = [])
      return [:niec_extension, :niec, :niec_origin, :niec_publication_information].push(*keys)
    end

    def self.niec_distributor_proxy(keys = [])
      return [:niec_extension, :niec, :niec_origin, :niec_distribution_information].push(*keys)
    end

    def self.ndh(pth, hsh={})
      return { path: pth, namespace_prefix: "niec"}.merge(hsh)
    end

    extend_terminology do |t|
      t.niec_extension(ndh "extension", attributes: { displayLabel: :none}){
        t.niec(ndh "niec"){
          t.niec_identifier(ndh "identifier"){
            t.type(path: { attribute: 'type'})
          }
          t.niec_title(ndh "title")
          t.niec_name(ndh "name"){
            t.niec_full_name(ndh "fullName"){
              t.authority(path: {attribute: 'authority'})
              t.type(path: { attribute: 'type'})
            }
            t.niec_role(ndh "role", attributes: { authority: "marcrelator" })
            t.niec_speaker_information(ndh "speakerInformation"){
              t.niec_gender(ndh "gender")
              t.niec_age(ndh "age")
              t.niec_race(ndh "race")
            }
          }
          t.niec_origin(ndh "origin"){
            t.niec_publication_information(ndh "publicationInformation"){
              t.niec_publisher_name(ndh "publisherName")
              t.niec_publication_date(ndh "publicationDate")
            }
            t.niec_distribution_information(ndh "distributionInformation"){
              t.niec_distributor_name(ndh "distributorName")
              t.niec_distribution_date(ndh "distributionDate")
            }
            t.niec_date_created(ndh "dateCreated")
            t.niec_date_issued(ndh "dateIssued")
          }
          t.niec_language_information(ndh "languageInformation"){
            t.niec_signed_language(ndh "signedLanguage"){
              t.niec_language(ndh "language")
              t.niec_sign_pace(ndh "signPace")
              t.niec_fingerspelling_extent(ndh "fingerspellingExtent")
              t.niec_fingerspelling_pace(ndh "fingerspellingPace")
              t.niec_numbers_extent(ndh "numbersExtent")
              t.niec_numbers_pace(ndh "numbersPace")
              t.niec_classifiers_extent(ndh "classifiersExtent")
              t.niec_use_of_space_extent(ndh "useOfSpaceExtent")
              t.niec_how_space_used(ndh "howSpaceUsed")
            }
          }
        }
      }

      t.niec_identifier(proxy: niec_proxy([:niec_identifier]))
      t.niec_identifier_type(proxy: niec_proxy([:niec_identifier, :type]))

      t.niec_title(proxy: niec_proxy([:niec_title]))

      t.niec_full_name(proxy: niec_full_name_proxy)
      t.niec_full_name_authority(proxy: niec_full_name_proxy([:authority]))
      t.niec_full_name_type(proxy: niec_full_name_proxy([:type]))

      t.niec_role(proxy: niec_proxy([:niec_name, :niec_role]))

      t.niec_gender(proxy: niec_speaker_proxy([:niec_gender]))
      t.niec_age(proxy: niec_speaker_proxy([:niec_age]))
      t.niec_race(proxy: niec_speaker_proxy([:niec_race]))

      t.niec_publisher_name(proxy: niec_publisher_proxy([:niec_publisher_name]))
      t.niec_publication_date(proxy:niec_publisher_proxy([:niec_publication_date]))

      t.niec_distributor_name(proxy: niec_distributor_proxy([:niec_distributor_name]))
      t.niec_distribution_date(proxy: niec_distributor_proxy([:niec_distribution_date]))

      t.niec_date_created(proxy: niec_proxy([:niec_origin, :niec_date_created]))
      t.niec_date_issued(proxy: niec_proxy([:niec_origin, :niec_date_issued]))
    end

    private_class_method :ndh, :niec_proxy, :niec_full_name_proxy
    private_class_method :niec_speaker_proxy, :niec_publisher_proxy
    private_class_method :niec_distributor_proxy
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

  def niec_publisher_name=(val)
    path_to_niec.niec_origin.niec_publication_information.niec_publisher_name = val
  end

  def niec_publication_date=(val)
    path_to_niec.niec_origin.niec_publication_information.niec_publication_date = val
  end

  def niec_distributor_name=(val)
    path_to_niec.niec_origin.niec_distribution_information.niec_distributor_name = val
  end

  def niec_distribution_date=(val)
    path_to_niec.niec_origin.niec_distribution_information.niec_distribution_date = val
  end

  def niec_date_created=(val)
    path_to_niec.niec_origin.niec_date_created = val
  end

  def niec_date_issued=(val)
    path_to_niec.niec_origin.niec_date_issued = val
  end

  private

  def path_to_niec
    self.niec_extension.niec
  end
end
