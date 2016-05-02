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
    results["file_name"]         = find_in_row(header_row, row_value, 'Filename')
    results["title"]             = find_in_row(header_row, row_value, 'Title')
    results["parent_filename"]   = find_in_row(header_row, row_value, 'Parent Filename')
    results["sequence"]          = find_in_row(header_row, row_value, 'Sequence')
    results["last_item"]         = find_in_row(header_row, row_value, 'Last Item')
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
