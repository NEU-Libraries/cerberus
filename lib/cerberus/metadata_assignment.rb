# Handles assignment of common metadata.
# Shouldn't explode due to lack of a datastream on hybrid assignments.
# Note that this enforces some naming conventions for datastreams.

module Cerberus
  module MetadataAssignment
    extend ActiveSupport::Concern

    included do

      def canonical_class=(string)
        if_properties_exists_strict { self.properties.canonical_class = string }
      end

      def canonical_class
        if_properties_exists_strict { self.properties.canonical_class.first }
      end

      def tmp_path=(string)
        if_properties_exists_strict { self.properties.tmp_path = string }
      end

      def tmp_path
        if_properties_exists_strict { self.properties.tmp_path.first }
      end

      def original_filename=(string)
        # Required because somehow Marcom was able to place invisible characters into filenames with Photo Mechanic
        # which caused "\xC2" from ASCII-8BIT to UTF-8 (Encoding::UndefinedConversionError)
        if_properties_exists_strict { self.properties.original_filename = Unidecoder.decode(string) }
      end

      def original_filename
        if_properties_exists_strict { self.properties.original_filename.first }
      end

      def thumbnail_list=(array_of_strings)
        if_properties_exists_strict { self.properties.thumbnail_list = array_of_strings }
      end

      def thumbnail_list
        if_properties_exists_strict { self.properties.thumbnail_list }
      end

      def title=(string)
        if_mods_exists { self.mods.title = string }
        if_DC_exists { self.DC.nu_title = string }
      end

      def title
        if_mods_exists { return self.mods.title.first }
        if_DC_exists { return self.DC.nu_title.first }
      end

      def non_sort=(string)
        if_mods_exists { self.mods.non_sort = string }
      end

      def non_sort
        if_mods_exists { return self.mods.title_info.non_sort.first }
      end

      def dc_type=(string)
        if_DC_exists { self.DC.nu_type = string }
      end

      def mods_type=(string)
        if_mods_exists { self.mods.type_of_resource = string }
      end

      def obj_type
        if_mods_exists { self.mods.type_of_resource.first }
      end

      def identifier=(string)
        if_mods_exists { self.mods.identifier = string }
        if_DC_exists { self.DC.nu_identifier = string }
      end

      def identifier
        if_mods_exists { return self.mods.identifier.first }
        if_DC_exists { return self.DC.nu_identifier.first }
      end

      def description=(string)
        if !string.blank?
          if_mods_exists { self.mods.description = string }
          if_DC_exists { self.DC.nu_description = string }
        end
      end

      def description
        if_mods_exists { return self.mods.abstract.first }
        if_DC_exists { return self.DC.nu_description.first }
      end

      def date=(string)
        if !string.blank?
          if_mods_exists { self.mods.date = string }
          if_DC_exists   { self.DC.date = string }
        end
      end

      def date
        if_mods_exists { return self.mods.date }
        if_DC_exists   { return self.DC.date.first }
      end

      def keywords=(array_of_strings)
        if_mods_exists { self.mods.topics = array_of_strings }
        if_DC_exists   { self.DC.subject = array_of_strings }
      end

      def keywords
        if_mods_exists { return self.mods.subject.topic }
        if_DC_exists   { return self.DC.subject }
      end

      def creators=(hash)
        fns = hash['first_names'] || []
        lns = hash['last_names'] || []
        cns = hash['corporate_names'] || []

        if_mods_exists do
          self.mods.assign_creator_personal_names(fns, lns)
          self.mods.assign_corporate_names(cns)
        end

        if_DC_exists { self.DC.assign_creators(fns, lns, cns) }
      end

      # Assumes you want a type agnostic dump of all creators and therefore uses the DC record
      def creators
        # if_DC_exists_strict { self.DC.creator }
        c = []
        c.concat personal_creators.map { |hsh| "#{hsh[:first]} #{hsh[:last]}" }
        c.concat corporate_creators
        c.reject { |c| c.empty? }
      end

      # Should return [{first: "Will", last: "Jackson"}, {first: "next_first", last: "etc"}]
      def personal_creators
        if_mods_exists_strict { self.mods.personal_creators }
      end

      # Should return just an array
      def corporate_creators
        if_mods_exists_strict { self.mods.corporate_creators }
      end

      def depositor=(string)
        # we need to remove the existing depositor permissions...
        if !self.depositor.blank?
          self.rightsMetadata.permissions({person: self.depositor}, 'none')
        end

        if_properties_exists_strict { self.properties.depositor = string }
        self.rightsMetadata.permissions({person: string}, 'edit')
      end

      def depositor
        if_properties_exists_strict { self.properties.depositor.first }
      end

      def proxy_uploader=(string)
        if_properties_exists_strict { self.properties.proxy_uploader = string }
        #self.rightsMetadata.permissions({person: string}, 'edit')
      end

      def proxy_uploader
        if_properties_exists_strict { self.properties.proxy_uploader.first }
      end

      # Use this when you need to get the person who should actually be
      # contacted about things w.r.t the file in question.
      def true_depositor
        proxy_uploader || depositor
      end

      def canonize
        if_properties_exists_strict { self.properties.canonize }
      end

      def uncanonize
        if_properties_exists_strict { self.properties.uncanonize }
      end

      def canonical?
        if_properties_exists_strict { self.properties.canonical? }
      end

      def smart_collection_type=(string)
        if_properties_exists_strict { self.properties.smart_collection_type = string }
      end

      def smart_collection_type
        if_properties_exists_strict { self.properties.get_smart_collection_type }
      end

      def is_smart_collection?
        if_properties_exists_strict do
          return !self.properties.smart_collection_type.empty?
        end
      end
    end

    private

      def if_mods_exists(&block)
        verify_datastream_carefree('mods', ModsDatastream, &block)
      end

      def if_mods_exists_strict(&block)
        verify_datastream_strict('mods', ModsDatastream, &block)
      end

      def if_DC_exists(&block)
        verify_datastream_carefree('DC', DublinCoreDatastream, &block)
      end

      def if_DC_exists_strict(&block)
        verify_datastream_strict('DC', DublinCoreDatastream, &block)
      end

      def if_properties_exists_strict(&block)
        verify_datastream_carefree('properties', PropertiesDatastream, &block)
      end

      def verify_datastream_carefree(ds_name, ds_class, &action)
        if datastream_exists?(ds_name, ds_class)
          action.call
        else
          return nil
        end
      end

      def verify_datastream_strict(ds_name, ds_class, &action)
        if datastream_exists?(ds_name, ds_class)
          action.call
        else
          raise Exceptions::DatastreamNotFoundError.new(ds_name, ds_class, self)
        end
      end

      def datastream_exists?(ds_name, ds_class)
        return self.datastreams.keys.include?(ds_name) && self.datastreams[ds_name].instance_of?(ds_class)
      end

  end
end
