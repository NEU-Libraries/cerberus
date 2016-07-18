# This module provides convenience methods that insert/remove nodes in the expected location
# within a defined terminology.
module NodeHelper

  # Inserts a new node that is a direct child of root into the document underneath an identical sibling if one exists.
  # Assumes that the datastream calling this method will implement a method of the form #{terminology_element_name}_template.
  # e.g. insert_new_node(:mods_personal_name) called on the ModsDatastream inserts a new node corresponding to t.mods_personal_name
  # given that the method mods_personal_name_template exists and returns a Nokogiri Document.
  def insert_new_node(term)
    node = self.class.send("#{term.to_s}_template")
    nodeset = self.find_by_terms(term)

    unless nodeset.nil?
      if nodeset.empty?
        self.ng_xml.root.add_child(node)
        index = 0
      else
        nodeset.after(node)
        index = nodeset.length
      end
    end
    return node, index
  end

  # Removes the specified root node at the specified index.
  def remove_node(term, index)
    node = self.find_by_terms(term.to_sym => index.to_i).first
    unless node.nil?
      node.remove
    end
  end

  # Removes trim_count's worth of term matching root nodes from the document.
  # Won't remove the first instance of the searched for element to preserve formatting.
  def trim_nodes_from_zero(term, trim_count)
    i = 0

    while i < trim_count
      if self.find_by_terms(term).length == 1
        node = self.find_by_terms(term)
        node.children.remove
        break
      end

      remove_node(term, i)
      i = i + 1
    end
  end

  # Removes subject nodes based on what type of node is within the subject
  def remove_subject_nodes(name)
    self.find_by_terms(:subject, name).each do |node|
      node.parent.remove
    end
  end
end
