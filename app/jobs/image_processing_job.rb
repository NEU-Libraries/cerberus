class ImageProcessingJob
  attr_accessor :file, :parent, :copyright

  def queue_name
    :loader_image_processing
  end

  def initialize(file, parent, copyright)
    self.file = file
    self.parent = parent
    self.copyright = copyright
  end

  def run
    # extract metadata from iptc
    # if theres an exception, log details to image_report
    require 'fileutils'
    job_id = "#{Time.now.to_i}-loader-image"
    FileUtils.mkdir_p "#{Rails.root}/log/#{job_id}"
    failed_pids_log = Logger.new("#{Rails.root}/log/#{job_id}/loader-image-process-job.log")

    begin
      core_file = ::CoreFile.new
      core_file.depositor = "000000000"
      core_file.parent = Collection.find(parent)
      core_file.properties.parent_id = core_file.parent.pid
      core_file.tag_as_in_progress
      # Context derived attributes
      core_file.tmp_path = file
      core_file.properties.original_filename = File.basename(file)
      core_file.label = File.basename(file)

      core_file.instantiate_appropriate_content_object(file)
      if core_file.canonical_class != "ImageMasterFile"
        #create failure report because it isn't an image
        core_file.destroy
      else
        classification = ''
        photo = IPTC::JPEG::Image.from_file file, quick=true
        photo.values.each do |item|
          puts "#{item.key}\t#{item.value}"
          if item.key == 'iptc/Headline'
            core_file.title = item.value
          elsif item.key == 'iptc/Category'
            if item.value == "ALU"
              k = "alumni"
            elsif item.value == "ATH"
              k = "athletics"
            elsif item.value == "CAM"
              k = "campus"
            elsif item.value == "CLA"
              k = "classroom"
            elsif item.value == "COM"
              k = "community outreach"
            elsif item.value == "EXPERIENTIAL LEARNING"
              k = item.value.downcase
            elsif item.value == "HEA"
              k = "headshots"
            elsif item.value == "POR"
              k = "portraits"
            elsif item.value == "PRE"
              k = "president"
            elsif item.value == "RES"
              k = "research"
            end
            classification = k
            core_file.mods.classification = classification
          elsif item.key == 'iptc/SuppCategory'
            s = ''
            if item.value.kind_of?(Array)
              item.value.each do |i|
                if i.kind_of?(String)
                  s = s + " -- " + i.downcase
                end
              end
              core_file.mods.classification = "#{classification}#{s}"
            else
              core_file.mods.classification = "#{classification}#{item.value}"
            end
          elsif item.key == "iptc/Byline"
            pers = item.value.split(",")
            # pers = {:first_names=>[pers[1].strip], :last_names=>[pers[0].strip]}
            # core_file.creators = pers
            core_file.mods.personal_name.name_part_given = pers[1].strip
            core_file.mods.personal_name.name_part_family = pers[0].strip
          elsif item.key == 'iptc/BylineTitle'
            core_file.mods.personal_name.role.role_term = item.value
            core_file.mods.personal_name.role.role_term.type = "text"
          elsif item.key == 'iptc/Caption'
            core_file.description = item.value
          elsif item.key == 'iptc/Source'
            core_file.mods.origin_info.publisher = item.value
          elsif item.key == "iptc/DateCreated"
            core_file.mods.origin_info.copyright = "#{item.value[0..3]}-#{item.value[4..5]}-#{item.value[6..7]}"
            core_file.date = "#{item.value[0..3]}-#{item.value[4..5]}-#{item.value[6..7]}"
          elsif item.key == 'iptc/Keywords'
            if item.value.kind_of?(Array)
              core_file.keywords = item.value
            else
              core_file.keywords = ["#{item.value}"]
            end
          elsif item.key == 'iptc/City'
            # core_file.mods.origin_info.place.term = item.value
            # core_file.mods.origin_info.place.term.type = "text"
          elsif item.key == 'iptc/ProvinceState'
            # if item.value == "MA"
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
        puts core_file.pid
        puts core_file.tmp_path
        puts core_file.original_filename

        # Process Thumbnail - this doens't actually seem to be working right now - I might not be passing the right params
        Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))
        core_file.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")

        if core_file.save!
          if core_file && !core_file.category.first.blank?
            UploadAlert.create_from_core_file(core_file, :create)
          end
        end
        #create success report

      end
    rescue Exception => error
      puts "There was an error"
      puts error
      pid = core_file.pid
      puts pid
      failed_pids_log.warn "#{Time.now} - Error processing PID: #{pid}"
      errors_for_pid = Logger.new("#{Rails.root}/log/#{job_id}/#{pid}.log")
      errors_for_pid.warn "#{Time.now} - #{$!.inspect}"
      errors_for_pid.warn "#{Time.now} - #{$!}"
      errors_for_pid.warn "#{Time.now} - #{$@}"
      core_file.destroy
    end
  end
end
