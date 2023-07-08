# A class to handle bucket-related operations
class BucketManager
  attr_reader :buckets

  def initialize(rate:, capacity:, max_buckets:)
    @buckets = Hash.new { |h, k| h[k] = { bucket: TokenBucket.new(rate: rate, capacity: capacity), mutex: Mutex.new, locked_until: nil } }
    @max_buckets = max_buckets
  end

  def within_bucket_limit?
    @buckets.size < @max_buckets
  end

  def valid_bucket_name?(bucket_name)
    bucket_name&.match?(/\A[\p{L}\p{N}\p{Pc}\p{M}\p{S}.\-]+\z/) == true
  end

  def get_bucket(bucket_name)
    raise TooManyBucketsError unless within_bucket_limit?
    raise InvalidBucketName unless valid_bucket_name?(bucket_name)
    @buckets[bucket_name]
  end

  def bucket_stats(bucket_name)
    bucket_info = @buckets[bucket_name]
    "tokens=#{bucket_info[:bucket].tokens},rate=#{bucket_info[:bucket].rate},capacity=#{bucket_info[:bucket].capacity}"
  end

  def all_bucket_statuses
    @buckets.map { |name, _| "#{name}=[#{bucket_stats(name)}]" }.join(",")
  end
end