class ProcessXmlZipJob
  include SpreadsheetHelper
  include XmlValidator
  include ApplicationHelper
  include ZipHelper

  attr_accessor :loader_name, :spreadsheet_file_path, :parent, :copyright, :current_user, :permissions, :client, :report_id, :preview, :existing_files, :depositor

  def queue_name
    :xml_loader_process_zip
  end

  def initialize(loader_name, spreadsheet_file_path, parent, copyright, current_user, permissions, report_id, depositor, preview=nil, client=nil)
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
    self.existing_files = false #flag to determine if the spreadsheet as a whole is editing or creating files, goes off of first row which is tested on preview, that way the user knows if they're editing or creating before proceeding with the load
  end

  def run
    load_report = Loaders::LoadReport.find(report_id)

    dir_path = File.dirname(spreadsheet_file_path)

    process_spreadsheet(dir_path, spreadsheet_file_path, load_report, preview, client)
  end

  def process_spreadsheet(dir_path, spreadsheet_file_path, load_report, preview, client)
    count = 0
    spreadsheet = load_spreadsheet(spreadsheet_file_path)

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

          if row_results["pid"].blank? && !row_results["file_name"].blank? #make new file
            preview_file.depositor = current_user.nuid
          else
            comparison_file = CoreFile.find(row_results["pid"])
            preview_file.depositor              = comparison_file.depositor
            preview_file.rightsMetadata.content = comparison_file.rightsMetadata.content
            load_report.comparison_file_pid = comparison_file.pid
            load_report.save!
          end

          preview_file.title                  = "derp"
          preview_file.tmp_path = spreadsheet_file_path
          preview_file.save!

          load_report.preview_file_pid = preview_file.pid
          load_report.save!

          # Load row of metadata in for preview
          assign_a_row(row_results, preview_file, dir_path, load_report)

          load_report.number_of_files = spreadsheet.last_row - header_position
          load_report.save!
        rescue Exception => error
          puts error
          puts error.backtrace
          # populate error report TODO
          return
        end
      end
    else # not a preview, process everything
      spreadsheet.each_row_streaming(offset: header_position) do |row|
        begin
          if row.present? && header_row.present?
            count = count + 1
            row_results = process_a_row(header_row, row)

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

                  if !row_results["embargoed"].blank? && row_results["embargoed"].downcase == "true"
                    core_file.embargo_release_date = row_results["embargo_date"]
                  end

                  assign_a_row(row_results, core_file, dir_path, load_report)
                  core_file.reload
                  core_file.tag_as_completed
                  core_file.save!

                else
                  populate_error_report(load_report, "File triggered failure for virus check", row_results, core_file, header_row, row)
                  next
                end
              else
                populate_error_report(load_report, "File specified does not exist", row_results, core_file, header_row, row)
                next
              end
            else #edit existing file
              core_file = CoreFile.find(row_results["pid"])
              assign_a_row(row_results, core_file, dir_path, load_report)
            end
          end
        rescue Exception => error
          puts error
          puts error.backtrace
          populate_error_report(load_report, error.message, row_results, core_file, header_row, row)
          next
        end
      end

      load_report.update_counts
      load_report.number_of_files = count
      load_report.save!
    end

    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      load_report.completed = true
      load_report.save!
    end
  end

  def assign_a_row(row_results, core_file, dir_path, load_report)
    xml_file_path = dir_path + "/" + row_results["xml_file_path"]

    puts "DGC DEBUG"
    puts "xml_file_path: #{xml_file_path}"
    puts "row_results: #{row_results.inspect}"

    if !xml_file_path.blank? && File.exists?(xml_file_path) && File.extname(xml_file_path) == ".xml"
      # Load mods xml and cleaning
      raw_xml = xml_decode(File.open(xml_file_path, "rb").read)
      # Validate
      validation_result = xml_valid?(raw_xml)

      if validation_result[:errors].blank?
        core_file.mods.content = raw_xml
        core_file.save!
        core_file.match_dc_to_mods
      else
        # Raise error, invalid mods
        core_file = nil
      end
    else
      # Raise error, can't load core file mods metadata
      core_file = nil
    end
  end

  def process_a_row(header_row, row_value)
    results = Hash.new
    results["pid"]                       = find_in_row(header_row, row_value, 'PIDs')
    results["xml_file_path"]             = find_in_row(header_row, row_value, 'MODS XML File Path')
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
            return row_value[row_pos].to_s || ""
        end
      end
    end
    return ""
  end

  def populate_error_report(load_report, error, row_results, core_file, header_row, row, existing_file = nil, old_mods = nil)
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

end
