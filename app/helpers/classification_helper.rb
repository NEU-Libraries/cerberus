# frozen_string_literal: true

module ClassificationHelper
  def assign_type(_file_path)
    Classification.work
  end

  def extract_mime_type(file_path); end
end
