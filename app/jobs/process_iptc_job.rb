# frozen_string_literal: true

class ProcessIptcJob < ApplicationJob
  queue_as :default

  def perform(ingest_id)
    ingest = Ingest.find(ingest_id)

    begin
      xml_content = generate_xml_from_iptc(JSON.parse(ingest.ingestible.metadata))
      work = AtlasRb::Work.create('tmpg6t2')

      Tempfile.create(['mods', '.xml'], binmode: true) do |temp_file|
        temp_file.write(xml_content)
        temp_file.flush
        AtlasRb::Work.update(work['id'], temp_file.path)
      end

      Tempfile.create(['image', '.jpg'], binmode: true) do |temp_image|
        temp_image.write(ingest.ingestible.image_file)
        temp_image.flush

        AtlasRb::Blob.create(work['id'], temp_image.path)
        AtlasRb::Community.metadata(work['id'], {'thumbnail' => ThumbnailCreator.call(path: temp_image.path) })
      end



      ingest.update!(status: :completed)
    rescue StandardError => e
      Rails.logger.error("Processing failed for ingest #{ingest_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      ingest.update!(status: :failed)
      raise e
    end
  end

  private

  # TODO Organize this bit a little
  def generate_xml_from_iptc(raw_iptc)
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml['mods'].mods('xmlns:drs' => 'https://repository.neu.edu/spec/v1',
                       'xmlns:mods' => 'http://www.loc.gov/mods/v3',
                       'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                       'xmlns:niec' => 'http://repository.neu.edu/schema/niec',
                       'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd') do


        xml['mods'].titleInfo('usage' => 'primary') do
          xml['mods'].title raw_iptc['Headline']
        end

        xml['mods'].titleInfo('type' => 'alternative') do
          xml['mods'].title
        end


        xml['mods'].abstract raw_iptc['Description'] if raw_iptc['Description'].present?


        if raw_iptc['By-line'].present?
          xml['mods'].name('type' => 'personal', 'usage' => 'primary') do
            name_parts = process_byline(raw_iptc['By-line'])
            xml['mods'].namePart(name_parts[:first], 'type' => 'given') if name_parts[:first]
            xml['mods'].namePart(name_parts[:last], 'type' => 'family') if name_parts[:last]
            xml['mods'].namePart
            xml['mods'].role do
              xml['mods'].roleTerm(raw_iptc['By-lineTitle'] || 'University Photographer', 'type' => 'text')
            end
          end
        end

        xml['mods'].name('type' => 'corporate')


        xml['mods'].originInfo do
          xml['mods'].place do
            xml['mods'].placeTerm
            if raw_iptc['City'].present? || raw_iptc['State'].present?
              xml['mods'].placeTerm([raw_iptc['City'], raw_iptc['State']].compact.join(' '), 'type' => 'text')
            end
          end

          # May need tweaks
          if raw_iptc['DateTimeOriginal'].present?
            xml['mods'].dateCreated(raw_iptc['DateTimeOriginal'], 'keyDate' => 'yes', 'encoding' => 'w3cdtf')
            xml['mods'].copyrightDate(raw_iptc['DateTimeOriginal'], 'encoding' => 'w3cdtf')
          end
          xml['mods'].publisher 'Northeastern University'
        end


        xml['mods'].language do
          xml['mods'].languageTerm
        end

        xml['mods'].note('type' => 'citation')


        if raw_iptc['Keywords']
          Array(raw_iptc['Keywords']).each do |keyword|
            next if keyword.blank?
            xml['mods'].subject do
              xml['mods'].topic keyword.to_s.downcase
            end
          end
        end

        xml['mods'].typeOfResource 'still image'


        xml['mods'].recordInfo do
          xml['mods'].recordContentSource
          xml['mods'].recordOrigin
          xml['mods'].descriptionStandard
          xml['mods'].languageOfCataloging do
            xml['mods'].languageTerm
          end
        end


        xml['mods'].physicalDescription do
          xml['mods'].form('electronic', 'authority' => 'marcform')
          xml['mods'].digitalOrigin 'born digital'
          xml['mods'].extent '1 photograph'
        end


        xml['mods'].identifier('http://testhandle', 'type' => 'hdl', 'displayLabel' => 'Permanent URL')


        xml['mods'].extension('displayLabel' => 'scholarly_object') do
          xml.scholarly_object do
            xml.category
            xml.department
            xml.degree
            xml.course_info do
              xml.course_number
              xml.course_title
            end
          end
        end

        xml['mods'].extension do
          xml['niec'].niec
        end

        xml['mods'].genre('photographs', 'authority' => 'aat')


        xml['mods'].accessCondition(
          'Marketing and Communications images are for use only within the context of Northeastern University...',
          'type' => 'use and reproduction'
        )


        if raw_iptc['Category'].present?
          classification = process_category(raw_iptc['Category'])
          if raw_iptc['SupplementalCategories'].present?
            classification += process_supplemental_categories(raw_iptc['SupplementalCategories'])
          end
          xml['mods'].classification classification
        end
      end
    end.to_xml
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
      val.map { |i| " -- #{i.downcase}" }.join.gsub("_", " ")
    else
      " -- #{val.downcase}"
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
