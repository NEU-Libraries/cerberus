class StatisticsController < ApplicationController
  def all_counts
    doc = SolrDocument.new(ActiveFedora::Base.find(params[:id], cast: true).to_solr)

    view_count = doc.impression_views
    download_count = doc.impression_downloads
    stream_count = doc.impression_streams

    respond_to do |format|
      format.js { render "shared/statistics/count", locals:{view_count: view_count, download_count: download_count, stream_count: stream_count}}
    end
  end
end
