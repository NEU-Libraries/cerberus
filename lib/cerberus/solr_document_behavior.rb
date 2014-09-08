require 'date_time_precision'
require 'date_time_precision/format/string'
include Rails.application.routes.url_helpers

module Cerberus
  module SolrDocumentBehavior
    include Cerberus::SolrQueries

    def process_date(date_string)
      begin
        if !date_string.nil? && (date_string != "")
          if(date_string.split("-")).length > 2
            return date_string.to_date.to_formatted_s(:long)
          else
            date_array = date_string.split("-") - ["null"]

            if date_array.length == 2
              date = Date.new(date_array.first.to_i, date_array.second.to_i).to_s(:long)
            else
              date = Date.new(date_array.first.to_i).to_s(:long)
            end

            return date
          end
        else
          return nil
        end
      rescue => error
        Rails.logger.warn error.backtrace
        Rails.logger.warn "Invalid date - #{self.pid} Error #{$!}"
      end

      return nil
    end

    def nuid
      Array(self[Solrizer.solr_name("nuid", :stored_searchable)]).first
    end

    def updated_at
      Array(self["system_modified_dtsi"]).first
    end

    def non_sort
      Array(self[Solrizer.solr_name("title_info_non_sort", :stored_searchable)]).first
    end

    def title_or_label
      title || label
    end

    def pid
      Array(self[:id]).first
    end

    def smart_collection_type
      Array(self[Solrizer.solr_name("smart_collection_type", :stored_searchable)]).first
    end

    def is_member_of
      Array(self[Solrizer.solr_name("is_member_of", :symbol)]).first
    end

    def has_affiliation
      Array(self[Solrizer.solr_name("has_affiliation", :symbol)]).first
    end

    def date_of_issue
      process_date(Array(self[Solrizer.solr_name("date_issued", :symbol)]).first)
    end

    def create_date
      process_date(Array(self[Solrizer.solr_name("system_create_dtsi")]).first)
    end

    def create_date_time
      x = Array(self["system_create_dtsi"]).first
      DateTime.parse x
    end

    def creators
      Array(self[Solrizer.solr_name("creator", :facetable)])
    end

    def type_label
      if self.klass == "CoreFile" && !self.canonical_class.nil?
        return I18n.t("drs.display_labels.#{self.canonical_class}.short")
      end
      I18n.t("drs.display_labels.#{self.klass}.short")
    end

    def derivative_label
      I18n.t("drs.display_labels.#{self.klass}.name")
    end

    def thumbnail_list
      thumbs = Array(self[Solrizer.solr_name("thumbnail_list", :stored_searchable)])

      # check pid to see if it has been indexed in solr yet, if not, return []
      if thumbs.length > 0
        thumb_url = thumbs.first
        pid = /neu\:[a-zA-Z0-9]*/.match(thumb_url).to_s
        thumb = ActiveFedora::SolrService.query("id:\"#{pid}\"").first
        if thumb.nil?
          return []
        else
          return thumbs
        end
      end

      # Safety return
      return []
    end

    def klass
      Array(self[Solrizer.solr_name("active_fedora_model", :stored_sortable)]).first
    end

    def canonical_class
      Array(self[Solrizer.solr_name("canonical_class", :stored_searchable)]).first
    end

    def parent
      Array(self[Solrizer.solr_name("parent_id", :stored_searchable)]).first
    end

    def employee_name
      Array(self[Solrizer.solr_name("employee_name", :stored_searchable)]).first
    end

    ##
    # Give our SolrDocument an ActiveModel::Naming appropriate route_key
    def route_key
      get(Solrizer.solr_name('has_model', :symbol)).split(':').last.downcase
    end

    ##
    # Offer the source (ActiveFedora-based) model to Rails for some of the
    # Rails methods (e.g. link_to).
    # @example
    #   link_to '...', SolrDocument(:id => 'bXXXXXX5').new => <a href="/dams_object/bXXXXXX5">...</a>
    def to_model
      m = ActiveFedora::Base.load_instance_from_solr(id, self)
      return self if m.class == ActiveFedora::Base
      m
    end

    def path
      polymorphic_path(self.to_model)
    end

    def noid
      self[Solrizer.solr_name('noid', Sufia::GenericFile.noid_indexer)]
    end

    def depositor(default = '')
      val = Array(self[Solrizer.solr_name("depositor")]).first
      val.present? ? val : default
    end

    def proxy_uploader(default = '')
      val = Array(self["proxy_uploader_tesim"]).first
      val.present? ? val : default
    end

    def true_depositor
      return proxy_uploader if ( !proxy_uploader.blank? )
      return depositor
    end

    def title
      title_str = ""
      if self.klass == "Employee"
        title_str = Array(self[Solrizer.solr_name("employee_name", :stored_searchable, type: :text)]).first
      else
        title_str = Array(self[Solrizer.solr_name("title", :stored_sortable)]).first
      end
    end

    def description
      Array(self[Solrizer.solr_name("abstract", :stored_searchable)]).first
    end

    def label
      Array(self[Solrizer.solr_name('label')]).first
    end

    def file_format
       Array(self[Solrizer.solr_name('file_format')]).first
    end

    def mime_type
      Array(self[Solrizer.solr_name("mime_type")]).first
    end

    def read_groups
      Array(self[Ability.read_group_field])
    end

    def edit_groups
      Array(self[Ability.edit_group_field])
    end

    def edit_people
      Array(self[Ability.edit_person_field])
    end

    def public?
      read_groups.include?('public')
    end

    def registered?
      read_groups.include?('registered')
    end


    def pdf?
      ['application/pdf'].include? self.mime_type
    end

    def image?
      ['image/png','image/jpeg', 'image/jpg', 'image/jp2', 'image/bmp', 'image/gif'].include? self.mime_type
    end

    def video?
      ['video/mpeg', 'video/mp4', 'video/webm', 'video/x-msvideo', 'video/avi', 'video/quicktime', 'application/mxf'].include? self.mime_type
    end

    def audio?
      # audio/x-wave is the mime type that fits 0.6.0 returns for a wav file.
      # audio/mpeg is the mime type that fits 0.6.0 returns for an mp3 file.
      ['audio/mp3', 'audio/mpeg', 'audio/x-wave', 'audio/x-wav', 'audio/ogg'].include? self.mime_type
    end

    # Content objects store file data in a datastream called 'content'
    # This method encapsulates reaching into the SolrDocument created from a
    # content object and fetching its filename.  Which is a surprisingly
    # involved process
    def get_content_label
      hsh = JSON.parse(get "object_profile_ssm")
      return hsh["datastreams"]["content"]["dsLabel"]
    end

    def is_empty_collection?
      return false if self.klass != "Collection"

      ActiveFedora::SolrService.query("parent_id_tesim:\"#{self.pid}\"").empty?
    end

    def codebook_for
      is_material_for_helper("is_codebook_for_ssim")
    end

    def dataset_for
      is_material_for_helper("is_dataset_for_ssim")
    end

    def figure_for
      is_material_for_helper("is_figure_for_ssim")
    end

    def instructional_material_for
      is_material_for_helper("is_instructional_material_for_ssim")
    end

    def supplemental_material_for
      is_material_for_helper("is_supplemental_material_for_ssim")
    end

    def transcription_of
      is_material_for_helper("is_transcription_of_ssim")
    end

    def is_material_for_helper(relation)
      all = self[relation] || []
      all.map { |x| SolrDocument.new x }
    end

    # Fetch the current item's embargo release date
    def embargo_release_date(opts = {})
      opts = opts.with_indifferent_access

      result = Array(self["embargo_release_date_dtsi"]).first

      if opts[:formatted] && result
        return DateTime.parse(result).strftime("%B %-d, %Y")
      else
        return result
      end
    end

    # Check if the current object is under embargo
    # disregarding the status of the current user
    def embargo_date_in_effect?
      e = embargo_release_date
      return false if e.blank?

      now = DateTime.now
      e = DateTime.parse e

      return now < e
    end

    # Check if the current object is under embargo
    def under_embargo?(user)
      e = embargo_release_date
      return false if e.blank?

      now = DateTime.now
      e = DateTime.parse e

      if !user
        return now < e
      else
        is_not_depositor = !(user.nuid == self.depositor)
        is_not_staff     = !(user.repo_staff?)
        return (now < e) && is_not_depositor && is_not_staff
      end
    end

    def is_content_object?
      return Array(self["is_part_of_ssim"]).any?
    end

    def get_core_record
      id = Array(self["is_part_of_ssim"]).first.split("/").last
      return SolrDocument.new ActiveFedora::SolrService.query("id:\"#{id}\"").first
    end

    # Check if the current file is in progress
    def in_progress?
      return Array(self["in_progress_tesim"]).first == "true"
    end
  end
end
