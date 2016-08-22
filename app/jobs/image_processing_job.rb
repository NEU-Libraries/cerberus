class ImageProcessingJob
  attr_accessor :file, :file_name, :parent, :copyright, :report_id, :permissions, :client, :derivatives
  include MimeHelper
  include HandleHelper
  include ApplicationHelper

  def queue_name
    :loader_image_processing
  end

  def initialize(file, file_name, parent, copyright, report_id, permissions=[], derivatives=false, client=nil)
    self.file = file
    self.file_name = file_name
    self.parent = parent
    self.copyright = copyright
    self.report_id = report_id
    self.permissions = permissions
    self.client = client
    self.derivatives = derivatives
  end

  def run
    # extract metadata from iptc
    # if theres an exception, log details to item_report
    require 'fileutils'
    require 'mini_exiftool'
    MiniExiftool.command = "#{Cerberus::Application.config.minitool_path}"
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
      core_file.properties.original_filename = File.basename(file_name)
      core_file.label = File.basename(file_name)

      core_file.instantiate_appropriate_content_object(file)
      if core_file.canonical_class != "ImageMasterFile" or extract_mime_type(file) != 'image/jpeg'
        report = load_report.item_reports.create_failure("File is not a JPG image", "", core_file.label)
        core_file.destroy
        FileUtils.rm(file)
      else
        classification = ''
        modified = false
        modified_message = ''
        photo = MiniExiftool.new("#{file}", iptc_encoding: 'UTF8', exif_encoding: 'UTF8')
        photo.tags.each do |tag|
          val = photo[tag]
          iptc[:"#{tag}"] = val
          if !tag.nil? && !val.nil? && !val.blank?
            if val.kind_of?(String) or val.kind_of?(Time)
              val = val
            elsif val.kind_of?(Integer) or val.kind_of?(Float) or val.kind_of?(Rational) or val.kind_of?(TrueClass) or val.kind_of?(FalseClass)
              val = String(val)
            elsif val.kind_of?(Array)
              val.map! do |i|
                if i.kind_of?(String) or i.kind_of?(Integer) or val.kind_of?(Float) or val.kind_of?(Time) or val.kind_of?(Rational) or val.kind_of?(TrueClass)
                  i = String(i)
                else
                  create_special_error("#{tag} contains #{val.class.name} data", iptc, core_file, load_report)
                  return
                end
              end
            else
              create_special_error("#{tag} contains #{val.class.name} data", iptc, core_file, load_report)
              return
            end

            # if val.kind_of?(String) and (val.include? "“" or val.include? "”" or val.include? "‘" or val.include? "’")
            #   create_special_error("#{tag} contains invalid smart quotes", iptc, core_file, load_report)
            #   return
            # elsif val.kind_of?(String) and (val.include? "—" or val.include? "—")
            #   create_special_error("#{tag} contains invalid em dash", iptc, core_file, load_report)
            #   return
            # elsif val.kind_of?(String) and (val.include? "…")
            #   create_special_error("#{tag} contains invalid ellipsis", iptc, core_file, load_report)
            #   return
            # end

            if val.kind_of?(String)
              raw_val = val
              # val = CGI.unescapeHTML(Unidecoder.decode(raw_val))
              val = xml_decode(raw_val)
              if val != raw_val
                modified_message = "#{tag} contained Unicode general punctuation. This has been replaced with the ASCII equivalent."
                modified = true
              end
            end

            if tag == 'Headline'
              core_file.title = val
            elsif tag == 'Category'
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
              else
                k = val.downcase
              end
              classification = k
              core_file.mods.classification = classification
            elsif tag == 'SupplementalCategories'
              s = ''
              if val.kind_of?(Array)
                val.each do |i|
                  if i.kind_of?(String)
                    s = s + " -- " + i.downcase
                    s = s.gsub("_", " ")
                  end
                end
                core_file.mods.classification = "#{classification}#{s}"
              else
                core_file.mods.classification = "#{classification}#{val}"
              end
            elsif tag == "By-line"
              if val.kind_of?(String)
                if val.include? ","
                  pers = val.split(",")
                  pers = {'first_names'=>[pers[1].strip], 'last_names'=>[pers[0].strip]}
                else
                  name_array = Namae.parse val
                  name_obj = name_array[0]
                  if !name_obj.nil? && !name_obj.given.blank? && !name_obj.family.blank?
                    pers = {'first_names'=>[name_obj.given], 'last_names'=>[name_obj.family]}
                    modified_message = "By-line parsed into Last Name, First Name format."
                    modified = true
                  else
                    create_special_error("Incorrectly formatted By-line", iptc, core_file, load_report)
                    return
                  end
                end
                core_file.creators = pers
              end
            elsif tag == 'By-lineTitle'
              core_file.mods.personal_name.role.role_term = val
              core_file.mods.personal_name.role.role_term.type = "text"
            elsif tag == 'Description'
              core_file.description = val
            elsif tag == 'Source'
              core_file.mods.origin_info.publisher = val
            elsif tag == "DateTimeOriginal"
              core_file.mods.origin_info.copyright = val.strftime("%F")
              core_file.date = val.strftime("%F")
            elsif tag == 'Keywords'
              if val.kind_of?(Array)
                core_file.keywords = val.map #(&:to_s)
              else
                core_file.keywords = ["#{val}"]
              end
            elsif tag == 'City'
              if !core_file.mods.origin_info.place.place_term.blank?
                core_file.mods.origin_info.place.place_term = val + "#{core_file.mods.origin_info.place.place_term.first}"
              else
                core_file.mods.origin_info.place.place_term = val
              end
            elsif tag == 'State'
              if !core_file.mods.origin_info.place.place_term.blank?
                core_file.mods.origin_info.place.place_term = "#{core_file.mods.origin_info.place.place_term.first} #{val}"
              else
                core_file.mods.origin_info.place.place_term = val
              end
            end
          end
          core_file.mods.genre = "photographs"
          core_file.mods.genre.authority = "aat"
          core_file.mods.physical_description.form = "electronic"
          core_file.mods.physical_description.form.authority = "marcform"
          core_file.mods.physical_description.digital_origin = "born digital"
          core_file.mods.physical_description.extent = "1 photograph"
          core_file.mods.access_condition = copyright
          core_file.mods.access_condition.type = "use and reproduction"
        end

        if core_file.title.blank?
          create_special_error("Missing title (IPTC Headline)", iptc, core_file, load_report)
          return
        end
        if core_file.keywords.first.blank?
          create_special_error("Missing keyword(s)", iptc, core_file, load_report)
          return
        end

        # Featured Content tagging
        sc_type = core_file.parent.smart_collection_type

        if !sc_type.nil? && sc_type != ""
          core_file.category = sc_type
        end

        # Create a handle
        core_file.identifier = make_handle(core_file.persistent_url, client)
        # core_file.mods.identifier.type = "handle"
        # core_file.mods.identifier.display_label = "Permanent URL"

        # Process Thumbnail
        width = photo.imagewidth
        height =  photo.imageheight
        if width > height
          size = width
        else
          size = height
        end
        if derivatives
          l = 1400.to_f/size.to_f
          m = 0.to_f/size.to_f
          s = 600.to_f/size.to_f
        else
          l = 0.to_f
          m = 0.to_f
          s = 0.to_f
        end

        permissions['CoreFile'].each do |perm, vals|
          vals.each do |group|
            if group.include? "northeastern"  #its a grouper group
              core_file.rightsMetadata.permissions({group: group}, "#{perm}")
            else #its an nuid for a user
              core_file.rightsMetadata.permissions({person: group}, "#{perm}")
            end
          end
        end
        Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename, nil, s, m, l, true, permissions))

        if core_file.save!
          UploadAlert.create_from_core_file(core_file, :create, "iptc")
        end
        if modified == true
          report = load_report.item_reports.create_modified(modified_message, core_file, iptc, :create)
        else
          report = load_report.item_reports.create_success(core_file, iptc, :create)
        end
      end
    rescue Exception => error
      pid = core_file.pid
      failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
      errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
      errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
      errors_for_pid.warn "#{Time.now} - #{$!}"
      errors_for_pid.warn "#{Time.now} - #{$@}"
      iptc = "" if iptc.empty?
      report = load_report.item_reports.create_failure(error.message, iptc, File.basename(file_name))
      FileUtils.rm(file)
      core_file.destroy
      raise error
    end
  end

  def create_special_error(error_message, iptc, core_file, load_report)
    report = load_report.item_reports.create_failure(error_message, iptc, core_file.label)
    core_file.destroy
    FileUtils.rm(file)
    return report
  end
end
