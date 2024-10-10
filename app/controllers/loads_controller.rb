# frozen_string_literal: true

# There needs to be work done on ingests and whether or not they go into load_report
# as of right now as long as the files seem valid they make it into ingest and then attempt to load
# but that makes the success rate of load_report 100% pretty much always (not always correct).
# Also with some things it will look like it failed but all valid jobs haven't
class LoadsController < ApplicationController
  def index
    @load_reports = LoadReport.order(created_at: :desc)
  end

  def show
    @load_report = LoadReport.find(params[:id])
  end

  def create
    uploaded_file = params[:file]
    if uploaded_file
      if uploaded_file.content_type == 'application/zip' ||
        uploaded_file.content_type == 'application/x-zip-compressed'
        process_zip(uploaded_file.tempfile)
      else
        redirect_to loads_path, alert: "Invalid file type: #{uploaded_file.content_type}. Please upload a ZIP file."
      end
    else
      redirect_to loads_path, alert: 'No file uploaded. Please select a ZIP file.'
    end
  end

  private

  def process_zip(zip)
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

  def process_spreadsheet(xlsx_file, zip_file, failures)
    spreadsheet_content = xlsx_file.get_input_stream.read
    spreadsheet = Roo::Spreadsheet.open(StringIO.new(spreadsheet_content), extension: :xlsx)
    load_report = LoadReport.create!(status: :in_progress)
    load_report.start_load

    header_row = spreadsheet.row(1)
    header_hash = {}
    header_row.each_with_index do |cell, index|
      header_hash[cell] = index
    end
    if header_hash.key?("PIDs") && header_hash.key?("MODS XML File Path")
      pid_column = header_hash["PIDs"]
      file_path_column = header_hash["MODS XML File Path"]
      spreadsheet.each_with_index do |row, index|
        next if index.zero?
        pid = row[pid_column]
        file_name = row[file_path_column]
        if pid && file_name
          xml_entry = zip_file.find_entry(file_name)
          if xml_entry
            ingest = Ingest.create_from_spreadsheet_row(pid, file_name, load_report.id)
            xml_content = xml_entry.get_input_stream.read
            UpdateMetadataJob.perform_later(pid, xml_content, ingest.id)
          else
            failures << "#{file_name} file not found in ZIP"
          end
        else
          failures << "Missing PID or filename in row #{index + 1}"
        end
      end

      load_report
    else
      failures << "Cannot find header labels"
      load_report
    end
  rescue StandardError => e
    failures << "Error processing spreadsheet: #{e.message}"
    load_report
  end
end
