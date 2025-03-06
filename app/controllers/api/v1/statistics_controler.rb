module Api
  module V1
    class StatisticsController < ApplicationController

      def views
        expires_in 1.hours, :public => true
        render json: AggregatedStatistic.where(pid: params[:id]).map{ |x| {"time" => x.processed_at.to_s, "count" => x.views.to_s} }.to_json
      end

      def downloads
        expires_in 1.hours, :public => true
        render json: AggregatedStatistic.where(pid: params[:id]).map{ |x| {"time" => x.processed_at.to_s, "count" => x.downloads.to_s} }.to_json
      end

      def streams
        expires_in 1.hours, :public => true
        render json: AggregatedStatistic.where(pid: params[:id]).map{ |x| {"time" => x.processed_at.to_s, "count" => x.streams.to_s} }.to_json
      end
    end
  end
end
