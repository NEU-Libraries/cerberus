# Handles assignment of common metadata. 
# Shouldn't explode due to lack of a datastream on hybrid assignments.  
# Note that this enforces some naming conventions for datastreams. 

module Drs
  module MetadataAssignment

    def title=(string) 
      if_DC_exists { self.DC.nu_title = string } 
      if_mods_exists { self.mods.mods_title = string } 
    end

    def title
      self.DC.nu_title.first 
    end

    def identifier=(string) 
      if_DC_exists { self.DC.nu_identifier = string } 
      if_mods_exists { self.mods.mods_identifier = string } 
    end

    def identifier
      self.DC.nu_identifier.first 
    end

    def description=(string) 
      if_DC_exists { self.DC.nu_description = string } 
      if_mods_exists { self.mods.mods_abstract = string } 
    end

    def description 
      self.DC.nu_description.first 
    end

    def date_of_issue=(string) 
      if_mods_exists_strict { self.mods.mods_date_issued = string } 
    end

    def date_of_issue
      if_mods_exists_strict { self.mods.mods_date_issued.first } 
    end

    def keywords=(array_of_strings) 
      if_mods_exists_strict { self.mods.keywords = array_of_strings } 
    end

    def keywords
      if_mods_exists_strict { self.mods.mods_subject(0).mods_keyword } 
    end

    def corporate_creators=(array_of_strings) 
      if_mods_exists_strict { self.mods.assign_corporate_names(array_of_strings) } 
    end

    def corporate_creators
      # Eliminates some whitespace that seems to get shoved into these entries.  
      if_mods_exists_strict { self.mods.corporate_creators } 
    end

    def personal_creators=(hash) 
      first_names = hash['creator_first_names'] 
      last_names = hash['creator_last_names'] 

      if_mods_exists_strict { self.mods.assign_creator_personal_names(first_names, last_names)  } 
    end

    # Should return [{first: "Will", last: "Jackson"}, {first: "next_first", last: "etc"}]
    def personal_creators 
      if_mods_exists_strict { self.mods.personal_creators } 
    end

    def depositor=(string) 
      if_properties_exists_strict { self.properties.depositor = string } 
      self.rightsMetadata.permissions({person: string}, 'edit') 
    end

    def depositor
      if_properties_exists_strict { self.properties.depositor.first } 
    end

    private 

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