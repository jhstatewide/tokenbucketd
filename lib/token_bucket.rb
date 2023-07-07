class TokenBucket
  attr_reader :last_used, :rate, :capacity, :tokens

  def initialize(rate:, capacity:)
    @capacity = capacity
    @rate = rate
    @tokens = capacity
    @last_refill = @last_used = Time.now
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
    @tokens > 0 ? 0 : (@last_refill + (1 / @rate)) - Time.now
  end

  def set_rate(new_rate)
    refill
    @rate = new_rate
  end

  def set_capacity(new_capacity)
    @capacity = new_capacity
    refill
  end

  private

  def refill
    now = Time.now
    elapsed = now - @last_refill
    refill_tokens = (@rate * elapsed).floor

    if refill_tokens > 0
      @tokens = [@tokens + refill_tokens, @capacity].min
      @last_refill = now
    end
  end
end
