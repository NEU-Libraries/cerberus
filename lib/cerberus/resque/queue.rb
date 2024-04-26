# Borrowed from:
# https://github.com/jeremy/resque-rails/blob/master/lib/resque/rails/queue.rb
module Cerberus
  module Resque
    class Queue
      attr_reader :default_queue_name

      def initialize(default_queue_name)
        @default_queue_name = default_queue_name
      end

      def push(job)
        queue = job.respond_to?(:queue_name) ? job.queue_name : default_queue_name
        begin
          config = YAML::load(ERB.new(IO.read(File.join(Rails.root, 'config', 'redis.yml'))).result)[Rails.env].with_indifferent_access
          Resque.redis = Redis.new(password: ENV["REDIS_PASSWD"], host: config[:host], port: config[:port], thread_safe: true, expires_in: 1.month, timeout: 10.0, reconnect_attempts: 10, tcp_keepalive: 300) rescue nil
          Resque.enqueue_to(queue, MarshaledJob, Base64.encode64(Marshal.dump(job)))
        rescue Redis::CannotConnectError
          logger.error "Redis is down!"
        end
      end
    end

    class MarshaledJob
      def self.perform(marshaled_job)
        Marshal.load(Base64.decode64(marshaled_job)).run
      end
    end
  end
end
