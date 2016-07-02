class ProcessXmlZipJob
  include SpreadsheetHelper
  include XmlValidator
  include ApplicationHelper
  include ZipHelper

  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user, :permissions, :client, :report_id, :preview, :existing_files

  def queue_name
    :xml_loader_process_zip
  end

  def initialize(loader_name, zip_path, parent, copyright, current_user, permissions, report_id, client=nil, preview=nil)
    self.loader_name = loader_name
    self.zip_path = zip_path
    self.parent = parent
    self.copyright = copyright
    self.current_user = current_user
    self.permissions = permissions
    self.client = client
    self.report_id = report_id
    self.preview = preview
    self.existing_files = false #flag to determine if the spreadsheet as a whole is editing or creating files, goes off of first row which is tested on preview, that way the user knows if they're editing or creating before proceeding with the load
  end

  def run
    load_report = Loaders::LoadReport.find(report_id)

    # unzip zip file to tmp storage
    dir_path = File.join(File.dirname(zip_path), File.basename(zip_path, ".*"))
    spreadsheet_file_path = unzip(zip_path, dir_path)

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
            # load_report.comparison_file_pid = "NURTS"
            load_report.save!
          end

          preview_file.tmp_path = spreadsheet_file_path
          load_report.preview_file_pid = preview_file.pid
          # load_report.preview_file_pid = "BLERTS"
          load_report.save!

          # Load row of metadata in for preview
          assign_a_row(row_results, preview_file, dir_path)

          load_report.number_of_files = spreadsheet.last_row - header_position
          load_report.save!
        rescue Exception => error
          puts error
          puts error.backtrace
          return
        end
      end
    else # not a preview, process everything
      spreadsheet.each_row_streaming(offset: header_position) do |row|
        if row.present? && header_row.present?
          count = count + 1
          row_results = process_a_row(header_row, row)
          core_file = CoreFile.find(row_results["pid"])
          assign_a_row(row_results, core_file, dir_path)
        end
      end
    end

    load_report.update_counts
    load_report.number_of_files = count
    load_report.save!

    if load_report.success_count + load_report.fail_count + load_report.modified_count == load_report.number_of_files
      load_report.completed = true
      load_report.save!
    end
  end

  def assign_a_row(row_results, core_file, dir_path)
    xml_file_path = dir_path + "/" + row_results["xml_file_path"]
    if !xml_file_path.blank? && File.exists?(xml_file_path) && File.extname(xml_file_path) == ".xml"
      # Load mods xml and cleaning
      raw_xml = xml_decode(File.open(xml_file_path, "rb").read)

      # Validate
      validation_result = xml_valid?(raw_xml)

      if validation_result[:errors].blank?
        core_file.mods.content = raw_xml
        core_file.save!
        core_file.match_dc_to_mods

        # Report success
        load_report.image_reports.create_success(core_file, "")
      else
        # Raise error, invalid mods
        load_report.image_reports.create_failure("Invalid MODS", validation_result[:errors], row_results["file_name"])

        core_file = nil
      end
    else
      # Raise error, can't load core file mods metadata
      load_report.image_reports.create_failure("Can't load MODS XML", "", row_results["file_name"])

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

  def unzip(file, dir_path)
    spreadsheet_file_path = ""
    FileUtils.mkdir(dir_path) unless File.exists? dir_path

    # Extract load zip
    file_list = safe_unzip(file, dir_path)

    # Find the spreadsheet
    xlsx_array = Dir.glob("#{dir_path}/*.xlsx")

    if xlsx_array.length > 1
      raise Exceptions::MultipleSpreadsheetError
    elsif xlsx_array.length == 0
      raise Exceptions::NoSpreadsheetError
    end

    spreadsheet_file_path = xlsx_array.first

    FileUtils.rm(file)
    return spreadsheet_file_path
  end
end
