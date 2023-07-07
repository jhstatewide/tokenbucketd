require 'logger'

class TokenBucket
  attr_reader :rate, :capacity, :tokens, :last_refill, :last_used

  # @param [Numeric] rate can be fractional, e.g. 0.5 tokens per second
  def initialize(rate:, capacity:)
    @rate = rate
    @capacity = capacity
    @tokens = capacity
    @last_refill = Time.now
    @last_used = Time.now
    @logger = ::Logger.new(STDOUT)
    @logger.level = ::Logger::DEBUG
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
    if @tokens < @capacity
      (@capacity - @tokens) / @rate
    else
      0
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
    added_tokens = (elapsed * rate).floor
    @tokens += added_tokens
    @tokens = capacity if @tokens > capacity
    @last_refill = now
  end
end