module Modsable
  extend ActiveSupport::Concern
  extend Forwardable

  def_delegators :descMetadata, *ModsMetadata.terminology.terms.keys.concat(ModsMetadata.terminology.terms.keys.map{|x| (x.to_s + "=").to_sym})

  included do
    has_subresource 'descMetadata', class_name: 'ModsMetadata'
  end

  def prefix(name)
    "#{name.underscore}__"
  end

  # Inserts a new contributor (mods:name) into the mods document
  # creates contributors of type :person, :organization, or :conference
  def insert_contributor(type, _opts = {})
    case type.to_sym
    when :person
      node = Hydra::ModsArticleDatastream.person_template
      nodeset = find_by_terms(:person)
    when :organization
      node = Hydra::ModsArticleDatastream.organization_template
      nodeset = find_by_terms(:organization)
    when :conference
      node = Hydra::ModsArticleDatastream.conference_template
      nodeset = find_by_terms(:conference)
    else
      ActiveFedora.logger.warn("#{type} is not a valid argument for Hydra::ModsArticleDatastream.insert_contributor")
      node = nil
      index = nil
    end

    unless nodeset.nil?
      if nodeset.empty?
        ng_xml.root.add_child(node)
        index = 0
      else
        nodeset.after(node)
        index = nodeset.length
      end
      self.dirty = true
    end

    [node, index]
  end

  # Remove the contributor entry identified by @contributor_type and @index
  def remove_contributor(contributor_type, index)
    find_by_terms(contributor_type.to_sym => index.to_i).first.remove
    self.dirty = true
  end

end
