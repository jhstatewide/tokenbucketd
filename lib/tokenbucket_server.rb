require 'socket'
require 'thread'
require 'logger'

require_relative 'token_bucket.rb'

# make a pretty print for TCPSocket
class TCPSocket
  def pretty_print
    "#{peeraddr[2]}:#{peeraddr[1]}"
  end
end

# a server that implements the token bucket algorithm

class Server
  def initialize(port:, rate:, capacity:, gc_interval:, gc_threshold:)
    @server = TCPServer.new(port)
    @port = port
    @buckets = Hash.new { |h, k| h[k] = { bucket: TokenBucket.new(rate: rate, capacity: capacity), mutex: Mutex.new } }
    @gc_interval = gc_interval
    @gc_threshold = gc_threshold
    start_gc_thread
    @logger = ::Logger.new(STDOUT)
    @logger.level= ::Logger::DEBUG
    @clients = []
  end

  def start
    @logger.info { "Starting server on port #{@port}" }
    loop do
      Thread.start(@server.accept) do |client|
          @logger.info { "Accepted connection from #{client.pretty_print}" }
          @clients << client
          handle_client(client)
        ensure
          @clients.delete(client)
      end
    end
  end

  private

  def bucket_stats(bucket_name)
    bucket_info = @buckets[bucket_name]
    bucket_info[:mutex].synchronize do
      "tokens=#{bucket_info[:bucket].tokens},rate=#{bucket_info[:bucket].rate},capacity=#{bucket_info[:bucket].capacity}"
    end
  end

  def valid_bucket_name?(bucket_name)
    bucket_name&.match?(/\A[\p{L}\p{N}\p{Pc}\p{M}\p{S}]+\z/) == true
  end

  def handle_client(client)
    while (line = client.gets)
      @logger.debug { "Received #{line.chomp} from #{client.pretty_print}" }
      return unless line && line.instance_of?(String)

      command, bucket_name, parameter = line.split
      bucket_info = @buckets[bucket_name] if valid_bucket_name?(bucket_name)
      case command&.upcase
      when "CONSUME"
        # require to have a bucket name
        if bucket_name.nil?
          client.puts "ERROR CONSUME requires a bucket name"
          next
        end
        # also make sure it's a valid bucket name. it has to be a unicode string
        # with no spaces
        unless valid_bucket_name?(bucket_name)
          client.puts "ERROR Invalid bucket name"
          next
        end
        if bucket_info[:mutex].synchronize { bucket_info[:bucket].consume }
          # put back to the client the number of tokens left and some stats
          client.puts "OK #{bucket_stats(bucket_name)}"
        else
          wait_time = bucket_info[:mutex].synchronize { bucket_info[:bucket].time_until_next_token }
          client.puts "WAIT #{wait_time} #{bucket_stats(bucket_name)}"
        end
      when "RATE"
        new_rate = parameter.to_f
        bucket_info[:mutex].synchronize { bucket_info[:bucket].set_rate(new_rate) }
        client.puts "OK RATE set to #{new_rate} for bucket #{bucket_name}"
      when "CAPACITY"
        new_capacity = parameter.to_i
        bucket_info[:mutex].synchronize { bucket_info[:bucket].set_capacity(new_capacity) }
        client.puts "OK CAPACITY set to #{new_capacity} for bucket #{bucket_name}"
      when "STATS"
        # require to have a bucket name
        if bucket_name.nil?
          client.puts "ERROR STATS require a bucket name"
          next
        end
        client.puts bucket_stats(bucket_name)
      when "STATUS"
        # cram all this on one line, OK clients=2 buckets=3, bucket_name=XXX,rate=yyy.
        all_bucket_statuses = @buckets.map { |name, _| "#{name}=[#{bucket_stats(name)}]" }.join(",")
        client.puts "OK STATUS clients=#{@clients.count} buckets=#{@buckets.count} #{all_bucket_statuses}"
      else
        client.puts "ERROR Unknown command #{command}. Valid commands are CONSUME and RATE"
      end
    end
  ensure
    @logger.info { "Closing connection to #{client.pretty_print}" }
    client.close
  end

  def start_gc_thread
    Thread.new do
      loop do
        sleep @gc_interval
        now = Time.now
        @buckets.each do |name, info|
          if now - info[:bucket].last_used > @gc_threshold
            @logger.info { "Removing bucket #{name} from memory" }
            @buckets.delete(name)
          end
        end
      end
    end
  end
end
