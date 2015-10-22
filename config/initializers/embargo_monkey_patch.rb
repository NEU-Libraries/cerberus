module Hydra
  module Datastream
    class RightsMetadata < ActiveFedora::OmDatastream
      def under_embargo?
        if !embargo_release_date.blank?
          (embargo_release_date && Time.zone.today < embargo_release_date.to_date) ? true : false
        else
          false
        end
      end
    end
  end
end
