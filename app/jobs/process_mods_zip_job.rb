class ProcessModsZipJob
  include SpreadsheetHelper
  include XmlValidator
  include ApplicationHelper
  include ZipHelper

  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user, :permissions, :client

  def queue_name
    :mods_process_zip
  end

  def initialize(loader_name, zip_path, parent, copyright, current_user, permissions, client=nil)
    self.loader_name = loader_name
    self.zip_path = zip_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.client = client
  end

  def run
    report_id = Loaders::LoadReport.create_from_strings(current_user, 0, loader_name, parent)
    load_report = Loaders::LoadReport.find(report_id)

    # unzip zip file to tmp storage
    dir_path = File.join(File.dirname(zip_path), File.basename(zip_path, ".*"))
    spreadsheet_file_path = unzip(zip_path, dir_path)

    process_spreadsheet(dir_path, spreadsheet_file_path, load_report, client)
  end

  def process_spreadsheet(dir_path, spreadsheet_file_path, load_report, client)
    count = 0
    spreadsheet = load_spreadsheet(spreadsheet_file_path)

    header_position = 1
    header_row = spreadsheet.row(header_position)

    spreadsheet.each_row_streaming(offset: header_position) do |row|
      if row.present? && header_row.present?
        row_results = process_a_row(header_row, row)
        # TODO fill out
      end
    end

    # load_report.update_counts
    # load_report.number_of_files = count
    # load_report.save!

    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      # LoaderMailer.load_alert(load_report, User.find_by_nuid(load_report.nuid)).deliver!
    end
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
    # results["Title"]                                      = find_in_row(header_row, row_value, '') #commented out until it has a unique value
    results["physical_location"]                            = find_in_row(header_row, row_value, 'What is the physical location for this object?')
    results["identifier"]                                   = find_in_row(header_row, row_value, 'What is the identifier for this object?')
    # results["Title"]                                      = find_in_row(header_row, row_value, '') #commented out until it has a unique value
    results["timestamp"]                                    = find_in_row(header_row, row_value, 'Timestamp')
    # results["Title"]                                      = find_in_row(header_row, row_value, '') #commented out until it has a unique value
    return results
  end

  def find_in_row(header_row, row_value, column_identifier)
    0.upto header_row.length do |row_pos|
      # Account for case insensitivity
      case header_row[row_pos].downcase
      when column_identifier.downcase
          return row_value[row_pos].to_s || ""
      end
    end
    return ""
  end

end
