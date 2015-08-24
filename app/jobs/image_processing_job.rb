class ImageProcessingJob
  attr_accessor :file, :file_name, :parent, :copyright, :report_id, :permissions
  include MimeHelper
  include HandleHelper

  def queue_name
    :loader_image_processing
  end

  def initialize(file, file_name, parent, copyright, report_id, permissions=[])
    self.file = file
    self.file_name = file_name
    self.parent = parent
    self.copyright = copyright
    self.report_id = report_id
    self.permissions = permissions
  end

  def run
    # extract metadata from iptc
    # if theres an exception, log details to image_report
    require 'fileutils'
    require 'mini_exiftool'
    MiniExiftool.command = '/opt/exiftool/exiftool'
    if !ENV['TRAVIS'].nil? && ENV['TRAVIS'] == 'true'
      MiniExiftool.command = '/usr/bin/exiftool/exiftool'
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
        report = load_report.image_reports.create_failure("File is not a JPG image", "", core_file.label)
        core_file.destroy
        FileUtils.rm(file)
      else
        classification = ''
        photo = MiniExiftool.new("#{file}", iptc_encoding: 'UTF8', exif_encoding: 'UTF8')
        photo.tags.each do |tag|
          val = photo[tag]
          iptc[:"#{tag}"] = val
          if !tag.nil? && !val.nil?
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

            if val.kind_of?(String) and (val.include? "“" or val.include? "”" or val.include? "‘" or val.include? "’")
              create_special_error("#{tag} contains invalid smart quotes", iptc, core_file, load_report)
              return
            elsif val.kind_of?(String) and (val.include? "—" or val.include? "—")
              create_special_error("#{tag} contains invalid em dash", iptc, core_file, load_report)
              return
            elsif val.kind_of?(String) and (val.include? "…")
              create_special_error("#{tag} contains invalid ellipsis", iptc, core_file, load_report)
              return
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
              pers = val.split(",")
              pers = {'first_names'=>[pers[1].strip], 'last_names'=>[pers[0].strip]}
              core_file.creators = pers
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
              core_file.mods.origin_info.place.city_term = val
            elsif tag == 'State'
              if val == "MA"
                core_file.mods.origin_info.place.state_term = "mau"
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
        if core_file.keywords.blank?
          create_special_error("Missing keyword(s)", iptc, core_file, load_report)
          return
        end

        # Featured Content tagging
        sc_type = core_file.parent.smart_collection_type

        if !sc_type.nil? && sc_type != ""
          core_file.category = sc_type
        end

        # Create a handle
        core_file.identifier = make_handle(core_file.persistent_url)
        core_file.mods.identifier.type = "handle"
        core_file.mods.identifier.display_label = "Permanent URL"

        # Process Thumbnail
        width = photo.imagewidth
        height =  photo.imageheight
        if width > height
          size = width
        else
          size = height
        end
        l = 1400.to_f/size.to_f
        m = 0.to_f/size.to_f
        s = 600.to_f/size.to_f

        permissions['CoreFile'].each do |perm, vals|
          vals.each do |group|
            core_file.rightsMetadata.permissions({group: group}, "#{perm}")
          end
        end
        Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename, nil, s, m, l))
        core_file.content_objects.each do |c|
          perms = permissions["#{c.klass}"]
          perms.each do |perm, vals|
            vals.each do |group|
              this_class = Object.const_get("#{c.klass}")
              this_obj = this_class.find("#{c.pid}")
              this_obj.rightsMetadata.permissions({group: group}, "#{perm}")
              this_obj.save!
            end
          end
        end

        if core_file.save!
          if core_file && !core_file.category.first.blank?
            UploadAlert.create_from_core_file(core_file, :create)
          end
        end
        report = load_report.image_reports.create_success(core_file, iptc)
      end
    rescue Exception => error
      pid = core_file.pid
      failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
      errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
      errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
      errors_for_pid.warn "#{Time.now} - #{$!}"
      errors_for_pid.warn "#{Time.now} - #{$@}"
      report = load_report.image_reports.create_failure(error.message, iptc, core_file.label)
      FileUtils.rm(file)
      core_file.destroy
      raise error
    end
  end

  def create_special_error(error_message, iptc, core_file, load_report)
    report = load_report.image_reports.create_failure(error_message, iptc, core_file.label)
    core_file.destroy
    FileUtils.rm(file)
    return report
  end
end
