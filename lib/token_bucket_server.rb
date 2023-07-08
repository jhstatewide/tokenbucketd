require_relative './bucket_manager'
require_relative './client_manager'
require_relative './gc_bucket_manager'
require_relative './command_handler'
require 'socket'
require 'logger'

class TokenBucketServer
  def initialize(port:, rate:, capacity:, gc_interval:, gc_threshold:, max_buckets: 65535, lock_duration: 300)
    @server = TCPServer.new(port)
    @port = port
    @bucket_manager = BucketManager.new(rate: rate, capacity: capacity, max_buckets: max_buckets)
    @client_manager = ClientManager.new
    @gc_bucket_manager = GCBucketManager.new(@bucket_manager.buckets, gc_interval: gc_interval, gc_threshold: gc_threshold, logger: ::Logger.new(STDOUT))
    @lock_duration = lock_duration
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::DEBUG
  end

  def start
    @logger.info { "Starting server on port #{@port}" }
    @gc_bucket_manager.start
    loop do
      Thread.start(@server.accept) do |client|
        @logger.info { "Accepted connection from #{client.pretty_print}" }
        @client_manager.add_client(client)
        handle_client(client)
      ensure
        @client_manager.remove_client(client)
      end
    end
  end

  def destroy!
    @logger.info { "Shutting down server" }
    @server.close
    @gc_bucket_manager.stop
    @client_manager.close_all
  end

  def buckets
    @bucket_manager.buckets
  end

  private

  def handle_client(client)
    while (line = client.gets)
      @logger.debug { "Received #{line.chomp} from #{client.pretty_print}" }
      return unless line && line.instance_of?(String)
      CommandHandler.new(client: client, bucket_manager: @bucket_manager, lock_duration: @lock_duration, logger: @logger).handle(line)
    end
  ensure
    @logger.info { "Closing connection to #{client.pretty_print}" }
    client.close
  end
end