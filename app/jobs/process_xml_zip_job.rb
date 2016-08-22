class ProcessXmlZipJob
  include SpreadsheetHelper
  include XmlValidator
  include ApplicationHelper
  include ZipHelper
  include HandleHelper

  attr_accessor :loader_name, :spreadsheet_file_path, :parent, :copyright, :current_user, :permissions, :client, :report_id, :preview, :existing_files, :depositor, :mods_content

  def queue_name
    :xml_loader_process_zip
  end

  def initialize(loader_name, spreadsheet_file_path, parent, copyright, current_user, permissions, report_id, existing_files, depositor, preview=nil, client=nil)
    self.loader_name = loader_name
    self.spreadsheet_file_path = spreadsheet_file_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.client = client
    self.report_id = report_id
    self.preview = preview
    self.depositor = depositor
    self.existing_files = existing_files #flag to determine if the spreadsheet as a whole is editing or creating files, goes off of first row which is tested on preview, that way the user knows if they're editing or creating before proceeding with the load
    self.mods_content = ""
  end

  def run
    load_report = Loaders::LoadReport.find(report_id)

    dir_path = File.dirname(spreadsheet_file_path)

    process_spreadsheet(dir_path, spreadsheet_file_path, load_report, preview, client)
  end

  def process_spreadsheet(dir_path, spreadsheet_file_path, load_report, preview, client)
    sentinel = nil

    count = 0
    spreadsheet = load_spreadsheet(spreadsheet_file_path)
    if spreadsheet.first_row.nil?
      raise "Your upload could not be processed because the submitted .zip file contains an empty spreadsheet."
      return
    end

    header_position = 1
    header_row = spreadsheet.row(header_position)

    core_file = nil

    if !preview.nil?
      row = spreadsheet.row(header_position + 1)
      if row.present? && header_row.present?
        begin
          row_results = process_a_row(header_row, row)
          # Process first row
          preview_file = CoreFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
          if row_results["file_name"].blank? && row_results["pid"].blank?
            raise "Your upload could not be processed because the spreadsheet is missing file names or PIDs. Please update the spreadsheet and try again."
            return
          elsif row_results["pid"].blank? && !row_results["file_name"].blank? && existing_files == true
            raise "Your upload could not be processed because the submitted .zip file contains new files. Please update the .zip file or select the \"New Files + Metadata\" option."
            return
          elsif !row_results["pid"].blank? && existing_files == false
            raise "Your upload could not be processed because the submitted .zip file does not contain any files. Please update the .zip file or select the \"Metadata Only\" upload option."
            return
          end

          if row_results["pid"].blank? && !row_results["file_name"].blank? #make new file
            preview_file.depositor = current_user.nuid
          else
            if !row_results["pid"].start_with?("neu:")
              raise "Your upload could not be processed because the PID is incorrectly formatted."
            end
            comparison_file = CoreFile.find(row_results["pid"])
            preview_file.depositor              = comparison_file.depositor
            preview_file.rightsMetadata.content = comparison_file.rightsMetadata.content
            preview_file.mods.identifier = comparison_file.mods.identifier
            load_report.comparison_file_pid = comparison_file.pid
            preview_file.identifier = comparison_file.identifier
            if load_report.collection.blank?
              load_report.collection = comparison_file.parent.pid
              collection = comparison_file.parent.pid
            end
            load_report.save!
          end

          preview_file.tmp_path = spreadsheet_file_path
          preview_file.save!

          load_report.preview_file_pid = preview_file.pid
          load_report.save!

          # Load row of metadata in for preview
          assign_a_row(row_results, preview_file, dir_path)

          load_report.number_of_files = spreadsheet.last_row - header_position
          load_report.save!
        rescue Exception => error
          xml_file_path = dir_path + "/" + row_results["xml_file_path"]
          if !xml_file_path.blank? && File.exists?(xml_file_path) && File.extname(xml_file_path) == ".xml"
            raw_xml = xml_decode(File.open(xml_file_path, "r").read)
          else
            rax_xml = ""
          end
          if !preview_file.mods.content.blank?
            item_report_info = row_results
            item_report_info["mods"] = preview_file.mods.content
          elsif !raw_xml.blank?
            item_report_info = row_results
            item_report_info["mods"] = raw_xml
          else
            item_report_info = row_results
          end
          item_report = load_report.item_reports.create_failure(error.to_s, item_report_info, "", true)
          item_report.title = preview_file.title
          item_report.original_file = find_in_row(header_row, row, 'File Name')
          item_report.save!
          load_report.completed = true
          load_report.fail_count = 1
          load_report.save!
          FileUtils.rm(spreadsheet_file_path)
          if CoreFile.exists?(load_report.preview_file_pid)
            CoreFile.find(load_report.preview_file_pid).destroy
          end
          raise error.to_s
          return
        end
      else
        raise "XML Files does not exist at the path specified. Please update the spreadsheet and try again."
      end
    else # not a preview, process everything
      existing_files = false
      x = 0
      start = header_position + 1
      end_row = spreadsheet.last_row.to_i
      (start..end_row).each do |this_row|
        row = spreadsheet.row(this_row)
        if row.present? && header_row.present?
          begin
            count = count + 1
            row_results = process_a_row(header_row, row)
            if x == 0
              existing_files = set_existing_files(row_results)
            end
            if row_results.blank?
              # do nothing
            else
              existing_file = false
              old_mods = nil
              if row_results["pid"].blank? && !row_results["file_name"].blank? #make new file
                new_file = dir_path + "/" + row_results["file_name"]
                if File.exists? new_file
                  if Cerberus::ContentFile.virus_check(File.new(new_file)) == 0
                    core_file = CoreFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
                    core_file.tag_as_in_progress
                    core_file.tmp_path = new_file
                    collection = !load_report.collection.blank? ? Collection.find(load_report.collection) : nil
                    core_file.parent = collection
                    core_file.properties.parent_id = collection.pid
                    core_file.depositor = depositor

                    # Does the collection have a sentinel?
                    if collection.sentinel
                      sentinel = collection.sentinel
                    else
                      core_file.rightsMetadata.content = collection.rightsMetadata.content
                    end

                    core_file.rightsMetadata.permissions({person: "#{depositor}"}, 'edit')
                    core_file.original_filename = row_results["file_name"]
                    core_file.label = row_results["file_name"]
                    core_file.instantiate_appropriate_content_object(new_file)
                    sc_type = collection.smart_collection_type
                    if !sc_type.nil? && sc_type != ""
                      core_file.category = sc_type
                    end
                    assign_a_row(row_results, core_file, dir_path)
                    core_file.identifier = make_handle(core_file.persistent_url, client)
                    core_file.save!

                    if !row_results["embargoed"].blank? && row_results["embargoed"].to_s.downcase == "true"
                      if row_results["embargo_date"].blank?
                        populate_error_report(load_report, existing_file, "Embargoed content must include an embargo release date", row_results, core_file, old_mods, header_row, row)
                        x = x+1
                        next
                      else
                        if row_results["embargo_date"].match(/\d{4}-\d{2}-\d{2}/)
                          core_file.embargo_release_date = row_results["embargo_date"]
                          core_file.save!
                        else
                          populate_error_report(load_report, existing_file, "Embargo date must follow format YYYY-MM-DD", row_results, core_file, old_mods, header_row, row)
                          x = x+1
                          next
                        end
                      end
                    end
                  else
                    populate_error_report(load_report, existing_file, "File triggered failure for virus check", row_results, core_file, old_mods, header_row, row)
                    x = x+1
                    next
                  end
                else
                  populate_error_report(load_report, existing_file, "File specified does not exist", row_results, core_file, old_mods, header_row, row)
                  x = x+1
                  next
                end
              elsif existing_files == true #edit existing file
                existing_file = true
                if !row_results["pid"].start_with?("neu:")
                  populate_error_report(load_report, existing_file, "PID is incorrectly formatted", row_results, core_file, old_mods, header_row, row)
                  x = x+1
                  next
                elsif core_file_checks(row_results["pid"]) == true
                  core_file = CoreFile.find(row_results["pid"])
                  old_mods = core_file.mods.content
                  core_file.mods.content = ModsDatastream.xml_template.to_xml
                  assign_a_row(row_results, core_file, dir_path)
                else
                  populate_error_report(load_report, existing_file, core_file_checks(row_results["pid"]), row_results, core_file, old_mods, header_row, row)
                  x = x+1
                  next
                end
              else #mismatch
                populate_error_report(load_report, existing_file, "File was missing pid or file name", row_results, nil, old_mods, header_row, row)
                x = x+1
                next
              end
              if existing_files == true && old_mods == core_file.mods.content
                load_report.item_reports.create_success(core_file, "", :update)
                x = x+1
                core_file.mods.content = old_mods
                core_file.save!
                next
              elsif core_file.keywords.length < 1
                populate_error_report(load_report, existing_file, "Must have at least one keyword", row_results, core_file, old_mods, header_row, row)
              elsif core_file.title.blank?
                populate_error_report(load_report, existing_file, "Must have a title", row_results, core_file, old_mods, header_row, row)
              elsif core_file.identifier.blank?
                populate_error_report(load_report, existing_file, "Must have a handle", row_results, core_file, old_mods, header_row, row)
              else
                if (core_file.canonical_class == "AudioFile" || core_file.canonical_class == "VideoFile") && !existing_files
                  if row_results["poster_path"].blank?
                    populate_error_report(load_report, existing_file, "Audio or Video File must have poster file", row_results, core_file, old_mods, header_row, row)
                  else
                    poster_path = dir_path + "/" + row_results["poster_path"]
                    Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename, poster_path))
                    load_report.item_reports.create_success(core_file, "", :create)
                    UploadAlert.create_from_core_file(core_file, :create, "xml")
                    x = x+1
                    next
                  end
                else
                  if !existing_files
                    Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))
                    UploadAlert.create_from_core_file(core_file, :create, "xml")
                    load_report.item_reports.create_success(core_file, "", :create)
                  else
                    distance = DamerauLevenshtein.distance(old_mods, core_file.mods.content, 1, 10000)
                    if distance > 0
                      UploadAlert.create_from_core_file(core_file, :update, "xml")
                      load_report.item_reports.create_success(core_file, "", :update)
                    end
                  end
                  x = x+1
                  next
                end
              end
            end
          rescue Exception => error
            populate_error_report(load_report, existing_file, error.message, row_results, core_file, old_mods, header_row, row)
            x = x+1
          end
        end
      end
      load_report.update_counts
      load_report.number_of_files = count
      load_report.save!
    end

    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      load_report.completed = true
      load_report.save!
      LoaderMailer.load_alert(load_report, User.find_by_nuid(load_report.nuid)).deliver!
      # cleaning up
      FileUtils.rm(spreadsheet_file_path)
      if CoreFile.exists?(load_report.preview_file_pid)
        CoreFile.find(load_report.preview_file_pid).destroy
      end
    end
  end

  def assign_a_row(row_results, core_file, dir_path)
    core_file.reload
    xml_file_path = dir_path + "/" + row_results["xml_file_path"]

    if !xml_file_path.blank? && File.exists?(xml_file_path) && File.extname(xml_file_path) == ".xml"
      raw_xml = xml_decode(File.open(xml_file_path, "r").read)
      self.mods_content = raw_xml
      # Validate
      validation_result = xml_valid?(raw_xml)

      if validation_result[:errors].blank?
        core_file.mods.content = raw_xml
        core_file.save!
        core_file.match_dc_to_mods

      else
        error_list = ""
        validation_result[:errors].each do |entry|
          error_list = error_list.concat("#{entry.class.to_s}: #{entry};")
        end
        core_file = nil
        raise error_list
      end
    else
      # Raise error, can't load core file mods metadata
      raise "Your upload could not be processed becuase the XML files could not be found."
      core_file = nil
    end
  end

  def process_a_row(header_row, row_value)
    results = Hash.new
    results["pid"]                       = find_in_row(header_row, row_value, 'PIDs')
    results["xml_file_path"]             = find_in_row(header_row, row_value, 'MODS XML File Path')
    results["poster_path"]               = find_in_row(header_row, row_value, 'File Name - Poster')
    # If new file
    results["file_name"]                 = find_in_row(header_row, row_value, 'File Name')
    results["embargoed"]                 = find_in_row(header_row, row_value, 'Embargoed?')
    results["embargo_date"]              = find_in_row(header_row, row_value, 'Embargo Date')
    return results
  end

  def find_in_row(header_row, row_value, column_identifier)
    0.upto header_row.length do |row_pos|
      if !header_row[row_pos].blank?
        # Account for case insensitivity
        case header_row[row_pos].downcase
        when column_identifier.downcase
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
      if old_mods
        core_file.mods.content = old_mods
        core_file.save!
      elsif !existing_file
        core_file.destroy if CoreFile.exists?(core_file.pid)
      end
      title = core_file.title.blank? ? row_results["title"] : core_file.title
      original_file = core_file.original_filename.blank? ? row_results["file_name"] : core_file.original_filename
    elsif !row_results.nil?
      title = find_in_row(header_row, row, 'Title')
      original_file = find_in_row(header_row, row, 'File Name')
    else
      title = ""
      original_file = ""
    end
    if !self.mods_content.blank?
      item_report_info = row_results
      item_report_info["mods"] = self.mods_content
    else
      item_report_info = row_results
    end
    item_report = load_report.item_reports.create_failure(error, item_report_info, "", false)
    item_report.title = title
    item_report.original_file = original_file
    item_report.save!
  end

  def set_existing_files(row_results)
    if row_results["pid"].blank? && !row_results["file_name"].blank?
      return false
    else
      return true
    end
  end
end
