class StatisticsController < ApplicationController
  def get_views
    @count = total_count
    respond_to do |format|
      format.js { render "count", locals:{count:@count}}
    end
  end
  def get_downloads
    @count = total_count
    respond_to do |format|
      format.js { render "count", locals:{count:@count}}
    end
  end
  def get_streams
    @count = total_count
    respond_to do |format|
      format.js { render "count", locals:{count:@count}}
    end
  end
end
