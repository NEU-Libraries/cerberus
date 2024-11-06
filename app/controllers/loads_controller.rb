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

    handle_processing_result(load_report, failures)
  end

  def process_images(image_entries, load_report_id, failures)
    image_entries.each do |entry|
      begin
        Tempfile.create(['image', File.extname(entry.name)], binmode: true) do |temp_file|
          temp_file.write(entry.get_input_stream.read)
          temp_file.flush

          raw_iptc = extract_raw_iptc(temp_file.path)

          if raw_iptc['Error'].present?
            failures << "Error extracting IPTC from #{entry.name}: #{raw_iptc['Error']}"
            next
          end

          image_data = File.binread(temp_file.path)

          ingest = IptcIngest.create_from_image_binary(
            entry.name,
            image_data,
            raw_iptc,
            load_report_id
          )

          ProcessIptcJob.perform_later(ingest.id)
        end
      rescue StandardError => e
        failures << "Error processing #{entry.name}: #{e.message}"
      end
    end
  end

  def process_manifest_zip(zip)
    failures = []
    load_report = LoadReport.create!(status: :in_progress)
    load_report.start_load

    begin
      Zip::File.open(zip) do |zip_file|
        manifest_file = zip_file.find_entry('manifest.xlsx')
        if manifest_file
          process_spreadsheet(manifest_file, zip_file, load_report.id, failures)
        else
          failures << 'Manifest file not found in ZIP.'
        end
      end
    rescue Zip::Error => e
      failures << "Error processing ZIP file: #{e.message}"
    end

    handle_processing_result(load_report, failures)
  end

  def process_spreadsheet(xlsx_file, zip_file, load_report_id, failures)
    spreadsheet_content = xlsx_file.get_input_stream.read
    spreadsheet = Roo::Spreadsheet.open(StringIO.new(spreadsheet_content), extension: :xlsx)

    success, error_message, headers = verify_and_assign_headers(spreadsheet, ["PIDs", "MODS XML File Path"])

    unless success
      failures << error_message
      return
    end

    process_spreadsheet_rows(spreadsheet, zip_file, headers, load_report_id, failures)
  rescue StandardError => e
    failures << "Error processing spreadsheet: #{e.message}"
  end

  def process_spreadsheet_rows(spreadsheet, zip_file, headers, load_report_id, failures)
    pid_column = headers["PIDs"]
    file_path_column = headers["MODS XML File Path"]

    spreadsheet.each_with_index do |row, index|
      next if index.zero? # Skip header row

      pid = row[pid_column]
      file_name = row[file_path_column]

      # Rails.logger.info "HERE GEORGE #{file_name} #{pid}"

      if pid.blank? || file_name.blank?
        failures << "Missing PID or filename in row #{index + 1}"
        next
      end

      queue_xml_metadata_update(zip_file, pid, file_name, load_report_id, index, failures)
    end
  end

  def queue_xml_metadata_update(zip_file, pid, file_name, load_report_id, row_index, failures)
    xml_entry = zip_file.find_entry(file_name)
    unless xml_entry
      failures << "#{file_name} file not found in ZIP"
      return
    end

    begin
      xml_content = xml_entry.get_input_stream.read

      # Create ingest record with XML content
      ingest = XmlIngest.create_from_spreadsheet_row(
        pid,
        file_name,
        xml_content,
        load_report_id
      )

      # Queue the update job
      UpdateMetadataJob.perform_later(ingest.id)
    rescue StandardError => e
      failures << "Error processing row #{row_index + 1}: #{e.message}"
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
      unless header_hash.key?(header_name)
        return nil
      end
      found_columns[header_name] = header_hash[header_name]
    end
    found_columns
  end

  def image_file?(filename)
    allowed_extensions = %w[.jpg .jpeg .png .gif .tiff .bmp]
    allowed_extensions.include?(File.extname(filename).downcase)
  end

  def extract_raw_iptc(file_path)
    photo = MiniExiftool.new(file_path)
    raw_data = photo.to_hash

    relevant_fields = {
      'Headline' => raw_data['Headline'],
      'Category' => raw_data['Category'],
      'SupplementalCategories' => raw_data['SupplementalCategories'],
      'By-line' => raw_data['By-line'],
      'By-lineTitle' => raw_data['By-lineTitle'],
      'Description' => raw_data['Description'],
      'Source' => raw_data['Source'],
      'DateTimeOriginal' => raw_data['DateTimeOriginal'], # Use preprocessed date
      'Keywords' => raw_data['Keywords'],
      'City' => raw_data['City'],
      'Subject' => raw_data['Subject'],
      'State' => raw_data['State'],
    }.compact

    if relevant_fields.empty?
      { 'Error' => 'No IPTC metadata found' }
    else
      relevant_fields
    end
  rescue StandardError => e
    { 'Error' => e.message }
  end

  def handle_processing_result(load_report, failures)
    if failures.empty?
      load_report&.finish_load
      redirect_to loads_path, notice: 'Upload processed successfully.'
    else
      load_report&.fail_load
      redirect_to loads_path, alert: "Errors occurred during processing: #{failures.join(', ')}"
    end
  end
end
