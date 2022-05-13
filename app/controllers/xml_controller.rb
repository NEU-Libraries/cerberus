# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    @work = Work.find(params[:id])
    @raw_xml = @work.mods_xml
  end

  def validate
    puts "DGC DEBUG VALIDATE"
    # $("#mods").html("<%= escape_javascript(render partial: "users/user", locals: {user: @user}) %>");
    respond_to do |format|
      format.turbo_stream
   end
  end

  def update
  end
end
