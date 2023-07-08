require 'socket'
require 'thread'
require 'logger'

require_relative './errors'
require_relative './token_bucket'

# make a pretty print for TCPSocket
class TCPSocket
  def pretty_print
    "#{peeraddr[2]}:#{peeraddr[1]}"
  end
end

# a server that implements the token bucket algorithm

class Server
  def initialize(port:, rate:, capacity:, gc_interval:, gc_threshold:, max_buckets: 65535)
    @server = TCPServer.new(port)
    @port = port
    @buckets = Hash.new { |h, k| h[k] = { bucket: TokenBucket.new(rate: rate, capacity: capacity), mutex: Mutex.new, locked_until: nil } }
    @gc_interval = gc_interval
    @gc_threshold = gc_threshold
    @rate = rate
    @capacity = capacity
    start_gc_thread
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::DEBUG
    @clients = []
    @max_buckets = max_buckets
    @lock_duration = 300
  end

  def start
    @logger.info { "Starting server on port #{@port}" }
    @logger.info { "Rate: #{@rate} tokens per second" }
    @logger.info { "Capacity: #{@capacity} tokens" }
    @logger.info { "GC interval: #{@gc_interval} seconds" }
    @logger.info { "GC threshold: #{@gc_threshold} seconds" }
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

  def buckets
    @buckets
  end

  def destroy!
    @logger.info { "Shutting down server" }
    @server.close
    @gc_thread&.kill
    @clients.each(&:close)
  end

  private

  def bucket_stats(bucket_name)
    bucket_info = @buckets[bucket_name]
    "tokens=#{bucket_info[:bucket].tokens},rate=#{bucket_info[:bucket].rate},capacity=#{bucket_info[:bucket].capacity}"
  end

  def valid_bucket_name?(bucket_name)
    bucket_name&.match?(/\A[\p{L}\p{N}\p{Pc}\p{M}\p{S}.\-]+\z/) == true
  end

  def ensure_within_bucket_limit
    # see if the bucket_name already exists and if the total number
    # is at the max. if so, this is false and we should not allocate any more.
    # if not, then we can allocate
    if @buckets.size >= @max_buckets
      raise TooManyBucketsError
    end
  end

  def possibly_allocate_bucket(bucket_name)
    ensure_within_bucket_limit

    unless valid_bucket_name?(bucket_name)
      raise InvalidBucketName
    end

    @buckets[bucket_name]
  end

  def handle_client(client)
    while (line = client.gets)
      begin
        @logger.debug { "Received #{line.chomp} from #{client.pretty_print}" }
        return unless line && line.instance_of?(String)

        command, bucket_name, parameter = line.split
        case command&.upcase
        when "LOCK"
          bucket_info = possibly_allocate_bucket(bucket_name)
          bucket_info[:mutex].synchronize do
            if bucket_info[:locked_until] && bucket_info[:locked_until] > Time.now
              client.puts "ERROR Bucket #{bucket_name} is already locked"
            else
              if bucket_info[:bucket].consume
                bucket_info[:locked_until] = Time.now + @lock_duration
                client.puts "OK LOCKED #{bucket_name}. Will force unlock in #{@lock_duration} seconds."
              else
                wait_time = bucket_info[:bucket].time_until_next_token
                client.puts "WAIT #{wait_time} #{bucket_stats(bucket_name)}"
              end
            end
          end
        when "RELEASE"
          bucket_info = possibly_allocate_bucket(bucket_name)
          bucket_info[:mutex].synchronize do
            bucket_info[:locked_until] = nil
            client.puts "OK RELEASED #{bucket_name}"
          end
        when "CONSUME"
          bucket_info = possibly_allocate_bucket(bucket_name)
          next if bucket_info.nil?

          bucket_info[:mutex].synchronize do
            if bucket_info[:locked_until] && bucket_info[:locked_until] > Time.now
              client.puts "WAIT #{bucket_info[:locked_until] - Time.now} Bucket #{bucket_name} is locked"
            else
              if bucket_info[:bucket].consume
                client.puts "OK #{bucket_stats(bucket_name)}"
              else
                wait_time = bucket_info[:bucket].time_until_next_token
                client.puts "WAIT #{wait_time} #{bucket_stats(bucket_name)}"
              end
            end
          end
        when "RATE"
          bucket_info = possibly_allocate_bucket(bucket_name)
          new_rate = parameter.to_f
          bucket_info[:mutex].synchronize { bucket_info[:bucket].set_rate(new_rate) }
          client.puts "OK RATE set to #{new_rate} for bucket #{bucket_name}"
        when "CAPACITY"
          bucket_info = possibly_allocate_bucket(bucket_name)
          new_capacity = parameter.to_i
          bucket_info[:mutex].synchronize { bucket_info[:bucket].set_capacity(new_capacity) }
          client.puts "OK CAPACITY set to #{new_capacity} for bucket #{bucket_name}"
        when "STATS"
          bucket_info = possibly_allocate_bucket(bucket_name)
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
      rescue TokenBucketError => e
        @logger.error { "Error #{e.message} from #{client.pretty_print}" }
        client.puts "ERROR #{e.message}"
      end
    end
  ensure
    @logger.info { "Closing connection to #{client.pretty_print}" }
    client.close
  end

  def start_gc_thread
    @gc_thread = Thread.new do
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
