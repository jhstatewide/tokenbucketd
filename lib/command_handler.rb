require_relative 'errors'
class CommandHandler
  def initialize(client:, bucket_manager:, lock_duration:, logger:)
    @client = client
    @bucket_manager = bucket_manager
    @lock_duration = lock_duration
    @logger = logger
  end

  def handle(line)
    command, bucket_name, parameter = line.split
    case command&.upcase
    when "LOCK"
      handle_lock(bucket_name)
    when "RELEASE"
      handle_release(bucket_name)
    when "CONSUME"
      handle_consume(bucket_name)
    when "RATE"
      handle_rate(bucket_name, parameter)
    when "CAPACITY"
      handle_capacity(bucket_name, parameter)
    when "STATS"
      handle_stats(bucket_name)
    when "STATUS"
      handle_status
    else
      @client.puts "ERROR Unknown command #{command}. Valid commands are CONSUME, RATE, LOCK, RELEASE, CAPACITY, STATS, and STATUS"
    end
  rescue TokenBucketError => e
    @logger.error { "Error #{e.message} from #{@client.pretty_print}" }
    @client.puts "ERROR #{e.message}"
  end

  private

  def handle_lock(bucket_name)
    bucket_info = @bucket_manager.get_bucket(bucket_name)
    bucket_info[:mutex].synchronize do
      if bucket_info[:locked_until] && bucket_info[:locked_until] > Time.now
        @client.puts "ERROR Bucket #{bucket_name} is already locked"
      else
        if bucket_info[:bucket].consume
          bucket_info[:locked_until] = Time.now + @lock_duration
          @client.puts "OK LOCKED #{bucket_name}. Will force unlock in #{@lock_duration} seconds."
        else
          wait_time = bucket_info[:bucket].time_until_next_token
          @client.puts "WAIT #{wait_time} #{@bucket_manager.bucket_stats(bucket_name)}"
        end
      end
    end
  end

  def handle_release(bucket_name)
    bucket_info = @bucket_manager.get_bucket(bucket_name)
    bucket_info[:mutex].synchronize do
      bucket_info[:locked_until] = nil
      @client.puts "OK RELEASED #{bucket_name}"
    end
  end

  def handle_consume(bucket_name)
    bucket_info = @bucket_manager.get_bucket(bucket_name)
    bucket_info[:mutex].synchronize do
      if bucket_info[:locked_until] && bucket_info[:locked_until] > Time.now
        @client.puts "WAIT #{bucket_info[:locked_until] - Time.now} Bucket #{bucket_name} is locked"
      else
        if bucket_info[:bucket].consume
          @client.puts "OK #{@bucket_manager.bucket_stats(bucket_name)}"
        else
          wait_time = bucket_info[:bucket].time_until_next_token
          @client.puts "WAIT #{wait_time} #{@bucket_manager.bucket_stats(bucket_name)}"
        end
      end
    end
  end

  def handle_rate(bucket_name, parameter)
    bucket_info = @bucket_manager.get_bucket(bucket_name)
    new_rate = parameter.to_f
    bucket_info[:mutex].synchronize { bucket_info[:bucket].set_rate(new_rate) }
    @client.puts "OK RATE set to #{new_rate} for bucket #{bucket_name}"
  end

  def handle_capacity(bucket_name, parameter)
    bucket_info = @bucket_manager.get_bucket(bucket_name)
    new_capacity = parameter.to_i
    bucket_info[:mutex].synchronize { bucket_info[:bucket].set_capacity(new_capacity) }
    @client.puts "OK CAPACITY set to #{new_capacity} for bucket #{bucket_name}"
  end

  def handle_stats(bucket_name)
    # require to have a bucket name
    if bucket_name.nil?
      @client.puts "ERROR STATS require a bucket name"
      return
    end
    @client.puts @bucket_manager.bucket_stats(bucket_name)
  end

  def handle_status
    # cram all this on one line, OK clients=2 buckets=3, bucket_name=XXX,rate=yyy.
    all_bucket_statuses = @bucket_manager.all_bucket_statuses
    @client.puts "OK STATUS buckets=#{bucket_manager.buckets.count} #{all_bucket_statuses}"
  end
end
