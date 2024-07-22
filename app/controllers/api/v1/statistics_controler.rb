module Api
  module V1
    class StatisticsController < ApplicationController

      def views
        render json: AggregatedStatistic.where(pid: pid).map{ |x| {"time" => x.processed_at.to_s, "count" => x.views.to_s} }.to_json
      end

      def downloads
        render json: AggregatedStatistic.where(pid: pid).map{ |x| {"time" => x.processed_at.to_s, "downloads" => x.views.to_s} }.to_json
      end

      def streams
        render json: AggregatedStatistic.where(pid: pid).map{ |x| {"time" => x.processed_at.to_s, "streams" => x.views.to_s} }.to_json
      end
    end
  end
end
