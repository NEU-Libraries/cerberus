class ProcessMultipageZipJob
  include SpreadsheetHelper

  attr_accessor :loader_name, :zip_path, :parent, :copyright, :current_user, :permissions, :client

  def queue_name
    :multipage_process_zip
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
    spreadsheet_file_path = unzip(zip_path, load_report, client)

    process_spreadsheet(spreadsheet_file_path)
  end

  def process_spreadsheet(spreadsheet_file_path)
    ss = load_spreadsheet(spreadsheet_file_path)
  end

  def process_a_row(header_row, row_value)
    file_name         = find_in_row(header_row, row_value, 'Filename')
    title             = find_in_row(header_row, row_value, 'Title')
    parent_filename   = find_in_row(header_row, row_value, 'Parent Filename')
    sequence          = find_in_row(header_row, row_value, 'Sequence')
    last_item         = find_in_row(header_row, row_value, 'Last Item')
  end

  def unzip(file, load_report, client)
    spreadsheet_file_path = ""

    Zip::File.open(file) do |zipfile|
      to = File.join(File.dirname(file), File.basename(file, ".*"))
      FileUtils.mkdir(to) unless File.exists? to
      count = 0

      # Extract all files
      zipfile.each do |f|
        if !f.directory? && File.basename(f.name)[0] != "." # Don't extract directories or mac specific files
          fpath = File.join(to, f.name)
          FileUtils.mkdir_p(File.dirname(fpath))
          zipfile.extract(f, fpath) unless File.exist?(fpath)
        end
      end

      # Find the spreadsheet
      xlsx_array = Dir.glob("#{Rails.application.config.tmp_path}/1442429470-31/*.xlsx")

      if xlsx_array.length > 1
        raise Exceptions::MultipleSpreadsheetError
      elsif xlsx_array.length == 0
        raise Exceptions::NoSpreadsheetError
      end

      spreadsheet_file_path = xlsx_array.first
    end

    FileUtils.rm(file)
    return spreadsheet_file_path
  end
end
