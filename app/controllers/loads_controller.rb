# frozen_string_literal: true

class LoadsController < ApplicationController
  # Toggle for now, will add auth features later
  def self.use_iptc_processing?
    true # Toggle this to switch between XML (false) and IPTC (true) processing
  end

  def index
    @load_reports = LoadReport.order(created_at: :desc)
  end

  def show
    @load_report = LoadReport.find(params[:id])
  end

  def create
    uploaded_file = params[:file]
    if uploaded_file
      if valid_zip?(uploaded_file)
        if self.class.use_iptc_processing?
          process_iptc_zip(uploaded_file.tempfile)
        else
          process_manifest_zip(uploaded_file.tempfile)
        end
      else
        redirect_to loads_path, alert: "Invalid file type: #{uploaded_file.content_type}. Please upload a ZIP file."
      end
    else
      redirect_to loads_path, alert: 'No file uploaded. Please select a ZIP file.'
    end
  end

  private

  def valid_zip?(file)
    file.content_type == 'application/zip' || file.content_type == 'application/x-zip-compressed'
  end

  def process_manifest_zip(zip)
    failures = []
    load_report = nil

    begin
      Zip::File.open(zip) do |zip_file|
        manifest_file = zip_file.find_entry('manifest.xlsx')
        if manifest_file
          load_report = process_spreadsheet(manifest_file, zip_file, failures)
        else
          failures << 'Manifest file not found in ZIP.'
        end
      end
    rescue Zip::Error => e
      failures << "Error processing ZIP file: #{e.message}"
    end

    if failures.empty?
      load_report&.finish_load
      redirect_to loads_path, notice: 'ZIP file processed successfully.'
    else
      load_report&.fail_load
      redirect_to loads_path, alert: "Errors occurred during processing: #{failures.join(', ')}"
    end
  end

  def process_iptc_zip(zip)
    failures = []
    load_report = LoadReport.create!(status: :in_progress)
    load_report.start_load

    begin
      Zip::File.open(zip) do |zip_file|
        image_entries = zip_file.select { |entry| entry.file? && entry.name.start_with?('jpgs/') && image_file?(entry.name) }

        if image_entries.empty?
          failures << 'No valid images found in the ZIP file.'
        else
          process_images(image_entries, load_report.id, failures)
        end
      end
    rescue Zip::Error => e
      failures << "Error processing ZIP file: #{e.message}"
    end

    if failures.empty?
      load_report.finish_load
      redirect_to loads_path, notice: 'Photos processed successfully.'
    else
      load_report.fail_load
      redirect_to loads_path, alert: "Errors occurred during processing: #{failures.join(', ')}"
    end
  end

  def image_file?(filename)
    allowed_extensions = %w[.jpg .jpeg .png .gif .tiff .bmp]
    allowed_extensions.include?(File.extname(filename).downcase)
  end

  def process_images(image_entries, load_report_id, failures)
    image_entries.each do |entry|
      begin
        image_data = entry.get_input_stream.read
        temp_file = Tempfile.new(['image', File.extname(entry.name)])
        temp_file.binmode
        temp_file.write(image_data)
        temp_file.rewind

        raw_iptc = extract_raw_iptc(temp_file.path)

        IptcIngest.create_from_image_binary(entry.name, raw_iptc, load_report_id)
      rescue StandardError => e
        failures << "Error processing #{entry.name}: #{e.message}"
      ensure
        temp_file&.close
        temp_file&.unlink
      end
    end
  end

  def extract_raw_iptc(file_path)
    photo = MiniExiftool.new(file_path)
    raw_data = photo.to_hash # We could just return this, if wanted.

    # Select only the IPTC-relevant fields we care about
    relevant_fields = {
      'Caption-Abstract' => raw_data['Caption-Abstract'],
      'Keywords' => raw_data['Keywords'],
      'By-line' => raw_data['By-line'],
      'By-lineTitle' => raw_data['By-lineTitle'],
      'City' => raw_data['City'],
      'State' => raw_data['State'],
      'Location' => raw_data['Location'],
      'Category' => raw_data['Category'],
      'Credit' => raw_data['Credit'],
      'Source' => raw_data['Source'],
      'Headline' => raw_data['Headline'],
      'CopyrightNotice' => raw_data['CopyrightNotice'],
      'DateCreated' => raw_data['DateCreated'],
      'Description' => raw_data['Description'],
      'Creator' => raw_data['Creator'],
      'SupplementalCategories' => raw_data['SupplementalCategories']
    }.compact

    if relevant_fields.empty?
      {'Error' => 'No IPTC metadata found'}
    else
      relevant_fields
    end
  rescue StandardError => e
    {'Error' => e.message}
  end

  def process_spreadsheet(xlsx_file, zip_file, failures)
    spreadsheet_content = xlsx_file.get_input_stream.read
    spreadsheet = Roo::Spreadsheet.open(StringIO.new(spreadsheet_content), extension: :xlsx)
    load_report = LoadReport.create!(status: :in_progress)
    load_report.start_load
    success, error_message, headers = verify_and_assign_headers(spreadsheet, ["PIDs", "MODS XML File Path"])
    if success
      queue_update_metadata_jobs(spreadsheet, zip_file, headers, load_report.id, failures)
      load_report
    else
      failures << error_message
      load_report
    end
  rescue StandardError => e
    failures << "Error processing spreadsheet: #{e.message}"
    load_report
  end

  def queue_update_metadata_jobs(spreadsheet, zip_file, headers, load_report_id, failures)
    pid_column = headers["PIDs"]
    file_path_column = headers["MODS XML File Path"]
    spreadsheet.each_with_index do |row, index|
      next if index.zero?
      pid = row[pid_column]
      file_name = row[file_path_column]
      if pid && file_name
        ingest = XmlIngest.create_from_spreadsheet_row(pid, file_name, load_report_id)
        xml_entry = zip_file.find_entry(file_name)
        if xml_entry
          xml_content = xml_entry.get_input_stream.read
          UpdateMetadataJob.perform_later(pid, xml_content, ingest.id)
        else
          ingest.update(status: :failed)
          failures << "#{file_name} file not found in ZIP"
        end
      else
        failures << "Missing PID or filename in row #{index + 1}"
      end
    end
  end

  def verify_and_assign_headers(spreadsheet, required_headers)
    header_columns = find_header_columns(spreadsheet, required_headers)

    unless header_columns.is_a?(Hash)
      return [false, "Failed to process header columns: unexpected format #{required_headers}", {}]
    end

    [true, nil, header_columns]
  end

  def find_header_columns(spreadsheet, header_names)
    header_row = spreadsheet.row(1)
    header_hash = {}
    header_row.each_with_index do |cell, index|
      header_hash[cell] = index
    end
    found_columns = {}
    header_names.each do |header_name|
      if header_hash.key?(header_name)
        found_columns[header_name] = header_hash[header_name]
      else
        return nil
      end
    end
    found_columns
  end
end


