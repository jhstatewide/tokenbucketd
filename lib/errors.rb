class TokenBucketError < StandardError
end

class TooManyBucketsError < TokenBucketError
  def initialize(msg = "Too many buckets")
    super(msg)
  end
end

class InvalidBucketName < TokenBucketError
  def initialize(msg = "Invalid bucket name")
    super(msg)
  end
end