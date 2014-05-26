# Handles assignment of common metadata.
# Shouldn't explode due to lack of a datastream on hybrid assignments.
# Note that this enforces some naming conventions for datastreams.

module Drs
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
        if_properties_exists_strict { self.properties.original_filename = string }
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
        if_descMetadata_exists { self.descMetadata.title = string }
      end

      def title
        if_mods_exists { return self.mods.title.first }
        self.DC.nu_title.first
      end

      def non_sort=(string)
        if_mods_exists { self.mods.title_info.non_sort = string }
      end

      def non_sort
        if_mods_exists { return self.mods.title_info.non_sort.first }
      end

      def dcmi_type=(string)
        if_mods_exists { self.mods.type_of_resource = string }
        if_DC_exists { self.DC.nu_type = string }
      end

      def dcmi_type
        if_mods_exists { return self.mods.type_of_resource.first }
        return self.DC.nu_type.first
      end

      def identifier=(string)
        if_mods_exists { self.mods.identifier = string }
        if_DC_exists { self.DC.nu_identifier = string }
        if_descMetadata_exists { self.descMetadata.identifier = string }
      end

      def identifier
        if_mods_exists { self.mods.identifier.first }
        self.DC.nu_identifier.first
      end

      def description=(string)
        if_mods_exists { self.mods.abstract = string }
        if_DC_exists { self.DC.nu_description = string }
        if_descMetadata_exists { self.descMetadata.description = string }
      end

      def description
        if_mods_exists { return self.mods.abstract.first }
        self.DC.nu_description.first
      end

      def date_of_issue=(string)
        if_mods_exists { self.mods.date_issued = string }
        if_DC_exists   { self.DC.date = string }
        if_descMetadata_exists { self.descMetadata.date_created = string }
      end

      def date_of_issue
        if_mods_exists { self.mods.date_issued.first }
        self.DC.date.first
      end

      def keywords=(array_of_strings)
        if_mods_exists { self.mods.topics = array_of_strings }
        if_DC_exists   { self.DC.subject = array_of_strings }
        if_descMetadata_exists { self.descMetadata.tag = array_of_strings }
      end

      def keywords
        self.DC.subject
      end

      def creators=(hash)
        fns = hash['first_names'] || []
        lns = hash['last_names'] || []
        cns = hash['corporate_names'] || []

        if_mods_exists do
          self.mods.assign_creator_personal_names(fns, lns)
          self.mods.assign_corporate_names(cns)
        end

        if_descMetadata_exists { assign_creator_array(fns, lns, cns) }

        if_DC_exists { self.DC.assign_creators(fns, lns, cns) }
      end

      # Assumes you want a type agnostic dump of all creators and therefore uses the DC record
      def creators
        if_DC_exists_strict { self.DC.creator }
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
        if_properties_exists_strict { self.properties.depositor = string }
        self.rightsMetadata.permissions({person: string}, 'edit')
      end

      def depositor
        if_properties_exists_strict { self.properties.depositor.first }
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

      def type=(array)
        if_descMetadata_exists_strict { self.descMetadata.resource_type = array }
      end

      def type
        if_descMetadata_exists_strict { self.descMetadata.resource_type }
      end

      def date_uploaded
        if_descMetadata_exists_strict { self.descMetadata.date_uploaded.first }
      end

      def date_updated
        if_descMetadata_exists_strict { self.descMetadata.date_modified.first }
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

      # Rather than pull in descMetadata for the moment,
      # we define this helper method that turns the first/last/corporate name arrays
      # into a single array of ready to assign creators
      def assign_creator_array(fns, lns, cns)
        if fns.length != lns.length
          raise "passed #{fns.length} first names and #{lns.length} last names."
        end

        full_names = []
        fns.each_with_index do |fn, i|
          full_names << "#{fn} #{lns[i]}"
        end

        self.descMetadata.creator = full_names + cns
      end


      def if_descMetadata_exists(&block)
        verify_datastream_carefree('descMetadata', GenericFileRdfDatastream, &block)
      end

      def if_descMetadata_exists_strict(&block)
        verify_datastream_strict('descMetadata', GenericFileRdfDatastream, &block)
      end

      def if_mods_exists(&block)
        verify_datastream_carefree('mods', NuModsDatastream, &block)
      end

      def if_mods_exists_strict(&block)
        verify_datastream_strict('mods', NuModsDatastream, &block)
      end

      def if_DC_exists(&block)
        verify_datastream_carefree('DC', NortheasternDublinCoreDatastream, &block)
      end

      def if_DC_exists_strict(&block)
        verify_datastream_strict('DC', NortheasternDublinCoreDatastream, &block)
      end

      def if_properties_exists_strict(&block)
        verify_datastream_carefree('properties', DrsPropertiesDatastream, &block)
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
