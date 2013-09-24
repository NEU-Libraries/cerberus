# Handles assignment of common metadata. 
# Shouldn't explode due to lack of a datastream on hybrid assignments.  
# Note that this enforces some naming conventions for datastreams. 

module Drs
  module MetadataAssignment
    extend ActiveSupport::Concern

    included do 
      def title=(string) 
        if_DC_exists { self.DC.nu_title = string } 
        if_mods_exists { self.mods.mods_title = string }
        if_descMetadata_exists { self.descMetadata.title = string }  
      end

      def title
        self.DC.nu_title.first 
      end

      def identifier=(string) 
        if_DC_exists { self.DC.nu_identifier = string } 
        if_mods_exists { self.mods.mods_identifier = string }
        if_descMetadata_exists { self.descMetadata.identifier = string }  
      end

      def identifier
        self.DC.nu_identifier.first 
      end

      def description=(string) 
        if_DC_exists { self.DC.nu_description = string } 
        if_mods_exists { self.mods.mods_abstract = string }
        if_descMetadata_exists { self.descMetadata.description = string } 
      end

      def description 
        self.DC.nu_description.first 
      end

      def date_of_issue=(string) 
        if_mods_exists { self.mods.mods_date_issued = string }
        if_DC_exists   { self.DC.date = string }  
      end

      def date_of_issue
        self.DC.date.first  
      end

      def keywords=(array_of_strings) 
        if_mods_exists { self.mods.keywords = array_of_strings }
        if_DC_exists   { self.DC.subject = array_of_strings }
      end

      def keywords
        self.DC.subject 
      end

      def assign_DC_creators(firsts, lasts, corporate) 
        if_DC_exists_strict do 
          self.DC.assign_creators(firsts, lasts, corporate) 
        end
      end

      def DC_creators 
        if_DC_exists_strict { self.DC.creator } 
      end

      def corporate_creators=(array_of_strings) 
        if_mods_exists_strict { self.mods.assign_corporate_names(array_of_strings) } 
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
        if_DC_exists_strict { self.DC.creator } 
      end

      # Should return [{first: "Will", last: "Jackson"}, {first: "next_first", last: "etc"}]
      def personal_creators 
        if_mods_exists_strict { self.mods.personal_creators } 
      end

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

      def personal_folder_type=(string) 
        if_properties_exists_strict { self.properties.personal_folder_type = string } 
      end

      def personal_folder_type
        if_properties_exists_strict { self.properties.get_personal_folder_type } 
      end

      def is_personal_folder? 
        if_properties_exists_strict do 
          return !self.properties.personal_folder_type.empty? 
        end
      end
    end

    private

      def if_descMetadata_exists(&block) 
        verify_datastream_carefree('descMetadata', GenericFileRdfDatastream, &block) 
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
          raise DatastreamNotFoundError.new(ds_name, ds_class, self) 
        end
      end

      def datastream_exists?(ds_name, ds_class) 
        return self.datastreams.keys.include?(ds_name) && self.datastreams[ds_name].instance_of?(ds_class)
      end

      class DatastreamNotFoundError < StandardError
        attr_accessor :ds_name, :ds_classname, :object_classname 

        def initialize(ds_name, ds_class, calling_object)
          self.ds_name = ds_name 
          self.ds_classname = ds_class.to_s 
          self.object_classname = calling_object.class.to_s

          super("Datastream with name #{ds_name} of class #{ds_classname} not defined for objects of type #{object_classname}.")  
        end
      end
  end
end