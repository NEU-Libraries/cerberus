class ImageProcessingJob
  attr_accessor :file, :parent, :copyright, :report_id
  include MimeHelper

  def queue_name
    :loader_image_processing
  end

  def initialize(file, parent, copyright, report_id)
    self.file = file
    self.parent = parent
    self.copyright = copyright
    self.report_id = report_id
  end

  def run
    # extract metadata from iptc
    # if theres an exception, log details to image_report
    require 'fileutils'
    job_id = "#{Time.now.to_i}-loader-image"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/loader-image-process-job.log")
    iptc = {}
    load_report = Loaders::LoadReport.find(report_id)
    begin
      core_file = ::CoreFile.new
      core_file.depositor = "000000000"
      core_file.parent = Collection.find(parent)
      core_file.properties.parent_id = core_file.parent.pid
      core_file.tag_as_in_progress
      core_file.tmp_path = file
      core_file.properties.original_filename = File.basename(file)
      core_file.label = File.basename(file)

      core_file.instantiate_appropriate_content_object(file)
      if core_file.canonical_class != "ImageMasterFile" or extract_mime_type(file) != 'image/jpeg'
        report = load_report.image_reports.create_failure("File is not a JPG image", "", core_file.label)
        core_file.destroy
        load_report.update_counts
      else
        classification = ''
        #handle special characters like smart quotes and ampersands
        encoding_options = {
          :invalid           => :replace,  # Replace invalid byte sequences
          :undef             => :replace,  # Replace anything not defined in ASCII
          :replace           => '',        # Use a blank for those replacements
          :universal_newline => true       # Always break lines with \n
        }
        photo = IPTC::JPEG::Image.from_file file, quick=true
        photo.values.each do |item|
          val = item.value
          if val.kind_of?(String)
            val = val.encode(Encoding.find('ASCII'), encoding_options)
          end
          iptc[:"#{item.key}"] = val
          if item.key == 'iptc/Headline'
            core_file.title = val
          elsif item.key == 'iptc/Category'
            if val == "ALU"
              k = "alumni"
            elsif val == "ATH"
              k = "athletics"
            elsif val == "CAM"
              k = "campus"
            elsif val == "CLA"
              k = "classroom"
            elsif val == "COM"
              k = "community outreach"
            elsif val == "EXPERIENTIAL LEARNING"
              k = val.downcase
            elsif val == "HEA"
              k = "headshots"
            elsif val == "POR"
              k = "portraits"
            elsif val == "PRE"
              k = "president"
            elsif val == "RES"
              k = "research"
            end
            classification = k
            core_file.mods.classification = classification
          elsif item.key == 'iptc/SuppCategory'
            s = ''
            if val.kind_of?(Array)
              val.each do |i|
                if i.kind_of?(String)
                  s = s + " -- " + i.downcase
                end
              end
              core_file.mods.classification = "#{classification}#{s}"
            else
              core_file.mods.classification = "#{classification}#{val}"
            end
          elsif item.key == "iptc/Byline"
            pers = val.split(",")
            # pers = {:first_names=>[pers[1].strip], :last_names=>[pers[0].strip]}
            # core_file.creators = pers
            core_file.mods.personal_name.name_part_given = pers[1].strip
            core_file.mods.personal_name.name_part_family = pers[0].strip
          elsif item.key == 'iptc/BylineTitle'
            core_file.mods.personal_name.role.role_term = val
            core_file.mods.personal_name.role.role_term.type = "text"
          elsif item.key == 'iptc/Caption'
            core_file.description = val
          elsif item.key == 'iptc/Source'
            core_file.mods.origin_info.publisher = val
          elsif item.key == "iptc/DateCreated"
            core_file.mods.origin_info.copyright = "#{val[0..3]}-#{val[4..5]}-#{val[6..7]}"
            core_file.date = "#{val[0..3]}-#{val[4..5]}-#{val[6..7]}"
          elsif item.key == 'iptc/Keywords'
            if val.kind_of?(Array)
              core_file.keywords = val
            else
              core_file.keywords = ["#{val}"]
            end
          elsif item.key == 'iptc/City'
            # core_file.mods.origin_info.place.term = val
            # core_file.mods.origin_info.place.term.type = "text"
          elsif item.key == 'iptc/ProvinceState'
            # if val == "MA"
            #   core_file.mods.origin_info.place.term = "mau"
            #   core_file.mods.origin_info.place.term.type = "code"
            #   core_file.mods.origin_info.place.term.authority = "marccountry"
            # end
          end
          core_file.mods.genre = "photographs"
          core_file.mods.genre.authority = "aat"
          core_file.mods.physical_description.digital_origin = "born digital"
          core_file.mods.physical_description.extent = "1 photograph"
          core_file.mods.access_condition = copyright
          core_file.mods.access_condition.type = "use and reproduction"
        end

        # Featured Content tagging
        sc_type = core_file.parent.smart_collection_type

        if !sc_type.nil? && sc_type != ""
          core_file.category = sc_type
        end

        # Create a handle
        core_file.identifier = make_handle(core_file.persistent_url)

        # Process Thumbnail - this doens't actually seem to be working right now - I might not be passing the right params TO DO
        Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))
        core_file.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

        if core_file.save!
          if core_file && !core_file.category.first.blank?
            UploadAlert.create_from_core_file(core_file, :create)
          end
        end
        report = load_report.image_reports.create_success(core_file, iptc)
        load_report.update_counts
      end
    rescue Exception => error
      pid = core_file.pid
      failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
      errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
      errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
      errors_for_pid.warn "#{Time.now} - #{$!}"
      errors_for_pid.warn "#{Time.now} - #{$@}"
      report = load_report.image_reports.create_failure(error.message, iptc, core_file.label)
      core_file.destroy
      load_report.update_counts
    end
  end
end
