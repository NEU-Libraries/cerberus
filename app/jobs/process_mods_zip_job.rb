class ProcessModsZipJob
  include SpreadsheetHelper
  include XmlValidator
  include ApplicationHelper
  include ZipHelper
  include HandleHelper

  attr_accessor :loader_name, :spreadsheet_file_path, :parent, :copyright, :current_user, :permissions, :preview, :depositor, :client, :report_id

  def queue_name
    :mods_process_zip
  end

  def initialize(loader_name, spreadsheet_file_path, parent, copyright, current_user, permissions, report_id, depositor, preview=nil, client=nil)
    self.loader_name = loader_name
    self.spreadsheet_file_path = spreadsheet_file_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.preview = preview
    self.client = client
    self.report_id = report_id
    self.depositor = depositor
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
        begin
          row_results = process_a_row(header_row, row)
          # Process first row
          preview_file = CoreFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))

          if row_results["pid"].blank? && !row_results["file_name"].blank? #make new file
            preview_file.depositor = current_user.nuid
          else
            comparison_file = CoreFile.find(row_results["pid"])
            preview_file.depositor              = comparison_file.depositor
            preview_file.rightsMetadata.content = comparison_file.rightsMetadata.content
            load_report.comparison_file_pid = comparison_file.pid
          end
          preview_file.tmp_path = spreadsheet_file_path

          # Load row of metadata in for preview
          assign_a_row(row_results, preview_file)

          load_report.preview_file_pid = preview_file.pid
          load_report.number_of_files = spreadsheet.last_row - header_position

          load_report.save!
        rescue Exception => error
          puts error
          puts error.backtrace
          return
        end
      end
    else #not a preview
      spreadsheet.each_row_streaming(offset: header_position) do |row|
        if row.present? && header_row.present?
          begin
            row_results = process_a_row(header_row, row)
            if row_results.blank?
              # do nothing
            else
              existing_file = false
              old_mods = nil
              if row_results["pid"].blank? && !row_results["file_name"].blank? #make new file
                new_file = File.dirname(dir_path) + "/" + row_results["file_name"]
                if File.exists? new_file
                  if Cerberus::ContentFile.virus_check(File.new(new_file)) == 0
                    core_file = CoreFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
                    core_file.tag_as_in_progress
                    core_file.tmp_path = new_file
                    collection = !load_report.collection.blank? ? Collection.find(load_report.collection) : nil
                    core_file.parent = collection
                    core_file.properties.parent_id = collection.pid
                    core_file.depositor = depositor
                    core_file.rightsMetadata.content = collection.rightsMetadata.content
                    core_file.rightsMetadata.permissions({person: "#{depositor}"}, 'edit')
                    core_file.original_filename = row_results["file_name"]
                    core_file.label = row_results["file_name"]
                    core_file.instantiate_appropriate_content_object(new_file)
                    sc_type = collection.smart_collection_type
                    if !sc_type.nil? && sc_type != ""
                      core_file.category = sc_type
                    end
                    core_file.identifier = make_handle(core_file.persistent_url, client)
                    Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))
                  else
                    populate_error_report(load_report, existing_file, "File triggered failure for virus check", row_results, core_file, old_mods, header_row, row)
                    next
                  end
                else
                  populate_error_report(load_report, existing_file, "File specified does not exist", row_results, core_file, old_mods, header_row, row)
                  next
                end
              else
                existing_file = true
                if core_file_checks(row_results["pid"]) == true
                  core_file = CoreFile.find(row_results["pid"])
                  handle = core_file.identifier
                  old_mods = core_file.mods.content
                  core_file.mods.content = ModsDatastream.xml_template.to_xml
                  core_file.mods.identifier = handle
                else
                  populate_error_report(load_report, existing_file, core_file_checks(row_results["pid"]), row_results, core_file, old_mods, header_row, row)
                  next
                end
              end
              assign_a_row(row_results, core_file)
              if core_file.keywords.length < 1
                populate_error_report(load_report, existing_file, "Must have at least one keyword", row_results, core_file, old_mods, header_row, row)
                next
              elsif core_file.title.blank?
                populate_error_report(load_report, existing_file, "Must have a title", row_results, core_file, old_mods, header_row, row)
                next
              elsif !row_results["handle"].blank? && core_file.identifier != row_results["handle"]
                image_report = load_report.image_reports.create_modified("Handle does not match", core_file, row_results)
                image_report.title = core_file.title
                image_report.save!
              else
                raw_xml = xml_decode(core_file.mods.content)
                result = xml_valid?(raw_xml)
                if !result[:errors].blank?
                  error_list = ""
                  result[:errors].each do |entry|
                    error_list = error_list.concat("#{entry.class.to_s}: #{entry} </br></br> ")
                  end
                  populate_error_report(load_report, existing_file, error_list, row_results, core_file, old_mods, header_row, row)
                  next
                else
                  load_report.image_reports.create_success(core_file, "")
                end
              end
            end
          rescue Exception => error
            puts error
            puts error.backtrace
            populate_error_report(load_report, existing_file, error.messsage, row_results, core_file, old_mods, header_row, row)
            next
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
      # cleaning up
      FileUtils.rm(spreadsheet_file_path)
      FileUtils.rmdir(File.dirname(dir_path))
      if CoreFile.exists?(load_report.preview_file_pid)
        CoreFile.find(load_report.preview_file_pid).destroy
      elsif CoreFile.exists?(load_report.comparison_file_pid)
        CoreFile.find(load_report.comparison_file_pid).destroy
      end
    end
  end

  def assign_a_row(row_results, core_file)
    core_file.mods.title = row_results["title"]
    core_file.mods.title_info.sub_title = row_results["subtitle"] unless row_results["subtitle"].blank?
    core_file.mods.title_info.non_sort = row_results["title_initial_article"] unless row_results["title_initial_article"].blank?
    core_file.mods.alternate_title.title = row_results["alternate_title"] unless row_results["alternate_title"].blank?
    core_file.mods.alternate_title.non_sort = row_results["alternate_title_initial_article"] unless row_results["alternate_title_initial_article"].blank?
    core_file.mods.alternate_title.sub_title = row_results["alternate_subtitle"] unless row_results["alternate_subtitle"].blank?
    core_file.mods.title_info.supplied = "yes" if row_results["supplied_title"] == "supplied"

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
        role = row_results["creator_#{n}_role"].split("|")[0]
        role_uri = row_results["creator_#{n}_role"].split("|")[1]
        affiliation = row_results["creator_#{n}_affiliation"]
        authority = row_results["creator_#{n}_authority"].split("|")[0]
        authority_uri = row_results["creator_#{n}_authority"].split("|")[1]
        value_uri = row_results["creator_#{n}_name"].split("|")[1]
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
          core_file.mods.personal_name(pers_num).name_part_address = address.strip unless address.blank?
          core_file.mods.personal_name(pers_num).name_part_date = date.strip unless date.blank?
        end
      end
    end

    core_file.mods.type_of_resource = row_results["type_of_resource"] unless row_results["type_of_resource"].blank?
    if !row_results["genre"].blank?
      genre = row_results["genre"].split("|")[0]
      value_uri = row_results["genre"].split("|")[1]
      authority = row_results["genre_authority"].split("|")[0]
      authority_uri = row_results["genre_authority"].split("|")[1]
      core_file.mods.genre = genre.strip
      core_file.mods.genre.authority = authority.strip unless authority.blank?
      core_file.mods.genre.authority_uri = authority_uri.strip unless authority_uri.blank?
      core_file.mods.genre.value_uri = value_uri.strip unless value_uri.blank?
    end
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
      keywords << topic[1] if !topic.blank?
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
      core_file.mods.subject(key).authority = row_results["topic_#{key+1}_authority"] unless row_results["topic_#{key+1}_authority"].blank? #adds authority if it is set, key starts from 0 but topics start from 1 in spreadsheet
    end

    subj_count = core_file.mods.subject.count
    name_subjects = []
    name_headings = row_results.select { |key, value| key.to_s.match(/^subject_name_\d+$/) }
    name_headings.each_with_index do |name, i|
      if !name[1].blank?
        i = i + 1 #spreadsheet index starts with 1 not 0
        if row_results["subject_name_#{i}_type"] == "personal"
          name_subjects[i] = {:personal => name[1].strip}
        elsif row_results["subject_name_#{i}_type"] == "corporate"
          name_subjects[i] = {:corporate => name[1].split("|")[0].strip}
        end
      end
    end
    if name_subjects.length > 0
      core_file.mods.name_subjects = name_subjects
    end
    core_file.mods.subject.each_with_index do |sub, i|
      if !core_file.mods.subject(i).name.blank?
        n = i - subj_count + 1
        name_type = row_results["subject_name_#{n}_type"]
        affiliation = row_results["subject_name_#{n}_affiliation"]
        authority = row_results["subject_name_#{n}_authority"].split("|")[0]
        authority_uri = row_results["subject_name_#{n}_authority"].split("|")[1]
        value_uri = row_results["subject_name_#{n}"].split("|").last
        if name_type == 'corporate'
          corp_num = i
          core_file.mods.subject(corp_num).name.affiliation = affiliation unless affiliation.blank?
          core_file.mods.subject(corp_num).name.authority = authority.strip unless authority.blank?
          core_file.mods.subject(corp_num).name.authority_uri = authority_uri.strip unless authority_uri.blank?
          core_file.mods.subject(corp_num).name.value_uri = value_uri.strip unless value_uri.blank?
        elsif name_type == 'personal'
          pers_num = i
          name = row_results["subject_name_#{n}"].split("|")
          family = name[0]
          given = name[1]
          address = name[2]
          date = name[3]
          core_file.mods.subject(pers_num).name = "" #clean out the basic name and rebuild
          core_file.mods.subject(pers_num).name.name_part_family = family.strip unless family.blank?
          core_file.mods.subject(pers_num).name.name_part_given = given.strip unless given.blank?
          core_file.mods.subject(pers_num).name.affiliation = affiliation.strip unless affiliation.blank?
          core_file.mods.subject(pers_num).name.authority = authority.strip unless authority.blank?
          core_file.mods.subject(pers_num).name.authority_uri = authority_uri.strip unless authority_uri.blank?
          core_file.mods.subject(pers_num).name.value_uri = value_uri.strip unless value_uri.blank?
          core_file.mods.subject(pers_num).name.name_part_address = address.strip unless address.blank?
          core_file.mods.subject(pers_num).name.name_part_date = date.strip unless date.blank?
        end
      end
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
    core_file.mods.record_info.record_creation_date = DateTime.now.strftime("%F")
    core_file.mods.physical_description.form = "electronic"
    core_file.mods.physical_description.form.authority = "marcform"

    core_file.save!
    xml = core_file.mods.content
    doc = Nokogiri::XML(xml,&:noblanks)
    core_file.mods.content = doc.to_s

    core_file.save!
  end

  def process_a_row(header_row, row_value)
    results = Hash.new
    results["handle"]                           = find_in_row(header_row, row_value, 'What is handle for the digitized object?')
    results["user_name"]                        = find_in_row(header_row, row_value, 'What is your name?')
    results["pid"]                              = find_in_row(header_row, row_value, 'What is PID for the digitized object?')
    results["file_name"]                        = find_in_row(header_row, row_value, 'File Name')
    results["archives_identifier"]              = find_in_row(header_row, row_value, 'Archives Identifier')
    results["supplied_title"]                   = find_in_row(header_row, row_value, 'Is this a supplied title?')
    results["title_initial_article"]            = find_in_row(header_row, row_value, 'Title Initial Article')
    results["title"]                            = find_in_row(header_row, row_value, 'Title')
    results["subtitle"]                         = find_in_row(header_row, row_value, 'Subtitle')
    results["alternate_title_initial_article"]  = find_in_row(header_row, row_value, 'Alternate Title Initial Article')
    results["alternate_title"]                  = find_in_row(header_row, row_value, 'Alternate Title')
    results["alternate_subtitle"]               = find_in_row(header_row, row_value, 'Alternate Subtitle')

    creator_count = header_row.select{|n| n[/^Creator \d+ Name$/]} #have to add one for primary special case
    creator_count.each_with_index do |x, i|
      i = i+1 #ignore primary
      results["creator_#{i}_name"] = find_in_row(header_row, row_value, "Creator #{i} Name")
      results["creator_#{i}_authority"] = find_in_row(header_row, row_value, "Creator #{i} Authority")
      results["creator_#{i}_name_type"] = find_in_row(header_row, row_value, "Creator #{i} Name Type")
      results["creator_#{i}_role"] = find_in_row(header_row, row_value, "Creator #{i} Role")
      results["creator_#{i}_affiliation"] = find_in_row(header_row, row_value, "Creator #{i} Affiliation")
    end
    results["creator_1_name"] = find_in_row(header_row, row_value, "Creator 1 Name - Primary Creator") #primary special case
    results["creator_1_authority"] = find_in_row(header_row, row_value, "Creator 1 Authority")
    results["creator_1_name_type"] = find_in_row(header_row, row_value, "Creator 1 Name Type")
    results["creator_1_role"] = find_in_row(header_row, row_value, "Creator 1 Role")
    results["creator_1_affiliation"] = find_in_row(header_row, row_value, "Creator 1 Affiliation")

    results["type_of_resource"]                             = find_in_row(header_row, row_value, 'Type of Resource')
    results["genre"]                                        = find_in_row(header_row, row_value, 'Genre')
    results["genre_authority"]                              = find_in_row(header_row, row_value, 'Genre Authority')
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

    topic_count = header_row.select{|m| m[/^Topical Subject Heading \d+$/]}
    topic_count.each_with_index do |x, i|
      results["topic_#{i}"]                                      = find_in_row(header_row, row_value, "Topical Subject Heading #{i}")
      results["topic_#{i}_authority"]                            = find_in_row(header_row, row_value, "Topical Subject Heading Authority #{i}")
    end

    subject_count = header_row.select{|y| y[/^Subject Name \d+$/]}
    subject_count.each_with_index do |x, i|
      results["subject_name_#{i}"]                               = find_in_row(header_row, row_value, "Subject Name #{i}")
      results["subject_name_#{i}_authority"]                     = find_in_row(header_row, row_value, "Subject Name #{i} Authority")
      results["subject_name_#{i}_type"]                          = find_in_row(header_row, row_value, "Subject Name #{i} Name Type")
      results["subject_name_#{i}_affiliation"]                   = find_in_row(header_row, row_value, "Subject Name #{i} Affiliation")
    end

    results["original_title"]                               = find_in_row(header_row, row_value, 'Original Title') #updated cell title
    results["physical_location"]                            = find_in_row(header_row, row_value, 'What is the physical location for this object?')
    results["identifier"]                                   = find_in_row(header_row, row_value, 'What is the identifier for this object?')
    results["collection_title"]                             = find_in_row(header_row, row_value, 'Collection Title') #updated cell title
    results["series_title"]                                  = find_in_row(header_row, row_value, 'Series Title') #updated cell title
    return results
  end

  def find_in_row(header_row, row_value, column_identifier)
    0.upto header_row.length-1 do |row_pos|
      # Account for case insensitivity
      if !header_row[row_pos].blank?
        case header_row[row_pos].downcase
        when column_identifier.downcase
          return row_value[row_pos].to_s.strip || ""
        end
      end
    end
    return ""
  end

  def core_file_checks(pid)
    if !ActiveFedora::Base.exists?(pid)
      return "Core file #{pid} does not exist"
    else
      cf = ActiveFedora::Base.find(pid, :cast=>true)
      if cf.class != CoreFile
        return "pid #{pid} is not a CoreFile object"
      else
        doc = SolrDocument.new(cf.to_solr)
        if (cf.mods.title.blank? || cf.mods.subject.length < 1) || (doc.title.blank? || doc['subject_topic_tesim'].nil?)
          return "No title and/or keyword found for #{pid}"
        else
          if !cf.healthy?
            return "Core file is not healthy"
          else
            if cf.tombstoned? || cf.in_progress? || cf.incomplete?
              return "Core file has non-active state: tombstoned, incomplete, or in_progress"
            else
              return true
            end
          end
        end
      end
    end
  end

  def populate_error_report(load_report, existing_file, error, row_results, core_file, old_mods, header_row, row)
    if existing_file && core_file
      core_file.mods.content = old_mods
      core_file.save!
    else
      core_file.destroy if core_file
    end
    row_results = row_results.blank? ? nil : row_results
    if core_file
      title = core_file.title.blank? ? row_results["title"] : core_file.title
      original_file = core_file.original_filename.blank? ? row_results["file_name"] : core_file.original_filename
    else
      title = find_in_row(header_row, row, 'Title')
      original_file = find_in_row(header_row, row, 'File Name')
    end
    image_report = load_report.image_reports.create_failure(error, row_results, "")
    image_report.title = title
    image_report.original_file = original_file
    image_report.save!
  end
end
