require 'socket'
require 'thread'
require 'logger'

class TokenBucket
  attr_reader :rate, :capacity, :tokens, :last_refill, :last_used

  def initialize(rate, capacity)
    @rate = rate
    @capacity = capacity
    @tokens = capacity
    @last_refill = Time.now
    @last_used = Time.now
    @logger = ::Logger.new(STDOUT)
    @logger.level= ::Logger::DEBUG
    @logger.debug { "Initialized TokenBucket with rate: #{rate} and capacity: #{capacity}" }
  end

  def consume
    refill
    if @tokens > 0
      @tokens -= 1
      @last_used = Time.now
      true
    else
      false
    end
  end

  def time_until_next_token
    refill
    if @tokens > 0
      0
    else
      (1.0 / rate) - (Time.now - last_refill)
    end
  end

  def set_rate(new_rate)
    @rate = new_rate
  end

  def set_capacity(new_capacity)
    @capacity = new_capacity
  end

  private

  def refill
    now = Time.now
    elapsed = now - @last_refill
    @tokens += elapsed * rate
    @tokens = capacity if @tokens > capacity
    @last_refill = now
  end
end

class Server
  def initialize(port, rate, capacity, gc_interval, gc_threshold)
    @server = TCPServer.new(port)
    @port = port
    @buckets = Hash.new { |h, k| h[k] = { bucket: TokenBucket.new(rate, capacity), mutex: Mutex.new } }
    @gc_interval = gc_interval
    @gc_threshold = gc_threshold
    start_gc_thread
    @logger = ::Logger.new(STDOUT)
    @logger.level= ::Logger::DEBUG
  end

  def start
    @logger.info { "Starting server on port #{@port}" }
    loop do
      Thread.start(@server.accept) do |client|
        @logger.debug { "Accepted connection from #{client}" }
        handle_client(client)
      end
    end
  end

  private

  def handle_client(client)
    while (line = client.gets)
      @logger.debug { "Received #{line.chomp} from #{client}" }
      return unless line && line.instance_of?(String)

      command, bucket_name, parameter = line.split
      bucket_info = @buckets[bucket_name]
      case command.upcase
      when "CONSUME"
        if bucket_info[:mutex].synchronize { bucket_info[:bucket].consume }
          client.puts "OK"
        else
          wait_time = bucket_info[:mutex].synchronize { bucket_info[:bucket].time_until_next_token }
          client.puts "WAIT #{wait_time}"
        end
      when "RATE"
        new_rate = parameter.to_f
        bucket_info[:mutex].synchronize { bucket_info[:bucket].set_rate(new_rate) }
        client.puts "Rate set to #{new_rate}"
      when "CAPACITY"
        new_capacity = parameter.to_i
        bucket_info[:mutex].synchronize { bucket_info[:bucket].set_capacity(new_capacity) }
        client.puts "Capacity set to #{new_capacity}"
      else
        client.puts "Unknown command #{command}. Valid commands are CONSUME and RATE"
      end
    end
  ensure
    client.close
  end

  def start_gc_thread
    Thread.new do
      loop do
        sleep @gc_interval
        now = Time.now
        @buckets.each do |name, info|
          if now - info[:bucket].last_used > @gc_threshold
            @buckets.delete(name)
          end
        end
      end
    end
  end
end
