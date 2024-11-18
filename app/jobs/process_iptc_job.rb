# frozen_string_literal: true

class ProcessIptcJob < ApplicationJob
  queue_as :default

  def self.default_collection_id
    'tmpg6t2'
  end

  def perform(ingest_id)
    ingest = Ingest.find(ingest_id)

    begin
      xml_content = generate_xml_from_iptc(JSON.parse(ingest.ingestible.metadata))
      work = AtlasRb::Work.create(self.class.default_collection_id)
      ingest.ingestible.update_pid(work['id'])

      Tempfile.create(['mods', '.xml'], binmode: true) do |temp_file|
        temp_file.write(xml_content)
        temp_file.flush
        AtlasRb::Work.update(work['id'], temp_file.path)
      end

      Tempfile.create(['image', '.jpg'], binmode: true) do |temp_image|
        temp_image.write(ingest.ingestible.image_file)
        temp_image.flush

        AtlasRb::Blob.create(work['id'], temp_image.path)
        AtlasRb::Community.metadata(work['id'], { 'thumbnail' => ThumbnailCreator.call(path: temp_image.path) })
      end

      ingest.update!(status: :completed)
    rescue StandardError => e
      Rails.logger.error("Processing failed for ingest #{ingest_id}: #{e.message}")
      ingest.update!(status: :failed)
      raise e
    end
  end

  private
  def generate_xml_from_iptc(raw_iptc)
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml['mods'].mods(mods_namespaces) do
        build_title_section(xml, raw_iptc)
        build_abstract_section(xml, raw_iptc)
        build_creator_section(xml, raw_iptc)
        build_origin_info_section(xml, raw_iptc)
        build_subject_section(xml, raw_iptc)
        build_resource_type_section(xml)
        build_physical_description_section(xml)
        build_identifiers_section(xml)
        build_genre_section(xml)
        build_access_condition_section(xml)
        build_classification_section(xml, raw_iptc)
      end
    end.to_xml
  end

  def mods_namespaces
    {
      'xmlns:mods' => 'http://www.loc.gov/mods/v3',
      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
      'xmlns:drs' => 'https://repository.neu.edu/spec/v1',
      'xmlns:niec' => 'http://repository.neu.edu/schema/niec',
      'xmlns:dcterms' => 'http://purl.org/dc/terms/',
      'xmlns:dwc' => 'http://rs.tdwg.org/dwc/terms/',
      'xmlns:dwr' => 'http://rs.tdwg.org/dwc/xsd/simpledarwincore/',
      'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd'
    }
  end

  def build_title_section(xml, raw_iptc)
    xml['mods'].titleInfo('usage' => 'primary') do
      xml['mods'].title raw_iptc['Headline']
    end
  end

  def build_abstract_section(xml, raw_iptc)
    xml['mods'].abstract raw_iptc['Description'] if raw_iptc['Description'].present?
  end

  def build_creator_section(xml, raw_iptc)
    if raw_iptc['By-line'].present?
      xml['mods'].name('type' => 'personal', 'usage' => 'primary') do
        name_parts = process_byline(raw_iptc['By-line'])
        xml['mods'].namePart(name_parts[:first], 'type' => 'given') if name_parts[:first]
        xml['mods'].namePart(name_parts[:last], 'type' => 'family') if name_parts[:last]
        xml['mods'].namePart

        if raw_iptc['By-lineTitle'].present?
          xml['mods'].role do
            xml['mods'].roleTerm(raw_iptc['By-lineTitle'], 'type' => 'text')
          end
        end
      end
    end
  end

  def build_origin_info_section(xml, raw_iptc)
    xml['mods'].originInfo do
      build_place_info(xml, raw_iptc)
      build_date_info(xml, raw_iptc)
      xml['mods'].publisher(raw_iptc['Source'])
    end
  end

  def build_place_info(xml, raw_iptc)
    xml['mods'].place do
      xml['mods'].placeTerm
      if raw_iptc['City'].present? || raw_iptc['State'].present?
        xml['mods'].placeTerm([raw_iptc['City'], raw_iptc['State']].compact.join(' '), 'type' => 'text')
      end
    end
  end

  def build_date_info(xml, raw_iptc)
    return unless raw_iptc['DateTimeOriginal'].present?

    xml['mods'].dateCreated(raw_iptc['DateTimeOriginal'], 'keyDate' => 'yes', 'encoding' => 'w3cdtf')
    xml['mods'].copyrightDate(raw_iptc['DateTimeOriginal'], 'encoding' => 'w3cdtf')
  end

  def build_subject_section(xml, raw_iptc)
    return unless raw_iptc['Keywords']

    Array(raw_iptc['Keywords']).each do |keyword|
      next if keyword.blank?
      xml['mods'].subject do
        xml['mods'].topic keyword.to_s
      end
    end
  end

  def build_resource_type_section(xml)
    xml['mods'].typeOfResource 'still image'
  end

  def build_physical_description_section(xml)
    xml['mods'].physicalDescription do
      xml['mods'].form('electronic', 'authority' => 'marcform')
      xml['mods'].digitalOrigin 'born digital'
      xml['mods'].extent '1 photograph'
    end
  end

  def build_identifiers_section(xml)
    xml['mods'].identifier('http://testhandle', 'type' => 'hdl', 'displayLabel' => 'Permanent URL')
  end

  def build_genre_section(xml)
    xml['mods'].genre('photographs', 'authority' => 'aat')
  end

  def build_access_condition_section(xml)
    xml['mods'].accessCondition.type 'use and reproduction'
  end

  def build_classification_section(xml, raw_iptc)
    classification = ''

    if raw_iptc['Category'].present?
      classification = process_category(raw_iptc['Category'])
    end

    if raw_iptc['SupplementalCategories'].present?
      supplemental = process_supplemental_categories(raw_iptc['SupplementalCategories'])
      classification = if classification.present?
                         "#{classification}#{supplemental}"
                       else
                         supplemental
                       end
    end

    xml['mods'].classification classification if classification.present?
  end

  def process_category(val)
    case val
    when "ALU" then "alumni"
    when "ATH" then "athletics"
    when "CAM" then "campus"
    when "CLA" then "classroom"
    when "COM" then "community outreach"
    when "EXPERIENTIAL LEARNING" then val.downcase
    when "HEA" then "headshots"
    when "POR" then "portraits"
    when "PRE" then "president"
    when "RES" then "research"
    else val.downcase
    end
  end

  def process_supplemental_categories(val)
    if val.kind_of?(Array)
      val.map do |i|
        if i.kind_of?(String)
          " -- " + i.downcase
        end
      end.compact.join.gsub("_", " ")
    else
      " -- #{val}"
    end
  end

  def process_byline(val)
    if val.include?(",")
      parts = val.split(",")
      { first: parts[1].strip, last: parts[0].strip }
    elsif val.include?(";")
      parts = val.split(";")
      { first: parts[1].strip, last: parts[0].strip }
    else
      name_array = Namae.parse(val)
      if name_array.blank?
        name_array = Namae.parse(val.titleize)
      end
      name_obj = name_array[0]
      if name_obj&.given.present? && name_obj&.family.present?
        { first: name_obj.given, last: name_obj.family }
      else
        {} # empty if can't parse
      end
    end
  end
end
