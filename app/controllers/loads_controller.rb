# frozen_string_literal: true

require 'zip'
require 'roo'

class LoadsController < ApplicationController
  def index
    @ingests = Ingest.order(created_at: :desc)
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
    Zip::File.open(zip) do |zip_file|
      manifest_file = zip_file.find_entry('manifest.xlsx')
      if manifest_file
        process_spreadsheet(manifest_file, zip_file)
      else
        redirect_to loads_path, alert: 'Manifest file not found in ZIP.'
      end
    end
  rescue Zip::Error => e
    redirect_to loads_path, alert: "Error processing ZIP file: #{e.message}"
  end

  def process_spreadsheet(xlsx_file, zip_file)
    spreadsheet_content = xlsx_file.get_input_stream.read
    spreadsheet = Roo::Spreadsheet.open(StringIO.new(spreadsheet_content), extension: :xlsx)

    spreadsheet.each_with_index do |row, index|
      next if index.zero?
      pid = row[0]
      file_name = row[1]
      if pid && file_name
        xml_entry = zip_file.find_entry(file_name)
        if xml_entry
          ingest = Ingest.create_from_spreadsheet_row(row)
          xml_content = xml_entry.get_input_stream.read
          UpdateMetadataJob.perform_later(pid, xml_content, ingest.id)
          redirect_to loads_path, notice: 'ZIP file processed successfully.'
        else
          redirect_to loads_path, alert: 'XML file not found in ZIP.'
        end
      end
    end
  rescue StandardError => e
    redirect_to loads_path, alert: "Error processing spreadsheet: #{e.message}"
  end
end
