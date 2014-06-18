require 'date_time_precision'
require 'date_time_precision/format/string'

module Drs
  module SolrDocumentBehavior
    include Drs::SolrQueries

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

    def creators
      Array(self[Solrizer.solr_name("creator", :facetable)])
    end

    def type_label
      if self.klass == "NuCoreFile" && !self.canonical_object.nil?
        return I18n.t("drs.display_labels.#{self.canonical_object.klass}.name")
      end
      I18n.t("drs.display_labels.#{self.klass}.name")
    end

    def thumbnail_list
      Array(self[Solrizer.solr_name("thumbnail_list", :stored_searchable)])
    end

    def klass
      Array(self[Solrizer.solr_name("active_fedora_model", :stored_sortable)]).first
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

    def noid
      self[Solrizer.solr_name('noid', Sufia::GenericFile.noid_indexer)]
    end

    def depositor(default = '')
      val = Array(self[Solrizer.solr_name("depositor")]).first
      val.present? ? val : default
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
  end
end
