module Api
  module V1
    class IngestController < ApplicationController

      include Cerberus::TempFileStorage
      include Cerberus::ThumbnailCreation
      include HandleHelper
      include MimeHelper

      def ingest
        # Take an external form, and based on whitelisted IP deposit submission
        ip = request.remote_ip

        begin
          collections = I18n.t "ingest.#{Rails.env}.#{ip.gsub(".", "-")}", raise: true # We replace periods for YML, and raise error if IP not on whitelist
        rescue I18n::MissingTranslationData
          email_handled_exception(Exceptions::SecurityEscalationError.new())
          respond_to do |format|
            format.json { render :json => { :error => "IP address not on whitelist. DRS administrators have been notified of this attempt.", status: :forbidden } }
          end and return
        end

        if params.blank? || params[:core_file].blank? || params[:file].blank?
          # raise submission empty error
          respond_to do |format|
            format.json { render :json => { :error => "Incomplete form submission. File and/or metadata are not available.", status: :bad_request }  }
          end and return
        elsif params[:core_file][:title].blank?
          # raise title required error
          respond_to do |format|
            format.json { render :json => { :error => "Incomplete form submission. Title missing.", status: :bad_request }  }
          end and return
        elsif params[:core_file][:keywords].blank?
          # raises keywords required error
          respond_to do |format|
            format.json { render :json => { :error => "Incomplete form submission. Keyword(s) missing.", status: :bad_request } }
          end and return
        end

        user_submittied_col_pid = params[:collection]

        if !user_submittied_col_pid.blank? && (!collections.contain? user_submittied_col_pid)
          # raises invalid data error
          respond_to do |format|
            format.json { render :json => { :error => "Invalid collection pid.", status: :bad_request } }
          end and return
        end

        if user_submittied_col_pid.blank?
          # Use default yml first value
          user_submittied_col_pid = collections.first
        end

        user_submittied_collection = Collection.find(user_submittied_col_pid)

        core_file = CoreFile.new
        core_file.tag_as_in_progress
        core_file.parent = user_submittied_collection
        core_file.properties.parent_id = user_submittied_collection.pid
        core_file.depositor = "000000000"
        core_file.properties.api_ingested = 'true'

        sentinel = core_file.parent.sentinel

        if sentinel && !sentinel.core_file.blank?
          core_file.permissions = sentinel.core_file["permissions"]
          core_file.mass_permissions = sentinel.core_file["mass_permissions"]
        end

        core_file.rightsMetadata.permissions({person: "000000000"}, 'edit')
        core_file.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit")
        core_file.save!

        # rescue block - JSON dump error and email dev
        begin
          # Required items;
          # Binary file
          file = params[:file]
          # Title
          core_file.title = params[:core_file][:title]
          # Keyword(s)
          core_file.keywords = params[:core_file][:keywords].reject { |x| x.empty? }

          # Optional items;
          # Subtitle
          core_file.mods.title_info.sub_title = params.fetch(:core_file, {}).fetch(:subtitle, {})
          # Date created
          core_file.date = params.fetch(:core_file, {}).fetch(:date_created, {})
          # Copyright date
          core_file.mods.origin_info.copyright = params.fetch(:core_file, {}).fetch(:copyright_date, {})
          # Date published - dateIssued
          core_file.mods.origin_info.date_issued = params.fetch(:core_file, {}).fetch(:date_published, {})
          # Publisher name
          core_file.mods.origin_info.publisher = params.fetch(:core_file, {}).fetch(:publisher, {})
          # Place of publication
          core_file.mods.origin_info.place.place_term = params.fetch(:core_file, {}).fetch(:place_of_publication, {})
          # Creator name(s) - first, last
          first_names = params.fetch(:core_file, {}).fetch(:creators, {}).fetch(:first_names, {}).reject { |x| x.empty? }
          last_names = params.fetch(:core_file, {}).fetch(:creators, {}).fetch(:last_names, {}).reject { |x| x.empty? }
          core_file.creators = {'first_names' => first_names, 'last_names'  => last_names}
          # Language(s)
          core_file.mods.languages = params.fetch(:core_file, {}).fetch(:languages, {}).reject { |x| x.empty? }
          # Description(s)
          core_file.mods.abstracts = params.fetch(:core_file, {}).fetch(:descriptions, {}).reject { |x| x.empty? }

          # Note(s) - array_of_hashes
          # hash[:note] = note
          # hash[:type] = row_results["notes_#{i}_type"]
          raw_notes = params.fetch(:core_file, {}).fetch(:notes, {}).reject { |x| x.empty? }
          composed_notes = Array.new
          raw_notes.each do |n|
            notes_hash = Hash.new
            notes_hash[:note] = n
            notes_hash[:type] = ""
            composed_notes << notes_hash
          end
          core_file.mods.notes = composed_notes

          # Use and reproduction - dropdown
          core_file.mods.access_condition = params.fetch(:core_file, {}).fetch(:use_and_reproduction, {})
          core_file.mods.access_condition.type = "use and reproduction"
        rescue Exception => error
          email_handled_exception(error)
          respond_to do |format|
            format.json { render :json => { :error => error.to_s, status: :bad_request }  }
          end and return
        end

        core_file.tag_as_completed
        core_file.save!

        new_path = move_file_to_tmp(file)
        core_file.tmp_path = new_path
        core_file.original_filename = file.original_filename
        core_file.instantiate_appropriate_content_object(new_path, core_file.original_filename)

        core_file.identifier = make_handle(core_file.persistent_url)

        core_file.save!

        Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))

        respond_to do |format|
          format.json { render :json => { :response=>"File uploaded", :pid => core_file.pid, :url => core_file.persistent_url }, status: :ok }
        end and return
      end

    end
  end
end
