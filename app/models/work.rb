# frozen_string_literal: true

class Work < Resource
  attribute :a_member_of, Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true)

  def mods_xml_path
    # TODO: Fix fragility (first etc.)
    children.find do |c|
      c.instance_of?(FileSet) && c.type == 'Metadata'
    end.files.first.file_path
  end
end
