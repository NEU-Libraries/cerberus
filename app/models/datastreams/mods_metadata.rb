class ModsMetadata < ActiveFedora::OmDatastream

  set_terminology do |t|
    t.root(path: "mods", xmlns: "http://www.loc.gov/mods/v3", schema: "http://www.loc.gov/standards/mods/v3/mods-3-2.xsd")

    t.title_info(path: "titleInfo") {
      t.main_title(index_as: [:facetable], path: "title", label: "title")
      t.language(index_as: [:facetable], path: { attribute: "lang" })
    }
    t.language{
      t.lang_code(index_as: [:facetable], path: "languageTerm", attributes: { type: "code" })
    }
    t.abstract
    t.subject {
      t.topic(index_as: [:facetable])
    }
    t.topic_tag(proxy: [:subject, :topic])
    # t.topic_tag(:index_as=>[:facetable],:path=>"subject", :default_content_path=>"topic")
    # This is a mods:name.  The underscore is purely to avoid namespace conflicts.
    t.name_(index_as: [:searchable]) {
      # this is a namepart
      t.namePart(type: :string, label: "generic name")
      # affiliations are great
      t.affiliation
      t.institution(path: "affiliation", index_as: [:facetable], label: "organization")
      t.displayForm
      t.role(ref: [:role])
      t.description(index_as: [:facetable])
      t.date(path: "namePart", attributes: { type: "date" })
      t.last_name(path: "namePart", attributes: { type: "family" })
      t.first_name(path: "namePart", attributes: { type: "given" }, label: "first name")
      t.terms_of_address(path: "namePart", attributes: { type: "termsOfAddress" })
      t.computing_id
    }
    # lookup :person, :first_name
    t.person(ref: :name, attributes: { type: "personal" }, index_as: [:facetable, :stored_searchable])
    t.department(proxy: [:person, :description], index_as: [:facetable])
    t.organization(ref: :name, attributes: { type: "corporate" }, index_as: [:facetable])
    t.conference(ref: :name, attributes: { type: "conference" }, index_as: [:facetable])
    t.role(index_as: [:stored_searchable]) {
      t.text(path: "roleTerm", attributes: { type: "text" }, index_as: [:stored_searchable])
      t.code(path: "roleTerm", attributes: { type: "code" })
    }
    t.journal(path: 'relatedItem', attributes: { type: "host" }) {
      t.title_info(index_as: [:facetable], ref: [:title_info])
      t.origin_info(path: "originInfo") {
        t.publisher
        t.date_issued(path: "dateIssued")
        t.issuance(index_as: [:facetable])
      }
      t.issn(path: "identifier", attributes: { type: "issn" })
      t.issue(path: "part") {
        t.volume(path: "detail", attributes: { type: "volume" }, default_content_path: "number")
        t.level(path: "detail", attributes: { type: "number" }, default_content_path: "number")
        t.extent
        t.pages(path: "extent", attributes: { unit: "pages" }) {
          t.start
          t.end
        }
        t.start_page(proxy: [:pages, :start])
        t.end_page(proxy: [:pages, :end])
        t.publication_date(path: "date", type: :date, index_as: [:stored_searchable])
      }
    }
    t.note
    t.location(path: "location") {
      t.url(path: "url")
    }
    t.publication_url(proxy: [:location, :url])
    t.peer_reviewed(proxy: [:journal, :origin_info, :issuance], index_as: [:facetable])
    t.title(proxy: [:title_info, :main_title])
    t.journal_title(proxy: [:journal, :title_info, :main_title])
  end

  # Generates an empty Mods Article (used when you call ModsArticle.new without passing in existing xml)
  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.mods(:version => "3.3", "xmlns:xlink" => "http://www.w3.org/1999/xlink",
               "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
               "xmlns" => "http://www.loc.gov/mods/v3",
               "xsi:schemaLocation" => "http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd") {
        xml.titleInfo(lang: "") {
          xml.title
        }
        xml.name(type: "personal") {
          xml.namePart(type: "given")
          xml.namePart(type: "family")
          xml.affiliation
          xml.computing_id
          xml.description
          xml.role {
            xml.roleTerm("Author", authority: "marcrelator", type: "text")
          }
        }
        xml.typeOfResource
        xml.genre(authority: "marcgt")
        xml.language {
          xml.languageTerm(authority: "iso639-2b", type: "code")
        }
        xml.abstract
        xml.subject {
          xml.topic
        }
        xml.relatedItem(type: "host") {
          xml.titleInfo {
            xml.title
          }
          xml.identifier(type: "issn")
          xml.originInfo {
            xml.publisher
            xml.dateIssued
            xml.issuance
          }
          xml.part {
            xml.detail(type: "volume") {
              xml.number
            }
            xml.detail(type: "number") {
              xml.number
            }
            xml.extent(unit: "pages") {
              xml.start
              xml.end
            }
            xml.date
          }
        }
        xml.location {
          xml.url
        }
      }
    end
    builder.doc
  end

  # Generates a new Person node
  def self.person_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.name(type: "personal") {
        xml.namePart(type: "family")
        xml.namePart(type: "given")
        xml.affiliation
        xml.computing_id
        xml.description
        xml.role {
          xml.roleTerm("Author", type: "text")
        }
      }
    end
    builder.doc.root
  end

  def self.full_name_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.full_name(type: "personal")
    end
    builder.doc.root
  end

  # Generates a new Organization node
  # Uses mods:name[@type="corporate"]
  def self.organization_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.name(type: "corporate") {
        xml.namePart
        xml.role {
          xml.roleTerm(authority: "marcrelator", type: "text")
        }
      }
    end
    builder.doc.root
  end

  # Generates a new Conference node
  def self.conference_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.name(type: "conference") {
        xml.namePart
        xml.role {
          xml.roleTerm(authority: "marcrelator", type: "text")
        }
      }
    end
    builder.doc.root
  end

  def to_solr(solr_doc = {}, opts = {})
    solr_doc = super

    # ::Solrizer::Extractor.insert_solr_field_value(solr_doc, ActiveFedora.index_field_mapper.solr_name('object_type', :facetable), "Article")
    ::Solrizer::Extractor.insert_solr_field_value(solr_doc, ActiveFedora.index_field_mapper.solr_name('mods_journal_title_info', :facetable), "Unknown") if solr_doc["mods_journal_title_info_facet"].nil?

    solr_doc
  end

end
