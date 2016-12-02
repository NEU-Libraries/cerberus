# properties datastream: catch-all for info that didn't have another home.  Particularly depositor.
class PropertiesDatastream < ActiveFedora::OmDatastream
  set_terminology do |t|
    t.root(:path=>"fields" )
    # This is where we put the user id of the object depositor -- impacts permissions/access controls
    t.parent_id :index_as=>[:stored_searchable]
    t.depositor :index_as=>[:stored_searchable]
    t.proxy_uploader :index_as=>[:stored_searchable]
    t.thumbnail_list :index_as=>[:stored_searchable]
    t.canonical  :index_as=>[:stored_searchable]
    t.incomplete :index_as=>[:stored_searchable]
    t.in_progress path: 'inProgress', :index_as=>[:stored_searchable]
    # This is where we put the relative path of the file if submitted as a folder
    t.relative_path
    t.smart_collection_type :index_as=>[:stored_searchable]
    t.import_url path: 'importUrl', :index_as=>:symbol
    # Moving ContentCreationJob later, need to store these for that to work
    t.tmp_path
    t.original_filename
    t.canonical_class :index_as=>[:stored_searchable]
    t.tombstoned
    t.md5_checksum :index_as=>[:stored_searchable]
    t.mime_type :index_as=>[:stored_searchable]
    t.ordinal_value :index_as=>[:stored_searchable, :stored_sortable], type: :integer
    t.ordinal_last :index_as=>[:stored_searchable]
    t.file_size :index_as=>[:stored_searchable]
    t.stream_only :index_as=>[:stored_searchable]
    t.published_set :index_as=>[:stored_searchable]
    t.iiif :index_as=>[:stored_searchable] #indexing this in case we ever need to retrieve them
  end

  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.fields
    end
    builder.doc
  end

  def get_smart_collection_type
    return self.smart_collection_type.first unless self.smart_collection_type.empty?
  end

  def in_progress?
    return ! self.in_progress.empty?
  end

  def incomplete?
    return ! self.incomplete.empty?
  end

  def tag_as_in_progress
    self.incomplete = []
    self.in_progress = 'true'
  end

  def tag_as_completed
    self.incomplete = []
    self.in_progress = []
  end

  def tag_as_incomplete
    self.incomplete = 'true'
    self.in_progress = []
  end

  def canonize
    self.canonical = 'yes'
  end

  def uncanonize
    self.canonical = ''
  end

  def canonical?
    return self.canonical.first == 'yes'
  end

  def tag_as_stream_only
    self.stream_only = 'true'
  end

  def stream_only?
    return ! self.stream_only.empty?
  end

end
