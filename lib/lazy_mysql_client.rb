require 'mysql2'

# Stands in for a Mysql2::Client but doesn't connect until the first query.
# Lets the app (and rails console) boot when the handle server is down; the
# connection error surfaces at the point of use instead.
class LazyMysqlClient
  def initialize(options)
    @options = options
    @mutex   = Mutex.new
    @client  = nil
  end

  def client
    @client || @mutex.synchronize { @client ||= Mysql2::Client.new(@options) }
  end

  def connected?
    !@client.nil?
  end

  def method_missing(name, *args, &block)
    if Mysql2::Client.method_defined?(name)
      client.public_send(name, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(name, include_private = false)
    Mysql2::Client.method_defined?(name) || super
  end
end
