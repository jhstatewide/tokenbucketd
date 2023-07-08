# A class for GC operations on the buckets
class GCBucketManager
  def initialize(buckets, gc_interval:, gc_threshold:, logger:)
    @buckets = buckets
    @gc_interval = gc_interval
    @gc_threshold = gc_threshold
    @logger = logger
  end

  def start
    @gc_thread = Thread.new do
      loop do
        sleep @gc_interval
        now = Time.now
        @buckets.each do |name, info|
          if now - info.bucket.last_used > @gc_threshold
            @logger.info { "Removing bucket #{name} from memory" }
            @buckets.delete(name)
          end
        end
      end
    end
  end

  def stop
    @gc_thread&.kill
  end
end