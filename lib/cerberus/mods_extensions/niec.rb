module Cerberus::ModsExtensions::NIEC
  extend ActiveSupport::Concern

  included do

    def self.nattr(keys, name=nil)
      if name
        getter_name = :"#{name}"
        setter_name = :"#{name}="
      else
        getter_name = :"#{keys.last}"
        setter_name = :"#{keys.last}="
      end

      define_method(getter_name) do
        keys.inject(self, &:send)
      end

      define_method(setter_name) do |value|
        last = keys.length - 1
        keys.each_with_index.inject(self) do |chain,(key, i)|
          if i != last
            chain.send(:"#{key}")
          else
            chain.send(:"#{key}=", value)
          end
        end
      end
    end

    def self.ndh(pth, hsh={})
      return { path: pth, namespace_prefix: "niec"}.merge(hsh)
    end

    extend_terminology do |t|
      t.niec_extension(path: "extension", namespace_prefix: "mods"){
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
              t.niec_language(ndh "language"){
                t.authority(path: { attribute: "authority" })
                t.type(path: { attribute: "type" })
              }
              t.niec_sign_pace(ndh "signPace")
              t.niec_fingerspelling_extent(ndh "fingerspellingExtent")
              t.niec_fingerspelling_pace(ndh "fingerspellingPace")
              t.niec_numbers_extent(ndh "numbersExtent")
              t.niec_numbers_pace(ndh "numbersPace")
              t.niec_classifiers_extent(ndh "classifiersExtent")
              t.niec_use_of_space_extent(ndh "useOfSpaceExtent")
              t.niec_how_space_used(ndh "howSpaceUsed")
            }
            t.niec_spoken_language(ndh "spokenLanguage"){
              t.niec_language(ndh "language"){
                t.authority(path: { attribute: "authority" })
                t.type(path: { attribute: "type" })
              }
              t.niec_speech_pace(ndh "speechPace")
              t.niec_lends_itself_to_fingerspelling(ndh "lendsItselfToFingerspelling")
              t.niec_lends_itself_to_classifiers(ndh "lendsItselfToClassifiers")
              t.niec_lends_itself_to_numbers(ndh "lendsItselfToNumbers")
              t.niec_lends_itself_to_use_of_space(ndh "lendsItselfToUseOfSpace")
            }
          }
          t.niec_content_description(ndh "contentDescription"){
            t.niec_text_type(ndh "textType")
            t.niec_register(ndh "register")
            t.niec_approach(ndh "approach")
            t.niec_captions(ndh "captions")
            t.niec_conversation_type(ndh "conversationType")
            t.niec_audience(ndh "audience")
            t.niec_genre(ndh("genre", {attributes: { authority: "aat"}}))
            t.niec_subject(ndh "subject"){
              t.niec_topic(ndh("topic", {attributes: { authority: "lcsh"}}))
            }
            t.niec_duration(ndh "duration")
            t.niec_overview(ndh "overview")
          }
          t.niec_transcript(ndh "transcript")
          t.niec_series(ndh "series")
          t.niec_comment(ndh "comment")
          t.niec_description(ndh "description")
          t.niec_rights_statement(ndh "rightsStatement")
        }
      }
    end

    nattr [:niec_extension, :niec, :niec_identifier]
    nattr [:niec_extension, :niec, :niec_identifier, :type], :niec_identifier_type
    nattr [:niec_extension, :niec, :niec_comment]
    nattr [:niec_extension, :niec, :niec_title]
    nattr [:niec_extension, :niec, :niec_name, :niec_full_name]
    nattr [:niec_extension, :niec, :niec_name, :niec_full_name, :type], :niec_full_name_type
    nattr [:niec_extension, :niec, :niec_name, :niec_full_name, :authority], :niec_full_name_authority
    nattr [:niec_extension, :niec, :niec_name, :niec_role]
    nattr [:niec_extension, :niec, :niec_name, :niec_speaker_information, :niec_gender]
    nattr [:niec_extension, :niec, :niec_name, :niec_speaker_information, :niec_age]
    nattr [:niec_extension, :niec, :niec_name, :niec_speaker_information, :niec_race]
    nattr [:niec_extension, :niec, :niec_origin, :niec_publication_information, :niec_publisher_name]
    nattr [:niec_extension, :niec, :niec_origin, :niec_publication_information, :niec_publication_date]
    nattr [:niec_extension, :niec, :niec_origin, :niec_distribution_information, :niec_distributor_name]
    nattr [:niec_extension, :niec, :niec_origin, :niec_distribution_information, :niec_distribution_date]
    nattr [:niec_extension, :niec, :niec_origin, :niec_date_created]
    nattr [:niec_extension, :niec, :niec_origin, :niec_date_issued]


    private_class_method :ndh, :niec_proxy, :niec_full_name_proxy
    private_class_method :niec_speaker_proxy, :niec_publisher_proxy
    private_class_method :niec_distributor_proxy
  end
end
