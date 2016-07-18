class ProcessModsZipJob
  include SpreadsheetHelper
  include XmlValidator
  include ApplicationHelper
  include ZipHelper
  include HandleHelper

  attr_accessor :loader_name, :spreadsheet_file_path, :parent, :copyright, :current_user, :permissions, :preview, :depositor, :client, :report_id, :existing_files

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
    self.existing_files = false #flag to determine if the spreadsheet as a whole is editing or creating files, goes off of first row which is tested on preview, that way the user knows if they're editing or creating before proceeding with the load
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
            preview_file.mods.identifier = comparison_file.mods.identifier
            load_report.comparison_file_pid = comparison_file.pid
            preview_file.identifier = comparison_file.identifier
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
      existing_files = false
      start = header_position + 1
      end_row = spreadsheet.last_row.to_i
        (start..end_row).each do |x|
        row = spreadsheet.row(x)
        if row.present? && header_row.present?
          begin
            row_results = process_a_row(header_row, row)
            if x == start
              existing_files = set_existing_files(row_results)
            end
            if row_results.blank?
              # do nothing
            else
              existing_file = false
              old_mods = nil
              if row_results["pid"].blank? && !row_results["file_name"].blank? && existing_files == false #make new file
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
                  else
                    populate_error_report(load_report, existing_file, "File triggered failure for virus check", row_results, core_file, old_mods, header_row, row)
                    next
                  end
                else
                  populate_error_report(load_report, existing_file, "File specified does not exist", row_results, core_file, old_mods, header_row, row)
                  next
                end
              elsif existing_files == true
                existing_file = true
                if core_file_checks(row_results["pid"]) == true
                  blank_handle = false
                  core_file = CoreFile.find(row_results["pid"])
                  handle = core_file.identifier
                  if handle.blank?
                    blank_handle = true
                    xml = Nokogiri::XML(core_file.mods.content)
                    handle = xml.xpath("//mods:identifier[contains(., 'hdl.handle.net')]").text
                  end
                  old_mods = core_file.mods.content
                  core_file.mods.content = ModsDatastream.xml_template.to_xml
                  core_file.mods.identifier = handle
                else
                  populate_error_report(load_report, existing_file, core_file_checks(row_results["pid"]), row_results, core_file, old_mods, header_row, row)
                  next
                end
              else
                # mix match spreadsheet with new files and existing files
                populate_error_report(load_report, existing_file, "File was missing pid or file name", row_results, nil, old_mods, header_row, row)
                next
              end
              assign_a_row(row_results, core_file)
              if core_file.keywords.length < 1
                populate_error_report(load_report, existing_file, "Must have at least one keyword", row_results, core_file, old_mods, header_row, row)
              elsif core_file.title.blank?
                populate_error_report(load_report, existing_file, "Must have a title", row_results, core_file, old_mods, header_row, row)
              elsif (!row_results["handle"].blank? && core_file.identifier != row_results["handle"]) || blank_handle
                if handle.blank?
                  image_report = load_report.image_reports.create_modified("The loader was unable to detect a handle for the original file.", core_file, row_results)
                else
                  image_report = load_report.image_reports.create_modified("Handle does not match", core_file, row_results)
                end
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
                elsif core_file.canonical_class == "AudioFile" || core_file.canonical_class == "VideoFile"
                  if row_results["poster_path"].blank?
                    populate_error_report(load_report, existing_file, "Audio or Video File must have poster file", row_results, core_file, old_mods, header_row, row)
                  else
                    poster_path = File.dirname(dir_path) + "/" + row_results["poster_path"]
                    Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename, poster_path))
                    load_report.image_reports.create_success(core_file, "")
                  end
                else
                  if !existing_files
                    Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))
                  end
                  load_report.image_reports.create_success(core_file, "")
                end
              end
            end
          rescue Exception => error
            puts error
            puts error.backtrace
            populate_error_report(load_report, existing_file, error.message, row_results, core_file, old_mods, header_row, row)
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
    alternate_titles = row_results.select { |key, value| key.to_s.match(/^alternate_title_\d+$/) if !value.blank? }
    if alternate_titles.count > 0
      alt_titles_array = []
      i = 1
      alternate_titles.each do |key, title|
        if !title.blank?
          hash = {}
          hash[:title] = title
          hash[:non_sort] = row_results["alternate_title_#{i}_non_sort"] unless row_results["alternate_title_#{i}_non_sort"].blank?
          hash[:sub_title] = row_results["alternate_title_#{i}_subtitle"] unless row_results["alternate_title_#{i}_subtitle"].blank?
        end
        alt_titles_array << hash
        i = i + 1
      end
      core_file.mods.alternate_titles = alt_titles_array
    end

    core_file.mods.title_info.supplied = "yes" if row_results["supplied_title"] == "supplied"

    creators = row_results.select { |key, value| key.to_s.match(/^creator_\d+_name$/) if !value.blank? }
    creator_nums = creators.keys.map {|key| key.scan(/\d/)[0].to_i }
    if creators.count > 0
      creator_hash = {}
      creator_hash['corporate_names'] = []
      creator_hash['first_names'] = []
      creator_hash['last_names'] = []
      personal_creators = {}
      personal_creators['first_names'] = []
      personal_creators['last_names'] = []
      creator_nums.each do |n|
        if !row_results["creator_#{n}_name"].blank?
          name_type = row_results["creator_#{n}_name_type"]
          if name_type == 'corporate'
            creator_hash['corporate_names'] << row_results["creator_#{n}_name"].split("|")[0].strip
          elsif name_type == 'personal'
            first = row_results["creator_#{n}_name"].split("|")[1]
            first = first.blank? ? " " : first.strip
            personal_creators['first_names'] << first
            personal_creators['last_names'] << row_results["creator_#{n}_name"].split("|")[0].strip
          end
        end
      end
      core_file.creators = creator_hash
      core_file.mods.personal_creators = personal_creators
      # assign primary
      if row_results["creator_1_name_type"] == "personal"
        core_file.mods.corporate_name(0).usage = nil
        core_file.mods.personal_name(0).usage = "primary"
      elsif row_results["creator_1_name_type"] == "corporate"
        core_file.mods.corporate_name(0).usage = "primary"
        core_file.mods.personal_name(0).usage = nil
      end
      creator_nums.each do |n|
        if !row_results["creator_#{n}_name"].blank?
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
            name = row_results["creator_#{n}_name"].split("|")[0].strip
            if name.include? "--"
              name_parts = []
              name.split("--").each do |name_part|
                name_parts << name_part.strip
              end
              core_file.mods.corporate_name(corp_num).name_part = name_parts
            end
            if !role.blank?
              core_file.mods.corporate_name(corp_num).role.role_term = role.strip
              core_file.mods.corporate_name(corp_num).role.role_term.value_uri = role_uri.strip unless role_uri.blank?
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
            value_uri = row_results["creator_#{n}_name"].split("|")[4]
            if !role.blank?
              core_file.mods.personal_name(pers_num).role.role_term = role.strip
              core_file.mods.personal_name(pers_num).role.role_term.value_uri = role_uri.strip unless role_uri.blank?
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
    end

    core_file.mods.type_of_resource = row_results["type_of_resource"] unless row_results["type_of_resource"].blank?
    genres = row_results.select { |key, value| key.to_s.match(/^genre_\d+$/) if !value.blank? }
    if genres.count > 0 && !genres.values.blank?
      core_file.mods.genres = genres.values.map {|value| value.split("|")[0].strip }
      i=0
      genres.each do |key, genre|
        if !genre.blank?
          value_uri = row_results["genre_#{i+1}"].split("|")[1]
          authority = row_results["genre_authority_#{i+1}"].split("|")[0]
          authority_uri = row_results["genre_authority_#{i+1}"].split("|")[1]
          core_file.mods.genre(i).authority = authority.strip unless authority.blank?
          core_file.mods.genre(i).authority_uri = authority_uri.strip unless authority_uri.blank?
          core_file.mods.genre(i).value_uri = value_uri.strip unless value_uri.blank?
        end
        i=i+1
      end
    end
    if !row_results["date_created_end_date"].blank?
      core_file.mods.origin_info.date_created = row_results["date_created"] unless row_results["date_created"].blank?
      core_file.mods.origin_info.date_created.point = "start" unless row_results["date_created"].blank?
      core_file.mods.origin_info.date_created_end = row_results["date_created_end_date"]
      core_file.mods.origin_info.date_created.qualifier = row_results["approximate_inferred_questionable"] unless row_results["approximate_inferred_questionable"].blank?
      core_file.mods.origin_info.date_created_end.qualifier = row_results["approximate_inferred_questionable"] unless row_results["approximate_inferred_questionable"].blank?
    else
      core_file.mods.date = row_results["date_created"] unless row_results["date_created"].blank?
      core_file.mods.origin_info.date_created.qualifier = row_results["approximate_inferred_questionable"] unless row_results["approximate_inferred_questionable"].blank?
    end

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
    core_file.mods.physical_description.reformatting_quality = row_results["reformatting_quality"] unless row_results["reformatting_quality"].blank?
    languages = row_results.select { |key, value| key.to_s.match(/^language_\d+$/) if !value.blank? }
    if languages.count > 0 && !languages.values.blank?
      core_file.mods.languages = languages.values
      i=0
      languages.each do |key, language|
        if !language.blank?
          lang = language.split("|")[0]
          lang_uri = language.split("|")[1]
          core_file.mods.language(i).language_term = lang.strip
          core_file.mods.language(i).language_term.language_term_type = "text"
          core_file.mods.language(i).language_term.language_authority = "iso639-2b"
          core_file.mods.language(i).language_term.language_authority_uri = "http://id.loc.gov/vocabulary/iso639-2"
          core_file.mods.language(i).language_term.language_value_uri = lang_uri.strip unless lang_uri.blank?
        end
        i=i+1
      end
    end
    abstracts = row_results.select { |key, value| key.to_s.match(/^abstract_\d+$/) if !value.blank? }
    if abstracts.count > 0 && !abstracts.values.blank?
      core_file.mods.abstracts = abstracts.values
    end
    core_file.mods.table_of_contents = row_results["table_of_contents"] unless row_results["table_of_contents"].blank?

    access_conditions = []
    uses = row_results.select { |key, value| key.to_s.match(/^access_condition_use_and_reproduction_\d+$/) if !value.blank? }
    uses.each do |key, use|
      if !use.blank?
        access_conditions << {:type=>"use and reproduction", :value=>use}
      end
    end
    restrictions = row_results.select { |key, value| key.to_s.match(/^access_condition_restriction_\d+$/) if !value.blank? }
    restrictions.each do |key, restriction|
      if !restriction.blank?
        access_conditions << {:type=>"restriction on access", :value=>restriction}
      end
    end
    if !access_conditions.blank?
      core_file.mods.access_conditions = access_conditions
    end

    notes = []
    note_results = row_results.select { |key, value| key.to_s.match(/^notes_\d+$/) if !value.blank? }
    i = 1
    note_results.each do |key, note|
      if !note.blank?
        hash = {}
        hash[:note] = note
        hash[:type] = row_results["notes_#{i}_type"]
        notes << hash if !hash.blank? && !hash.values.blank?
      end
      i = i + 1
    end
    if !notes.blank?
      core_file.mods.notes = notes
    end

    # subjects/topics
    keywords = []
    topical_headings = row_results.select { |key, value| key.to_s.match(/^topic_\d+$/) if !value.blank? }
    topical_headings.each do |topic|
      keywords << topic[1] if !topic.blank?
    end
    core_file.mods.topics = keywords #have to create the subject nodes first
    core_file.mods.subject.topic.each_with_index do |subject, key|
      value_uri = ""
      if subject.include? "|"
        subject = subject.split("|")
        value_uri = subject[1].strip unless subject[1].strip.blank?
        subject = subject[0].strip
      end
      if subject.include? "--"
        topics = []
        subject.split("--").each do |topic|
          topics << topic.strip
        end
        core_file.mods.subject(key).topic = topics
      else
        core_file.mods.subject(key).topic = subject
      end
      authority = row_results["topic_#{key+1}_authority"].split("|")[0]
      authority_uri = row_results["topic_#{key+1}_authority"].split("|")[1]
      core_file.mods.subject(key).authority = authority.strip unless authority.blank?
      core_file.mods.subject(key).authority_uri = authority_uri.strip unless authority_uri.blank?
      core_file.mods.subject(key).value_uri = value_uri.strip unless value_uri.blank?
      #adds authority if it is set, key starts from 0 but topics start from 1 in spreadsheet
    end

    subj_count = core_file.mods.subject.count
    name_subjects = []
    name_headings = row_results.select { |key, value| key.to_s.match(/^subject_name_\d+$/) if !value.blank? }
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
        value_uri = row_results["subject_name_#{n}"].split("|")[1]
        if name_type == 'corporate'
          corp_num = i
          name = row_results["subject_name_#{n}"].split("|")[0].strip
          if name.include? "--"
            name_parts = []
            name.split("--").each do |name_part|
              name_parts << name_part.strip
            end
            core_file.mods.subject(corp_num).name.name_part = name_parts
          end
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
          value_uri = name[4]
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

    geog_subjects = row_results.select { |key, value| key.to_s.match(/^subject_geo_\d+$/) if !value.blank? }
    if geog_subjects.count > 0
      subj_count = core_file.mods.subject.count
      geo_array = []
      geog_subjects.each.with_index(1) do |geo, i|
        geo = row_results["subject_geo_#{i}"].split("|")[0]
        if !geo.blank?
          vals = geo.split("--")
          array = []
          vals.each do |val|
            array << val.strip if !val.blank?
          end
          geo_array << array
        end
      end
      core_file.mods.geog_subjects = geo_array
      core_file.mods.subject.each_with_index do |geo, i|
        if !core_file.mods.subject(i).geographic.blank?
          n = i - subj_count + 1
          value_uri = row_results["subject_geo_#{n}"].split("|")[1]
          authority = row_results["subject_geo_#{n}_authority"].split("|")[0]
          authority_uri = row_results["subject_geo_#{n}_authority"].split("|")[1]
          core_file.mods.subject(i).value_uri = value_uri.strip unless value_uri.blank?
          core_file.mods.subject(i).authority = authority.strip unless authority.blank?
          core_file.mods.subject(i).authority_uri = authority_uri.strip unless authority_uri.blank?
        end
      end
    end

    temporal_subjects = row_results.select { |key, value| key.to_s.match(/^subject_temporal_\d+$/) if !value.blank? }
    if temporal_subjects.count > 0
      subj_count = core_file.mods.subject.count
      temp_array = []
      temporal_subjects.each.with_index(1) do |temp, i|
        hash = {}
        this_temp = row_results["subject_temporal_#{i}"].strip
        hash[:dates] = []
        hash[:dates] << this_temp unless this_temp.blank?
        hash[:dates] << row_results["subject_temporal_#{i}_end"].strip unless row_results["subject_temporal_#{i}_end"].blank?
        hash[:point] = [] unless row_results["subject_temporal_#{i}_end"].blank?
        hash[:point] << "start" if !row_results["subject_temporal_#{i}"].blank? && !row_results["subject_temporal_#{i}_end"].blank?
        hash[:point] << "end" unless row_results["subject_temporal_#{i}_end"].blank?
        hash[:qualifier] = row_results["subject_temporal_#{i}_qualifier"].strip unless row_results["subject_temporal_#{i}_qualifier"].blank?
        temp_array << hash unless hash.blank? || hash.values.blank?
      end
      core_file.mods.temporal_subjects = temp_array
    end

    title_subjects = row_results.select { |key, value| (key.to_s.match(/^subject_title_\d+$/) || key.to_s.match(/^subject_alt_title_\d+$/)) if !value.blank? }
    if title_subjects.count > 0
      subj_count = core_file.mods.subject.count
      title_array = []
      alt_i = 1
      i = 1
      title_subjects.each do |key, title|
        if !title.blank?
          hash = {}
          hash[:title] = title
          if key.include? "alt"
            hash[:non_sort] = row_results["subject_alt_title_#{alt_i}_non_sort"] unless row_results["subject_alt_title_#{alt_i}_non_sort"].blank?
            hash[:sub_title] = row_results["subject_alt_title_#{alt_i}_subtitle"] unless row_results["subject_alt_title_#{alt_i}_subtitle"].blank?
            hash[:type] = "alternative"
            alt_i = alt_i + 1
          else
            hash[:non_sort] = row_results["subject_title_#{i}_non_sort"] unless row_results["subject_title_#{i}_non_sort"].blank?
            hash[:sub_title] = row_results["subject_title_#{i}_subtitle"] unless row_results["subject_title_#{i}_subtitle"].blank?
            i = i + 1
          end
          title_array << hash unless hash.blank? || hash.values.blank?
        end
      end
      core_file.mods.title_subjects = title_array unless title_array.blank?
    end

    geo_code_subjects = row_results.select { |key, value| key.to_s.match(/^subject_geo_code_\d+$/) if !value.blank? }
    if geo_code_subjects.count > 0
      subj_count = core_file.mods.subject.count
      geo_code_array = []
      geo_code_subjects.each.with_index(1) do |geo, i|
        geo = row_results["subject_geo_code_#{i}"].split("|")[0]
        if !geo.blank?
          geo_code_array << geo.strip
        end
      end
      core_file.mods.geo_code_subjects = geo_code_array
      core_file.mods.subject.each_with_index do |geo, i|
        if !core_file.mods.subject(i).geographic_code.blank?
          n = i - subj_count + 1
          value_uri = row_results["subject_geo_code_#{n}"].split("|")[1]
          authority = row_results["subject_geo_code_#{n}_authority"].split("|")[0]
          authority_uri = row_results["subject_geo_code_#{n}_authority"].split("|")[1]
          core_file.mods.subject(i).value_uri = value_uri.strip unless value_uri.blank?
          core_file.mods.subject(i).authority = authority.strip unless authority.blank?
          core_file.mods.subject(i).authority_uri = authority_uri.strip unless authority_uri.blank?
        end
      end
    end

    genre_subjects = row_results.select { |key, value| key.to_s.match(/^subject_genre_\d+$/) if !value.blank? }
    if genre_subjects.count > 0
      subj_count = core_file.mods.subject.count
      genre_array = []
      genre_subjects.each.with_index(1) do |genre, i|
        genre = row_results["subject_genre_#{i}"].split("|")[0]
        if !genre.blank?
          genre_array << genre.strip
        end
      end
      core_file.mods.genre_subjects = genre_array
      core_file.mods.subject.each_with_index do |genre, i|
        if !core_file.mods.subject(i).genre.blank?
          n = i - subj_count + 1
          value_uri = row_results["subject_genre_#{n}"].split("|")[1]
          authority = row_results["subject_genre_#{n}_authority"].split("|")[0]
          authority_uri = row_results["subject_genre_#{n}_authority"].split("|")[1]
          core_file.mods.subject(i).value_uri = value_uri.strip unless value_uri.blank?
          core_file.mods.subject(i).authority = authority.strip unless authority.blank?
          core_file.mods.subject(i).authority_uri = authority_uri.strip unless authority_uri.blank?
        end
      end
    end

    cartographic_subjects = row_results.select { |key, value| key.to_s.match(/^subject_cartographic_\d+/) if !value.blank? }
    cartographic_nums = cartographic_subjects.keys.map {|key| key.scan(/\d/)[0].to_i }
    cartographic_nums = cartographic_nums.uniq
    if cartographic_nums.count > 0
      subj_count = core_file.mods.subject.count
      carto_array = []
      cartographic_nums.each.with_index(1) do |i|
        scale = row_results["subject_cartographic_#{i}_scale"]
        projection = row_results["subject_cartographic_#{i}_projection"]
        coordinates = row_results["subject_cartographic_#{i}_coordinates"].split("|")[0]
        if !scale.blank? || !projection.blank? || !coordinates.blank?
          hash = {}
          hash[:scale] = scale unless scale.blank?
          hash[:projection] = projection unless projection.blank?
          hash[:coordinates] = coordinates.strip unless coordinates.blank?
        end
        carto_array << hash unless hash.blank? || hash.values.blank?
      end
      core_file.mods.cartographic_subjects = carto_array
      core_file.mods.subject.each_with_index do |carto, i|
        if !core_file.mods.subject(i).cartographics.blank?
          n = i - subj_count + 1
          value_uri = row_results["subject_cartographic_#{n}_coordinates"].split("|")[1]
          authority = row_results["subject_cartographic_#{n}_authority"].split("|")[0]
          authority_uri = row_results["subject_cartographic_#{n}_authority"].split("|")[1]
          core_file.mods.subject(i).value_uri = value_uri.strip unless value_uri.blank?
          core_file.mods.subject(i).authority = authority.strip unless authority.blank?
          core_file.mods.subject(i).authority_uri = authority_uri.strip unless authority_uri.blank?
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
    core_file.match_dc_to_mods
    core_file.save!
  end

  def process_a_row(header_row, row_value)
    results = Hash.new
    results["handle"]                           = find_in_row(header_row, row_value, 'What is handle for the digitized object?')
    results["user_name"]                        = find_in_row(header_row, row_value, 'What is your name?')
    results["pid"]                              = find_in_row(header_row, row_value, 'What is PID for the digitized object?')
    results["file_name"]                        = find_in_row(header_row, row_value, 'File Name')
    results["poster_path"]                      = find_in_row(header_row, row_value, 'File Name - Poster')
    results["archives_identifier"]              = find_in_row(header_row, row_value, 'Archives Identifier')
    results["supplied_title"]                   = find_in_row(header_row, row_value, 'Is this a supplied title?')
    results["title_initial_article"]            = find_in_row(header_row, row_value, 'Title Initial Article')
    results["title"]                            = find_in_row(header_row, row_value, 'Title')
    results["subtitle"]                         = find_in_row(header_row, row_value, 'Subtitle')

    alternate_titles = header_row.select{|m| m[/(?i)^Alternate Title \d+[ \f\t\v]*/] if !m.blank?}
    alternate_titles.each.with_index(1) do |x, i|
      results["alternate_title_#{i}"]                              = find_in_row(header_row, row_value, "Alternate Title #{i}")
      results["alternate_title_#{i}_non_sort"]                     = find_in_row(header_row, row_value, "Alternate Title #{i} Initial Article")
      results["alternate_title_#{i}_subtitle"]                     = find_in_row(header_row, row_value, "Alternate Title #{i} Subtitle")
    end

    creators = header_row.select{|n| n[/(?i)^Creator \d+ Name[ \f\t\v]*/] if !n.blank?} #have to add one for primary special case
    creators.each.with_index(2) do |x, i|
      results["creator_#{i}_name"] = find_in_row(header_row, row_value, "Creator #{i} Name")
      if !results["creator_#{i}_name"].blank?
        results["creator_#{i}_authority"] = find_in_row(header_row, row_value, "Creator #{i} Authority")
        results["creator_#{i}_name_type"] = find_in_row(header_row, row_value, "Creator #{i} Name Type").downcase
        results["creator_#{i}_role"] = find_in_row(header_row, row_value, "Creator #{i} Role")
        results["creator_#{i}_affiliation"] = find_in_row(header_row, row_value, "Creator #{i} Affiliation")
      else
        results["creator_#{i}_authority"] = ""
        results["creator_#{i}_name_type"] = ""
        results["creator_#{i}_role"] = ""
        results["creator_#{i}_affiliation"] = ""
      end
    end
    results["creator_1_name"] = find_in_row(header_row, row_value, "Creator 1 Name - Primary Creator") #primary special case
    results["creator_1_authority"] = find_in_row(header_row, row_value, "Creator 1 Authority")
    results["creator_1_name_type"] = find_in_row(header_row, row_value, "Creator 1 Name Type")
    results["creator_1_role"] = find_in_row(header_row, row_value, "Creator 1 Role")
    results["creator_1_affiliation"] = find_in_row(header_row, row_value, "Creator 1 Affiliation")

    results["type_of_resource"]                             = find_in_row(header_row, row_value, 'Type of Resource')
    genres = header_row.select{|m| m[/(?i)^Genre \d+[ \f\t\v]*/] if !m.blank?}
    genres.each.with_index(1) do |x, i|
      results["genre_#{i}"] = find_in_row(header_row, row_value, "Genre #{i}")
      results["genre_authority_#{i}"] = find_in_row(header_row, row_value, "Genre Authority #{i}")
    end
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

    languages = header_row.select{|m| m[/(?i)^Language \d+[ \f\t\v]*/] if !m.blank?}
    languages.each.with_index(1) do |x, i|
      results["language_#{i}"]                              = find_in_row(header_row, row_value, "Language #{i}")
    end
    abstracts = header_row.select{|m| m[/(?i)^Abstract \d+[ \f\t\v]*/] if !m.blank?}
    abstracts.each.with_index(1) do |x, i|
      results["abstract_#{i}"]                              = find_in_row(header_row, row_value, "Abstract #{i}")
    end
    results["table_of_contents"]                            = find_in_row(header_row, row_value, 'Table of Contents')
    restrictions = header_row.select{|m| m[/(?i)^Access Condition : Restriction on access \d+[ \f\t\v]*/] if !m.blank?}
    restrictions.each.with_index(1) do |x, i|
      results["access_condition_restriction_#{i}"]          = find_in_row(header_row, row_value, "Access Condition : Restriction on access #{i}")
    end
    uses = header_row.select{|m| m[/(?i)^Access Condition : Use and Reproduction \d+[ \f\t\v]*/] if !m.blank?}
    uses.each.with_index(1) do |x, i|
      results["access_condition_use_and_reproduction_#{i}"] = find_in_row(header_row, row_value, "Access Condition : Use and Reproduction #{i}")
    end
    notes = header_row.select{|m| m[/(?i)^Note \d+[ \f\t\v]*/] if !m.blank?}
    notes.each.with_index(1) do |x, i|
      results["notes_#{i}"]                                 = find_in_row(header_row, row_value, "Note #{i}")
      results["notes_#{i}_type"]                            = find_in_row(header_row, row_value, "Note #{i} Attribute")
    end
    results["original_title"]                               = find_in_row(header_row, row_value, 'Original Title')
    results["physical_location"]                            = find_in_row(header_row, row_value, 'What is the physical location for this object?')
    results["identifier"]                                   = find_in_row(header_row, row_value, 'What is the identifier for this object?')
    results["collection_title"]                             = find_in_row(header_row, row_value, 'Collection Title')
    results["series_title"]                                 = find_in_row(header_row, row_value, 'Series Title')

    topics = header_row.select{|m| m[/(?i)^Topical Subject Heading \d+[ \f\t\v]*/] if !m.blank?}
    topics.each.with_index(1) do |x, i|
      results["topic_#{i}"]                                      = find_in_row(header_row, row_value, "Topical Subject Heading #{i}")
      results["topic_#{i}_authority"]                            = find_in_row(header_row, row_value, "Topical Subject Heading Authority #{i}")
    end

    subjects = header_row.select{|y| y[/(?i)^Name Subject Heading \d+[ \f\t\v]*/] if !y.blank?}
    subjects.each.with_index(1) do |x, i|
      results["subject_name_#{i}"]                               = find_in_row(header_row, row_value, "Name Subject Heading #{i}")
      results["subject_name_#{i}_authority"]                     = find_in_row(header_row, row_value, "Name Subject Heading Authority #{i}")
      results["subject_name_#{i}_type"]                          = find_in_row(header_row, row_value, "Name Subject Heading Name Type #{i}").downcase
      results["subject_name_#{i}_affiliation"]                   = find_in_row(header_row, row_value, "Name Subject Heading Affiliation #{i}")
    end

    geog_subjects = header_row.select{|y| y[/(?i)^Geographic Subject Heading \d+[ \f\t\v]*/] if !y.blank?}
    geog_subjects.each.with_index(1) do |x, i|
      results["subject_geo_#{i}"]                               = find_in_row(header_row, row_value, "Geographic Subject Heading #{i}")
      results["subject_geo_#{i}_authority"]                     = find_in_row(header_row, row_value, "Geographic Subject Heading Authority #{i}")
    end

    temporal_subjects = header_row.select{|y| y[/(?i)^Temporal Subject Heading \d+[ \f\t\v]*/] if !y.blank?}
    temporal_subjects.each.with_index(1) do |x, i|
      results["subject_temporal_#{i}"]                          = find_in_row(header_row, row_value, "Temporal Subject Heading #{i}")
      results["subject_temporal_#{i}_end"]                      = find_in_row(header_row, row_value, "Temporal Subject Heading End Date #{i}")
      results["subject_temporal_#{i}_qualifier"]                = find_in_row(header_row, row_value, "Temporal Subject Heading Qualifier #{i}")
    end

    title_subjects = header_row.select{|y| y[/(?i)^Title Subject \d+[ \f\t\v]*/] if !y.blank?}
    title_subjects.each.with_index(1) do |x, i|
      results["subject_title_#{i}"]                             = find_in_row(header_row, row_value, "Title Subject #{i}")
      results["subject_title_#{i}_non_sort"]                    = find_in_row(header_row, row_value, "Title Subject Initial Article #{i}")
      results["subject_title_#{i}_subtitle"]                    = find_in_row(header_row, row_value, "Title Subject Subtitle #{i}")
    end
    alt_title_subjects = header_row.select{|y| y[/(?i)^Title Subject Alternate Title \d+[ \f\t\v]*/] if !y.blank?}
    alt_title_subjects.each.with_index(1) do |x, i|
      results["subject_alt_title_#{i}"]                         = find_in_row(header_row, row_value, "Title Subject Alternate Title #{i}")
      results["subject_alt_title_#{i}_non_sort"]                = find_in_row(header_row, row_value, "Title Subject Alternate Title Initial Article #{i}")
      results["subject_alt_title_#{i}_subtitle"]                = find_in_row(header_row, row_value, "Title Subject Alternate Title Subtitle #{i}")
    end
    geo_code_subjects = header_row.select {|y| y[/(?i)^Geographic Code Subject Heading \d+[ \f\t\v]*/] if !y.blank?}
    geo_code_subjects.each.with_index(1) do |x, i|
      results["subject_geo_code_#{i}"]                          = find_in_row(header_row, row_value, "Geographic Code Subject Heading #{i}")
      results["subject_geo_code_#{i}_authority"]                = find_in_row(header_row, row_value, "Geographic Code Subject Heading Authority #{i}")
    end
    genre_subjects = header_row.select {|y| y[/(?i)^Genre Subject \d+[ \f\t\v]*/] if !y.blank?}
    genre_subjects.each.with_index(1) do |x, i|
      results["subject_genre_#{i}"]                             = find_in_row(header_row, row_value, "Genre Subject #{i}")
      results["subject_genre_#{i}_authority"]                   = find_in_row(header_row, row_value, "Genre Subject Authority #{i}")
    end
    cartographic_subjects = header_row.select {|key| key.to_s.match(/(?i)^Cartographics Subject [a-zA-Z]* \d+[ \f\t\v]*/) if !key.blank?}
    carto_nums = cartographic_subjects.map {|key| key.scan(/\d/)[0].to_i }
    carto_nums.uniq.each.with_index(1) do |x, i|
      results["subject_cartographic_#{i}_coordinates"]          = find_in_row(header_row, row_value, "Cartographics Subject Coordinates #{i}")
      results["subject_cartographic_#{i}_scale"]                = find_in_row(header_row, row_value, "Cartographics Subject Scale #{i}")
      results["subject_cartographic_#{i}_projection"]           = find_in_row(header_row, row_value, "Cartographics Subject Projection #{i}")
      results["subject_cartographic_#{i}_authority"]            = find_in_row(header_row, row_value, "Cartographics Subject Authority #{i}")
    end

    return results
  end

  def find_in_row(header_row, row_value, column_identifier)
    0.upto header_row.length-1 do |row_pos|
      # Account for case insensitivity
      if !header_row[row_pos].blank?
        case header_row[row_pos].downcase.strip
        when column_identifier.downcase.strip
          value = row_value[row_pos].to_s || ""
          if !value.blank? && value != ""
            return value.strip
          else
            return value
          end
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
    row_results = row_results.blank? ? nil : row_results
    if core_file
      if existing_file && CoreFile.exists?(core_file.pid)
        core_file.mods.content = old_mods
        core_file.save!
      else
        core_file.destroy if CoreFile.exists?(core_file.pid)
      end
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

  def set_existing_files(row_results)
    if row_results["pid"].blank? && !row_results["file_name"].blank?
      return false
    else
      return true
    end
  end
end
