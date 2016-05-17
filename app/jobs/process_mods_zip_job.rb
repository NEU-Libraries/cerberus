class ProcessModsZipJob
  include SpreadsheetHelper
  include XmlValidator
  include ApplicationHelper
  include ZipHelper

  attr_accessor :loader_name, :spreadsheet_file_path, :parent, :copyright, :current_user, :permissions, :preview, :client, :report_id

  def queue_name
    :mods_process_zip
  end

  def initialize(loader_name, spreadsheet_file_path, parent, copyright, current_user, permissions, report_id, preview=nil, client=nil)
    self.loader_name = loader_name
    self.spreadsheet_file_path = spreadsheet_file_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.preview = preview
    self.client = client
    self.report_id = report_id
  end

  def run
    load_report = Loaders::LoadReport.find(report_id)

    # unzip zip file to tmp storage
    dir_path = File.join(File.dirname(spreadsheet_file_path), File.basename(spreadsheet_file_path, ".*"))

    process_spreadsheet(dir_path, spreadsheet_file_path, load_report, preview, client)
  end

  def process_spreadsheet(dir_path, spreadsheet_file_path, load_report, preview, client)
    count = 0
    spreadsheet = load_spreadsheet(spreadsheet_file_path)

    header_position = 1
    header_row = spreadsheet.row(header_position)

    spreadsheet.each_row_streaming(offset: header_position) do |row|
      if row.present? && header_row.present?
        row_results = process_a_row(header_row, row)
        if preview
          # Process first row
          comparison_file = CoreFile.find(row_results["pid"])

          preview_file = CoreFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
          preview_file.depositor              = comparison_file.depositor
          preview_file.rightsMetadata.content = comparison_file.rightsMetadata.content
          # commenting this out because it means that changes to the xml_template will be removed if they didn't exist before the comparison_file was created, the diff still works without this but it means whatever is in the spreadsheet becomes all of the metadata, not just changing some of the fields
          # preview_file.mods.content           = comparison_file.mods.content
          preview_file.tmp_path = spreadsheet_file_path

          # Load row of metadata in for preview
          assign_a_row(row_results, preview_file)

          load_report.comparison_file_pid = comparison_file.pid
          load_report.preview_file_pid = preview_file.pid

          load_report.save!
          return
        end
      end
    end

    load_report.update_counts
    load_report.number_of_files = count
    load_report.save!

    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      load_report.completed = true
      load_report.save!
      # LoaderMailer.load_alert(load_report, User.find_by_nuid(load_report.nuid)).deliver!
    end
  end

  def assign_a_row(row_results, core_file)
    core_file.mods.identifier = row_results["handle"] #will need to check that this matches the original handle or else this file should error
    # core_file.mods. = row_results["archives_identifier"] #not sure where this goes in the mods yet

    core_file.mods.title = row_results["title"]
    core_file.mods.title_info.sub_title = row_results["subtitle"]
    core_file.mods.title_info.non_sort = row_results["title_initial_article"]
    core_file.mods.alternate_title.title = row_results["alternate_title"]
    core_file.mods.alternate_title.non_sort = row_results["alternate_title_initial_article"]
    core_file.mods.alternate_title.sub_title = row_results["alternate_subtitle"]

    # TODO - work creator magic loop here
    creators = row_results.select { |key, value| key.to_s.match(/^creator_\d+_name$/) }
    creator_nums = creators.keys.map {|key| key.scan(/\d/)[0].to_i }
    if creators.count > 0
      creator_hash = {}
      creator_hash['corporate_names'] = []
      creator_hash['first_names'] = []
      creator_hash['last_names'] = []
      creator_nums.each do |n|
        name_type = row_results["creator_#{n}_name_type"]
        if name_type == 'corporate'
          creator_hash['corporate_names'] << row_results["creator_#{n}_name"]
        elsif name_type == 'personal'
          creator_hash['first_names'] << row_results["creator_#{n}_name"]
          # last_names - not sure how to parse this since its one field
        end
      end
      puts creator_hash
      core_file.creators = creator_hash
      # currently the hash only accepts first_names, last_names, and corporate_names so we'd need to loop back through to assign the role and affiliation
    end

    core_file.mods.type_of_resource = row_results["type_of_resource"]
    core_file.mods.genre = row_results["genre"]
    # core_file.mods.genre.authority = #need authority
    # core_file.mods.date = row_results["date_created"] + row_results["date_created_end_date"] + row_results["approximate_inferred_questionable"] #not sure on this - how to string together? we currently have no notion of the point attribute for start and end in the mods datastream

    core_file.mods.origin_info.copyright = row_results["copyright_date"]
    core_file.mods.origin_info.date_issued = row_results["date_issued"]
    core_file.mods.origin_info.publisher = row_results["publisher_name"]
    core_file.mods.origin_info.place.place_term = row_results["place_of_publication"]
    core_file.mods.origin_info.edition = row_results["edition"]
    core_file.mods.origin_info.issuance = row_results["issuance"]
    core_file.mods.origin_info.frequency = row_results["frequency"]
    # core_file.mods.origin_info.frequency.authority = #need authority
    core_file.mods.physical_description.extent = row_results["extent"]
    core_file.mods.physical_description.digital_origin = row_results["digital_origin"]
    core_file.mods.physical_description.reformatting_quality = row_results["reformatting_quality"]
    core_file.mods.language.language_term = row_results["language"] #need type, authority, potentially authorityURI and valueURI
    core_file.mods.description = row_results["abstract"]
    core_file.mods.table_of_contents = row_results["table_of_contents"]

    access_conditions = {}
    if !row_results["acess_condition_use_and_reproduction"].blank?
      access_conditions["use and reproduction"] = row_results["acess_condition_use_and_reproduction"]
    end
    if !row_results["acess_condition_use_and_reproduction"].blank?
      access_conditions["restriction on access"] = row_results["acess_condition_restriction"]
    end
    if !access_conditions.blank?
      core_file.mods.access_conditions = access_conditions
    end

    notes = {}
    if !row_results["provenance"].blank?
      notes["provenance"] = row_results["provenance"]
    end
    if !row_results["other_notes"].blank?
      notes["other"] = row_results["other_notes"]
    end
    if !notes.blank?
      core_file.mods.notes = notes
    end

    # subjects/topics
    # will these have different attributes for the different types?
    keywords = []
    keywords << row_results["topical_subject_headings"]
    keywords << row_results["personal_name_subject_headings"]
    keywords << row_results["additional_personal_name_subject_headings"]
    keywords << row_results["corporate_name_subject_headings"]
    keywords << row_results["addiditional_corporate"]
    core_file.keywords = keywords


    # for related items - three separate related items based on different fields at the end of the spreadsheet
    # perhaps it will make sense to make a hash of hashes...or different methods for the difference related item "types"
    related_items = {}
    # original item
    if !row_results["original_title"].blank? || !row_results["physical_location"].blank? || !row_results["identifier"].blank?
      related_items["original"] = {}
      if !row_results["original_title"].blank?
        related_items["original"][:title] = row_results["original_title"]
      end
      if !row_results["physical_location"].blank?
        related_items["original"][:physical_location] = row_results["physical_location"]
      end
      if !row_results["identifier"].blank?
        related_items["original"][:identifier] = row_results["identifier"]
      end
    end
    # host aka collection
    if !row_results["collection_title"].blank?
      related_items["host"] = {:title => row_results["collection_title"]}
    end
    # series
    if !row_results["series_title"].blank?
      related_items["series"] = {:title => row_results["series_title"]}
    end
    if !related_items.blank?
      core_file.mods.related_items = related_items
    end

    # timestamp - does not need to be recorded, it is a google generated timestamp

    # default values inserted on every record
    core_file.mods.record_info.record_content_source = "Northeastern University Libraries"
    core_file.mods.record_info.record_origin = "Generated from spreadsheet"
    core_file.mods.record_info.language_of_cataloging.language_term = "English"
    core_file.mods.record_info.language_of_cataloging.language_term.language_authority = "iso639-2b"
    core_file.mods.record_info.language_of_cataloging.language_term.language_authority_uri = "http://id.loc.gov/vocabulary/iso639-2"
    core_file.mods.record_info.language_of_cataloging.language_term.language_term_type = "text"
    core_file.mods.record_info.language_of_cataloging.language_term.language_value_uri = "http://id.loc.gov/vocabulary/iso639-2/eng"
    core_file.mods.record_info.description_standard = "RDA"
    core_file.mods.record_info.description_standard.authority = "marcdescription"
    core_file.mods.physical_description.form = "electronic"
    core_file.mods.physical_description.form.authority = "marcform"

    core_file.save!
  end

  def process_a_row(header_row, row_value)
    results = Hash.new
    # results["file_name"]         = find_in_row(header_row, row_value, 'Filename')
    # results["title"]             = find_in_row(header_row, row_value, 'Title')
    # results["parent_filename"]   = find_in_row(header_row, row_value, 'Parent Filename')
    # results["sequence"]          = find_in_row(header_row, row_value, 'Sequence')
    # results["last_item"]         = find_in_row(header_row, row_value, 'Last Item')

    results["user_name"]                        = find_in_row(header_row, row_value, 'What is your name?')
    results["pid"]                              = find_in_row(header_row, row_value, 'What is PID for the digitized object?')
    results["handle"]                           = find_in_row(header_row, row_value, 'What is handle for the digitized object?')
    results["file_name"]                        = find_in_row(header_row, row_value, 'File Name')
    results["archives_identifier"]              = find_in_row(header_row, row_value, 'Archives Identifier')
    results["supplied_title"]                   = find_in_row(header_row, row_value, 'Is this a supplied title?')
    results["title_initial_article"]            = find_in_row(header_row, row_value, 'Title Initial Article')
    results["title"]                            = find_in_row(header_row, row_value, 'Title')
    results["subtitle"]                         = find_in_row(header_row, row_value, 'Subtitle')
    results["alternate_title_initial_article"]  = find_in_row(header_row, row_value, 'Alternate Title Initial Article')
    results["alternate_title"]                  = find_in_row(header_row, row_value, 'Alternate Title')
    results["alternate_subtitle"]               = find_in_row(header_row, row_value, 'Alternate Subtitle')

    results["creator_1_name"] = find_in_row(header_row, row_value, 'Creator 1 Name - Primary Creator')
    results["creator_1_name_type"] = find_in_row(header_row, row_value, 'Creator 1 Name Type')
    results["creator_1_role"] = find_in_row(header_row, row_value, 'Creator 1 Role')
    results["creator_1_affiliation"] = find_in_row(header_row, row_value, 'Creator 1 Affiliation')

    results["creator_2_name"] = find_in_row(header_row, row_value, 'Creator 2 Name - Primary Creator')
    results["creator_2_name_type"] = find_in_row(header_row, row_value, 'Creator 2 Name Type')
    results["creator_2_role"] = find_in_row(header_row, row_value, 'Creator 2 Role')
    results["creator_2_affiliation"] = find_in_row(header_row, row_value, 'Creator 2 Affiliation')

    results["more_creators"] = find_in_row(header_row, row_value, 'Would you like to add more creators?')

    results["creator_3_name"] = find_in_row(header_row, row_value, 'Creator 3 Name - Primary Creator')
    results["creator_3_name_type"] = find_in_row(header_row, row_value, 'Creator 3 Name Type')
    results["creator_3_role"] = find_in_row(header_row, row_value, 'Creator 3 Role')
    results["creator_3_affiliation"] = find_in_row(header_row, row_value, 'Creator 3 Affiliation')

    results["creator_4_name"] = find_in_row(header_row, row_value, 'Creator 4 Name - Primary Creator')
    results["creator_4_name_type"] = find_in_row(header_row, row_value, 'Creator 4 Name Type')
    results["creator_4_role"] = find_in_row(header_row, row_value, 'Creator 4 Role')
    results["creator_4_affiliation"] = find_in_row(header_row, row_value, 'Creator 4 Affiliation')

    results["creator_5_name"] = find_in_row(header_row, row_value, 'Creator 5 Name - Primary Creator')
    results["creator_5_name_type"] = find_in_row(header_row, row_value, 'Creator 5 Name Type')
    results["creator_5_role"] = find_in_row(header_row, row_value, 'Creator 5 Role')
    results["creator_5_affiliation"] = find_in_row(header_row, row_value, 'Creator 5 Affiliation')

    results["type_of_resource"]                             = find_in_row(header_row, row_value, 'Type of Resource')
    results["genre"]                                        = find_in_row(header_row, row_value, 'Genre')
    results["date_created"]                                 = find_in_row(header_row, row_value, 'Date Created')
    results["date_created_end_date"]                        = find_in_row(header_row, row_value, 'Date Created - End Date')
    results["approximate_inferred_questionable"]            = find_in_row(header_row, row_value, 'Date Created - Is this date approximate, inferred, or questionable?')
    results["copyright_date"]                               = find_in_row(header_row, row_value, 'Copyright Date')
    results["date_issued"]                                  = find_in_row(header_row, row_value, 'Date Issued (Published)')
    results["publisher_name"]                               = find_in_row(header_row, row_value, 'Publisher Name')
    results["place_of_publication"]                         = find_in_row(header_row, row_value, 'Place of Publication')
    results["edition"]                                      = find_in_row(header_row, row_value, 'Edition')
    results["issuance"]                                     = find_in_row(header_row, row_value, 'Issuance')
    results["frequency"]                                    = find_in_row(header_row, row_value, 'Frequency')
    results["reformatting_quality"]                         = find_in_row(header_row, row_value, 'Reformatting Quality')
    results["extent"]                                       = find_in_row(header_row, row_value, 'Extent')
    results["digital_origin"]                               = find_in_row(header_row, row_value, 'Digital Origin')
    results["language"]                                     = find_in_row(header_row, row_value, 'Language')
    results["abstract"]                                     = find_in_row(header_row, row_value, 'Abstract')
    results["table_of_contents"]                            = find_in_row(header_row, row_value, 'Table of Contents')
    results["acess_condition_restriction"]                  = find_in_row(header_row, row_value, 'Access Condition : Restriction on access')
    results["acess_condition_use_and_reproduction"]         = find_in_row(header_row, row_value, 'Access Condition : Use and Reproduction')
    results["provenance"]                                   = find_in_row(header_row, row_value, 'Provenance note')
    results["other_notes"]                                  = find_in_row(header_row, row_value, 'Other notes')
    results["topical_subject_headings"]                     = find_in_row(header_row, row_value, 'Topical Subject Headings')
    results["personal_name_subject_headings"]               = find_in_row(header_row, row_value, 'Personal Name Subject Headings')
    results["additional_personal_name_subject_headings"]    = find_in_row(header_row, row_value, 'Additional Personal Name Subject Headings')
    results["corporate_name_subject_headings"]              = find_in_row(header_row, row_value, 'Corporate Name Subject Headings')
    results["addiditional_corporate"]                       = find_in_row(header_row, row_value, 'Addiditional Corporate Name Subject Headings')
    results["original_title"]                               = find_in_row(header_row, row_value, 'Original Title') #updated cell title
    results["physical_location"]                            = find_in_row(header_row, row_value, 'What is the physical location for this object?')
    results["identifier"]                                   = find_in_row(header_row, row_value, 'What is the identifier for this object?')
    results["collection_title"]                             = find_in_row(header_row, row_value, 'Collection Title') #updated cell title
    results["timestamp"]                                    = find_in_row(header_row, row_value, 'Timestamp')
    results["series_title"]                                  = find_in_row(header_row, row_value, 'Series Title') #updated cell title
    return results
  end

  def find_in_row(header_row, row_value, column_identifier)
    0.upto header_row.length do |row_pos|
      # Account for case insensitivity
      if !header_row[row_pos].blank?
        case header_row[row_pos].downcase
        when column_identifier.downcase
            return row_value[row_pos].to_s || ""
        end
      end
    end
    return ""
  end

end
