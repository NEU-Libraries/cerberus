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
    spreadsheet = load_spreadsheet(spreadsheet_file_path)

    header_position = 1
    header_row = spreadsheet.row(header_position)

    if !preview.nil?
      row = spreadsheet.row(header_position + 1)
      if row.present? && header_row.present?
        row_results = process_a_row(header_row, row)
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
        load_report.number_of_files = spreadsheet.last_row - header_position

        load_report.save!
      else
        puts "row not present"
      end
    else
      puts "not a preview anymore"
      spreadsheet.each_row_streaming(offset: header_position) do |row|
        if row.present? && header_row.present?
          begin
            row_results = process_a_row(header_row, row)
            core_file = CoreFile.find(row_results["pid"])
            if core_file.identifier != row_results["handle"]
              image_report = load_report.image_reports.create_failure("Handle does not match", row_results, "")
              image_report.title = core_file.title
              image_report.save!
            else
              core_file.mods.content = ModsDatastream.xml_template.to_xml
              assign_a_row(row_results, core_file)
              raw_xml = xml_decode(core_file.mods.content)
              result = xml_valid?(raw_xml)
              if !result[:errors].blank?
                image_report = load_report.image_reports.create_failure(error, row_results, "")
                image_report.title = core_file.title
                image_report.save!
              else
                puts "mods is valid"
                load_report.image_reports.create_success(core_file, "")
              end
            end
          rescue Exception => error
            puts error
            puts error.backtrace
            load_report.image_reports.create_failure(error, "", "")
          end
        end
      end
      load_report.update_counts
      load_report.save!
    end

    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      load_report.completed = true
      load_report.save!
      # LoaderMailer.load_alert(load_report, User.find_by_nuid(load_report.nuid)).deliver!
    end
  end

  def assign_a_row(row_results, core_file)
    core_file.mods.identifier = row_results["handle"]

    core_file.mods.title = row_results["title"]
    core_file.mods.title_info.sub_title = row_results["subtitle"] unless row_results["subtitle"].blank?
    core_file.mods.title_info.non_sort = row_results["title_initial_article"] unless row_results["title_initial_article"].blank?
    core_file.mods.alternate_title.title = row_results["alternate_title"] unless row_results["alternate_title"].blank?
    core_file.mods.alternate_title.non_sort = row_results["alternate_title_initial_article"] unless row_results["alternate_title_initial_article"].blank?
    core_file.mods.alternate_title.sub_title = row_results["alternate_subtitle"] unless row_results["alternate_subtitle"].blank?

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
          creator_hash['corporate_names'] << row_results["creator_#{n}_name"].split("|")[0].strip
        elsif name_type == 'personal'
          creator_hash['first_names'] << row_results["creator_#{n}_name"].split("|")[1].strip
          creator_hash['last_names'] << row_results["creator_#{n}_name"].split("|")[0].strip
        end
      end
      core_file.creators = creator_hash
      # assign primary
      if row_results["creator_1_name_type"] == "personal"
        core_file.mods.corporate_name(0).usage = nil
        core_file.mods.personal_name(0).usage = "primary"
      elsif row_results["creator_1_name_type"] == "corporate"
        core_file.mods.corporate_name(0).usage = "primary"
        core_file.mods.personal_name(0).usage = nil
      end
      creator_nums.each do |n|
        name_type = row_results["creator_#{n}_name_type"]
        role = row_results["creator_#{n}_role"]
        role_uri = row_results["creator_#{n}_role_value_uri"]
        affiliation = row_results["creator_#{n}_affliation"]
        authority = row_results["creator_#{n}_authority"].split("|")[0]
        authority_uri = row_results["creator_#{n}_authority"].split("|")[1]
        value_uri = row_results["creator_#{n}_name"].split("|").last
        if name_type == 'corporate'
          corp_creators = row_results.select { |key, value| key.to_s.match(/^creator_\d+_name_type$/) && value.to_s.match(/^corporate$/) }
          corp_nums = corp_creators.keys.map {|key| key.scan(/\d/)[0].to_i }
          corp_num = corp_nums.index(n) #this basically maps the row_results n number to the creator index since corp and pers are separate in the mods
          if !role.blank?
            core_file.mods.corporate_name(corp_num).role.role_term = role
            core_file.mods.corporate_name(corp_num).role.role_term.value_uri = role_uri unless role_uri.blank?
            core_file.mods.corporate_name(corp_num).role.role_term.authority = "marcrelator"
            core_file.mods.corporate_name(corp_num).role.role_term.authority_uri = "http://id.loc.gov/vocabulary/relators"
            core_file.mods.corporate_name(corp_num).role.role_term.type = "text"
          end
          core_file.mods.corporate_name(corp_num).affiliation = affiliation unless affiliation.blank?
          core_file.mods.corporate_name(corp_num).authority = authority.strip unless authority.blank?
          core_file.mods.corporate_name(corp_num).authority_uri = authority_uri.strip unless authority_uri.blank?
          core_file.mods.corporate_name(corp_num).value_uri = value_uri.strip unless value_uri.blank?
        elsif name_type == 'personal'
          personal_creators = row_results.select { |key, value| key.to_s.match(/^creator_\d+_name_type$/) && value.to_s.match(/^personal$/) }
          pers_nums = personal_creators.keys.map {|key| key.scan(/\d/)[0].to_i }
          pers_num = pers_nums.index(n)
          address = row_results["creator_#{n}_name"].split("|")[2]
          date = row_results["creator_#{n}_name"].split("|")[3]
          if !role.blank?
            core_file.mods.personal_name(pers_num).role.role_term = role
            core_file.mods.personal_name(pers_num).role.role_term.value_uri = role_uri unless role_uri.blank?
            core_file.mods.personal_name(pers_num).role.role_term.authority = "marcrelator"
            core_file.mods.personal_name(pers_num).role.role_term.authority_uri = "http://id.loc.gov/vocabulary/relators"
            core_file.mods.personal_name(pers_num).role.role_term.type = "text"
          end
          core_file.mods.personal_name(pers_num).affiliation = affiliation unless affiliation.blank?
          core_file.mods.personal_name(pers_num).authority = authority.strip unless authority.blank?
          core_file.mods.personal_name(pers_num).authority_uri = authority_uri.strip unless authority_uri.blank?
          core_file.mods.personal_name(pers_num).value_uri = value_uri.strip unless value_uri.blank?
          # core_file.mods.personal_name(pers_num).address = address.strip unless address.blank? #do not know correct mods for this field
          core_file.mods.personal_name(pers_num).name_part_date = date.strip unless date.blank?
        end
      end
    end

    core_file.mods.type_of_resource = row_results["type_of_resource"] unless row_results["type_of_resource"].blank?
    core_file.mods.genre = row_results["genre"] unless row_results["genre"].blank?
    core_file.mods.genre.authority = row_results["genre_authority"] unless row_results["genre_authority"].blank?
    if !row_results["date_created_end_date"].blank?
      core_file.mods.origin_info.date_created = row_results["date_created"]
      core_file.mods.origin_info.date_created.point = "start"
      core_file.mods.origin_info.date_created_end = row_results["date_created_end_date"]
      core_file.mods.origin_info.date_created.qualifier = row_results["approximate_inferred_questionable"] unless row_results["approximate_inferred_questionable"].blank?
      core_file.mods.origin_info.date_created_end.qualifier = row_results["approximate_inferred_questionable"] unless row_results["approximate_inferred_questionable"].blank?
    else
      core_file.mods.date = row_results["date_created"] unless row_results["date_created"].blank?
      core_file.mods.origin_info.date_created.qualifier = row_results["approximate_inferred_questionable"] unless row_results["approximate_inferred_questionable"].blank?
    end
    core_file.mods.origin_info.date_created.qualifier = row_results["approximate_inferred_questionable"] unless row_results["approximate_inferred_questionable"].blank?

    core_file.mods.origin_info.copyright = row_results["copyright_date"] unless row_results["copyright_date"].blank?
    core_file.mods.origin_info.date_issued = row_results["date_issued"] unless row_results["date_issued"].blank?
    core_file.mods.origin_info.publisher = row_results["publisher_name"] unless row_results["publisher_name"].blank?
    core_file.mods.origin_info.place.place_term = row_results["place_of_publication"] unless row_results["place_of_publication"].blank?
    core_file.mods.origin_info.edition = row_results["edition"] unless row_results["edition"].blank?
    core_file.mods.origin_info.issuance = row_results["issuance"] unless row_results["issuance"].blank?
    core_file.mods.origin_info.frequency = row_results["frequency"] unless row_results["frequency"].blank?
    core_file.mods.origin_info.frequency.authority = row_results["frequency_authority"] unless row_results["frequency_authority"].blank?
    core_file.mods.physical_description.extent = row_results["extent"] unless row_results["extent"].blank?
    core_file.mods.physical_description.digital_origin = row_results["digital_origin"] unless row_results["digital_origin"].blank?
    core_file.mods.physical_description.reformatting_quality = row_results["reformatting_quality"]
    if !row_results["language"].blank?
      core_file.mods.language.language_term = row_results["language"]
      core_file.mods.language.language_term.language_term_type = "text"
      core_file.mods.language.language_term.language_authority = "iso639-2b"
      core_file.mods.language.language_term.language_authority_uri = "http://id.loc.gov/vocabulary/iso639-2"
      core_file.mods.language.language_term.language_value_uri = row_results["language_uri"] unless row_results["language_uri"].blank?
    end
    core_file.mods.description = row_results["abstract"] unless row_results["abstract"].blank?
    core_file.mods.table_of_contents = row_results["table_of_contents"] unless row_results["table_of_contents"].blank?

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
    keywords = []
    topical_headings = row_results.select { |key, value| key.to_s.match(/^topic_\d+$/) }
    topical_headings.each do |topic|
      keywords << topic[1]
    end
    core_file.mods.topics = keywords #have to create the subject nodes first
    core_file.mods.subject.topic.each_with_index do |subject, key|
      if subject.include? "--"
        topics = []
        core_file.mods.subject(key).topic[0].split("--").each do |topic|
          topics << topic.strip
        end
        core_file.mods.subject(key).topic = topics
      else
        core_file.mods.subject(key).topic = subject
      end
      core_file.mods.subject(key).authority = row_results["topic_#{key+1}_authority"] unless row_results["topic_#{key+1}_authority"].blank? #adds authority if it is set, key begins from 0 but topics begin from 1 in spreadsheet
    end

    # this will probably be refactored
    name_subjects = []
    row_results["personal_name_subject_headings"].split(";").each do |name|
      name_subjects << {:personal => name.strip}
    end
    row_results["additional_personal_name_subject_headings"].split(";").each do |name|
      name_subjects << {:personal => name.strip}
    end
    row_results["corporate_name_subject_headings"].split(";").each do |name|
      name_subjects << {:corporate => name.strip}
    end
    row_results["additional_corporate"].split(";").each do |name|
      name_subjects << {:corporate => name.strip}
    end
    if name_subjects.length > 0
      core_file.mods.name_subjects = name_subjects
    end


    # for related items
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
    results["creator_1_authority"] = find_in_row(header_row, row_value, 'Creator 1 Authority')
    results["creator_1_name_type"] = find_in_row(header_row, row_value, 'Creator 1 Name Type')
    results["creator_1_role"] = find_in_row(header_row, row_value, 'Creator 1 Role')
    results["creator_1_role_value_uri"] = find_in_row(header_row, row_value, 'Creator 1 Role Value URI')
    results["creator_1_affiliation"] = find_in_row(header_row, row_value, 'Creator 1 Affiliation')

    results["creator_2_name"] = find_in_row(header_row, row_value, 'Creator 2 Name')
    results["creator_2_authority"] = find_in_row(header_row, row_value, 'Creator 2 Authority')
    results["creator_2_name_type"] = find_in_row(header_row, row_value, 'Creator 2 Name Type')
    results["creator_2_role"] = find_in_row(header_row, row_value, 'Creator 2 Role')
    results["creator_2_role_value_uri"] = find_in_row(header_row, row_value, 'Creator 2 Role Value URI')
    results["creator_2_affiliation"] = find_in_row(header_row, row_value, 'Creator 2 Affiliation')

    results["creator_3_name"] = find_in_row(header_row, row_value, 'Creator 3 Name')
    results["creator_3_authority"] = find_in_row(header_row, row_value, 'Creator 3 Authority')
    results["creator_3_name_type"] = find_in_row(header_row, row_value, 'Creator 3 Name Type')
    results["creator_3_role"] = find_in_row(header_row, row_value, 'Creator 3 Role')
    results["creator_3_role_value_uri"] = find_in_row(header_row, row_value, 'Creator 3 Role Value URI')
    results["creator_3_affiliation"] = find_in_row(header_row, row_value, 'Creator 3 Affiliation')

    results["creator_4_name"] = find_in_row(header_row, row_value, 'Creator 4 Name')
    results["creator_4_authority"] = find_in_row(header_row, row_value, 'Creator 4 Authority')
    results["creator_4_name_type"] = find_in_row(header_row, row_value, 'Creator 4 Name Type')
    results["creator_4_role"] = find_in_row(header_row, row_value, 'Creator 4 Role')
    results["creator_4_role_value_uri"] = find_in_row(header_row, row_value, 'Creator 4 Role Value URI')
    results["creator_4_affiliation"] = find_in_row(header_row, row_value, 'Creator 4 Affiliation')

    results["creator_5_name"] = find_in_row(header_row, row_value, 'Creator 5 Name')
    results["creator_5_authority"] = find_in_row(header_row, row_value, 'Creator 5 Authority')
    results["creator_5_name_type"] = find_in_row(header_row, row_value, 'Creator 5 Name Type')
    results["creator_5_role"] = find_in_row(header_row, row_value, 'Creator 5 Role')
    results["creator_5_role_value_uri"] = find_in_row(header_row, row_value, 'Creator 5 Role Value URI')
    results["creator_5_affiliation"] = find_in_row(header_row, row_value, 'Creator 5 Affiliation')

    results["type_of_resource"]                             = find_in_row(header_row, row_value, 'Type of Resource')
    results["genre"]                                        = find_in_row(header_row, row_value, 'Genre')
    results["genre_authority"]                                        = find_in_row(header_row, row_value, 'Genre Authority')
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
    results["frequency_authority"]                          = find_in_row(header_row, row_value, 'Frequency Authority')
    results["reformatting_quality"]                         = find_in_row(header_row, row_value, 'Reformatting Quality')
    results["extent"]                                       = find_in_row(header_row, row_value, 'Extent')
    results["digital_origin"]                               = find_in_row(header_row, row_value, 'Digital Origin')
    results["language"]                                     = find_in_row(header_row, row_value, 'Language')
    results["language_uri"]                                 = find_in_row(header_row, row_value, 'Language URI')
    results["abstract"]                                     = find_in_row(header_row, row_value, 'Abstract')
    results["table_of_contents"]                            = find_in_row(header_row, row_value, 'Table of Contents')
    results["acess_condition_restriction"]                  = find_in_row(header_row, row_value, 'Access Condition : Restriction on access')
    results["acess_condition_use_and_reproduction"]         = find_in_row(header_row, row_value, 'Access Condition : Use and Reproduction')
    results["provenance"]                                   = find_in_row(header_row, row_value, 'Provenance note')
    results["other_notes"]                                  = find_in_row(header_row, row_value, 'Other notes')
    results["topic_1"]                                      = find_in_row(header_row, row_value, 'Topical Subject Heading 1')
    results["topic_1_authority"]                            = find_in_row(header_row, row_value, 'Topical Subject Heading Authority 1')
    results["topic_2"]                                      = find_in_row(header_row, row_value, 'Topical Subject Heading 2')
    results["topic_2_authority"]                            = find_in_row(header_row, row_value, 'Topical Subject Heading Authority 2')
    results["topic_3"]                                      = find_in_row(header_row, row_value, 'Topical Subject Heading 3')
    results["topic_3_authority"]                            = find_in_row(header_row, row_value, 'Topical Subject Heading Authority 3')
    results["topic_4"]                                      = find_in_row(header_row, row_value, 'Topical Subject Heading 4')
    results["topic_4_authority"]                            = find_in_row(header_row, row_value, 'Topical Subject Heading Authority 4')
    results["topic_5"]                                      = find_in_row(header_row, row_value, 'Topical Subject Heading 5')
    results["topic_5_authority"]                            = find_in_row(header_row, row_value, 'Topical Subject Heading Authority 5')
    results["topic_6"]                                      = find_in_row(header_row, row_value, 'Topical Subject Heading 6')
    results["topic_6_authority"]                            = find_in_row(header_row, row_value, 'Topical Subject Heading Authority 6')
    results["topic_7"]                                      = find_in_row(header_row, row_value, 'Topical Subject Heading 7')
    results["topic_7_authority"]                            = find_in_row(header_row, row_value, 'Topical Subject Heading Authority 7')
    results["personal_name_subject_headings"]               = find_in_row(header_row, row_value, 'Personal Name Subject Headings')
    results["additional_personal_name_subject_headings"]    = find_in_row(header_row, row_value, 'Additional Personal Name Subject Headings')
    results["corporate_name_subject_headings"]              = find_in_row(header_row, row_value, 'Corporate Name Subject Headings')
    results["additional_corporate"]                       = find_in_row(header_row, row_value, 'Additional Corporate Name Subject Headings')
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
