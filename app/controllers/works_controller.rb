# frozen_string_literal: true

class WorksController < ApplicationController
  include ValkyrieHelper

  def show
    @work = Work.find(params[:id])
  end

  def new
    @work = Work.new
  end

  def create
    w = Valkyrie.config.metadata_adapter.persister.save(resource: Work.new)

    tmp = params[:binary].tempfile
    file_path = File.join('/home/cerberus/storage', params[:binary].original_filename)
    FileUtils.cp tmp.path, file_path
    # create file set
    fs = Valkyrie.config.metadata_adapter.persister.save(resource: FileSet.new(type: Classification.descriptive_metadata.name))
    fs.member_ids += [
      create_blob(create_file(file_path, fs).id, file_path.split('/').last, Cerberus::Vocab::PCDMUse.MetadataFile,
                  w.id).id
    ]
    fs.a_member_of = w.id
    Valkyrie.config.metadata_adapter.persister.save(resource: fs)
    flash[:notice] = fs.noid
    redirect_to w
  end
end
