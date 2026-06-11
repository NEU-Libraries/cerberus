# frozen_string_literal: true

module XmlLoader
  # On-disk locations for a LoadReport's staged archive and its unpacked
  # contents. Mirrors the layout LoadsController#save_archive writes to
  # (uploads_root/load_reports/<id>/<filename>), shared by the preview
  # service and the unzip job so the path convention lives in one place.
  module Paths
    module_function

    def archive_path(load_report)
      File.join(root(load_report), load_report.source_filename)
    end

    def extracted_dir(load_report)
      File.join(root(load_report), 'extracted')
    end

    def root(load_report)
      File.join(
        Rails.application.config.x.cerberus.uploads_root,
        'load_reports',
        load_report.id.to_s
      )
    end
  end
end
