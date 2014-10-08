module Cerberus::ModsExtensions::NIEC
  extend ActiveSupport::Concern

  included do
    class << self
      attr_accessor :niec_attrs
    end
    self.niec_attrs ||= []


    def self.niec_attr(keys, name=nil, **opts)
      if name
        getter_name = :"#{name}"
        setter_name = :"#{name}="
      else
        getter_name = :"#{keys.last}"
        setter_name = :"#{keys.last}="
      end

      opts[:index_as] ||= :symbol
      opts[:type] ||= :text

      define_method(getter_name) do
        keys.inject(self, &:send)
      end

      self.niec_attrs << [getter_name, opts]

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

    def self.path_to_niec
      [:niec_extension, :niec]
    end

    def self.path_to_name
      path_to_niec.push(:niec_name)
    end

    def self.path_to_origin
      path_to_niec.push(:niec_origin)
    end

    def self.path_to_signed_language
      path_to_niec.push(:niec_language_information, :niec_signed_language)
    end

    def self.path_to_spoken_language
      path_to_niec.push(:niec_language_information, :niec_spoken_language)
    end

    def self.path_to_content_desc
      path_to_niec.push(:niec_content_description)
    end

    niec_attr path_to_niec.push(:niec_identifier)
    niec_attr path_to_niec.push(:niec_identifier, :type), :niec_identifier_type
    niec_attr path_to_niec.push(:niec_comment), :index_as => :stored_searchable
    niec_attr path_to_niec.push(:niec_title), :index_as => :stored_searchable
    niec_attr path_to_niec.push(:niec_transcript)
    niec_attr path_to_niec.push(:niec_description),
                                :index_as => :stored_searchable
    niec_attr path_to_niec.push(:niec_series),
                                :index_as => :stored_searchable
    niec_attr path_to_niec.push(:niec_rights_statement)

    # niec:name elements
    niec_attr path_to_name.push(:niec_full_name),
                                :index_as => :stored_searchable
    niec_attr path_to_name.push(:niec_full_name, :type), :niec_full_name_type
    niec_attr path_to_name.push(:niec_full_name, :authority),
                                :niec_full_name_authority
    niec_attr path_to_name.push(:niec_role)
    niec_attr path_to_name.push(:niec_speaker_information, :niec_gender)
    niec_attr path_to_name.push(:niec_speaker_information, :niec_age)
    niec_attr path_to_name.push(:niec_speaker_information, :niec_race)

    #niec:origin elements
    niec_attr path_to_origin.push(:niec_publication_information,
                                  :niec_publisher_name),
                                  :index_as => :stored_searchable
    niec_attr path_to_origin.push(:niec_publication_information,
                                  :niec_publication_date),
                                  :index_as => :stored_searchable,
                                  :type => :date
    niec_attr path_to_origin.push(:niec_distribution_information,
                                  :niec_distributor_name)
    niec_attr path_to_origin.push(:niec_distribution_information,
                                  :niec_distribution_date),
                                  :index_as => :stored_searchable,
                                  :type => :date
    niec_attr path_to_origin.push(:niec_date_created),
                                  :index_as => :stored_searchable,
                                  :type => :date
    niec_attr path_to_origin.push(:niec_date_issued),
                                  :index_as => :stored_searchable,
                                  :type => :date

    #niec:languageInformation elements
    niec_attr path_to_signed_language.push(:niec_language),
                                           :niec_signed_language
    niec_attr path_to_signed_language.push(:niec_language, :authority),
                                           :niec_signed_language_authority
    niec_attr path_to_signed_language.push(:niec_language, :type),
                                           :niec_signed_language_type
    niec_attr path_to_signed_language.push(:niec_sign_pace)
    niec_attr path_to_signed_language.push(:niec_fingerspelling_extent)
    niec_attr path_to_signed_language.push(:niec_fingerspelling_pace)
    niec_attr path_to_signed_language.push(:niec_numbers_pace)
    niec_attr path_to_signed_language.push(:niec_numbers_extent)
    niec_attr path_to_signed_language.push(:niec_classifiers_extent)
    niec_attr path_to_signed_language.push(:niec_use_of_space_extent)
    niec_attr path_to_signed_language.push(:niec_how_space_used)
    niec_attr path_to_spoken_language.push(:niec_language),
                                           :niec_spoken_language
    niec_attr path_to_spoken_language.push(:niec_language, :authority),
                                           :niec_spoken_language_authority
    niec_attr path_to_spoken_language.push(:niec_language, :type),
                                           :niec_spoken_language_type
    niec_attr path_to_spoken_language.push(:niec_speech_pace)
    niec_attr path_to_spoken_language.push(:niec_lends_itself_to_fingerspelling)
    niec_attr path_to_spoken_language.push(:niec_lends_itself_to_numbers)
    niec_attr path_to_spoken_language.push(:niec_lends_itself_to_classifiers)
    niec_attr path_to_spoken_language.push(:niec_lends_itself_to_use_of_space)

    #niec:contentDescription elements
    niec_attr path_to_content_desc.push(:niec_text_type)
    niec_attr path_to_content_desc.push(:niec_register)
    niec_attr path_to_content_desc.push(:niec_approach)
    niec_attr path_to_content_desc.push(:niec_captions)
    niec_attr path_to_content_desc.push(:niec_conversation_type)
    niec_attr path_to_content_desc.push(:niec_audience)
    niec_attr path_to_content_desc.push(:niec_genre)
    niec_attr path_to_content_desc.push(:niec_subject)
    niec_attr path_to_content_desc.push(:niec_duration)
    niec_attr path_to_content_desc.push(:niec_overview)

    private_class_method :ndh
  end

  def generate_niec_solr_hash(hsh = {})
    self.class.niec_attrs.each do |niec_attribute|
      getter = niec_attribute.first

      opts     = niec_attribute.last
      index_as = opts[:index_as]
      type     = opts[:type]

      key    = Solrizer.solr_name(getter.to_s, index_as, type: type)

      value = self.send(getter)

      if value.present?
        hsh[key] = value
      end
    end

    hsh
  end
end
