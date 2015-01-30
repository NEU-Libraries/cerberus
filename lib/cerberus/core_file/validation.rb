module Cerberus::CoreFile::Validation
  include XmlValidator

  def healthy?
    results = Hash.new

    # valid mods xml?
    xml_results = xml_valid?(self.mods.content)
    results[:errors] = xml_results[:errors]

    # has parent?
    if self.parent.nil? || !self.parent.is_a?(Collection)
      results[:errors] << Exceptions::NoParentFoundError
    end

    # depositor with edit permissions?
    if self.depositor.blank?
      results[:errors] << Exceptions::NoDepositorFoundError
    else
      u = User.find_by_nuid(self.depositor)
      if u.nil?
        results[:errors] << Exceptions::NoDepositorFoundError
      else
        if !u.can?(:read, self)
          results[:errors] << Exceptions::InvalidDepositorPermissionsError
        end
      end
    end

    # canonical content object?
    if self.canonical_object.nil?
      results[:errors] << Exceptions::NoCanonicalObjectFoundError
    end

    # canonical class?
    if self.canonical_class.blank?
      results[:errors] << Exceptions::NoCanonicalClassFoundError
    end

    # valid mass permissions?
    if !(self.mass_permissions == "public" || self.mass_permissions == "private")
      # no mass permissions!
      results[:errors] << Exceptions::NoMassPermissionsError
    else
      # is the parent private? if it is, is this core file?
      if parent.mass_permissions == "private"
        if self.mass_permissions == "public"
          # invalid permissions!
          results[:errors] << Exceptions::InvalidMassPermissionsError
        end
      end
    end

    # can be solrized?
    begin
      if self.to_solr.blank?
        results[:errors] << Exceptions::SolrizationError
      end
    rescue Exception => error
      results[:errors] << error
    end

    if results[:errors] == []
      return true
    end

    return results
  end
end
