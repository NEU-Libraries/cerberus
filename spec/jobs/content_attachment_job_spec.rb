require 'spec_helper'

describe ContentAttachmentJob do
  before(:each) do

  end

  after(:each) do
    ActiveFedora::Base.destroy_all
  end

  # ContentAttachmentJob.new(@core_file.pid, @content_object.tmp_path, @content_object.pid, @content_object.original_filename, true, params[:permissions])
  # core_file, file_path, content_object, file_name, delete_file=true, permissions=nil
  # it "gets core_file"
  # it "gets content_object"
  # it "adds the file the content_object"
  # it "sets the core_record for the content_object"
  # it "sets the title to the filename"
  # it "sets the identifier to the pid"
  # it "sets the depositor to core_record depositor"
  # it "sets the proxy uploader"
  # it "sets nil permissions to the core_record permissions"
  # it "sets no nil permissions"
  # it "sets original_filename"
  # it "sets md5"
  # it "sets mime_type"
  # it "deletes cached content objects"
  # it "deletes tmp file"

end
