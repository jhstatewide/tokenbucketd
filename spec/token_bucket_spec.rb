require 'rspec'
require_relative '../lib/token_bucket'

RSpec.describe TokenBucket do
  subject(:bucket) { described_class.new(rate: rate, capacity: capacity) }

  let(:rate) { 1 } # 5 tokens per second
  let(:capacity) { 1 } # maximum 5 tokens
  let(:consume_interval) { 1.0 / rate }
  let(:lock_duration) { 5 }  # you may need to expose lock_duration in your Server class for this test

  describe '#initialize' do
    it 'initializes with given rate and capacity' do
      expect(bucket.rate).to eq(rate)
      expect(bucket.capacity).to eq(capacity)
    end

    it 'initializes with full tokens' do
      expect(bucket.tokens).to eq(capacity)
    end
  end

  describe '#consume' do
    context 'when tokens are available' do
      it 'consumes a token and returns true' do
        expect(bucket.consume).to eq(true)
        expect(bucket.tokens).to eq(capacity - 1)
      end
    end

    context 'when no tokens are available' do
      before do
        capacity.times { bucket.consume }
      end

      it 'returns false' do
        expect(bucket.consume).to eq(false)
      end
    end
  end

  describe '#time_until_next_token' do
    context 'when tokens are available' do
      it 'returns 0' do
        expect(bucket.time_until_next_token).to eq(0)
      end
    end

    context 'when no tokens are available' do
      before do
        bucket.consume
        sleep(consume_interval/2)
      end

      it 'returns the time until the next token' do
        expect(bucket.time_until_next_token).to be_within(0.01).of(consume_interval/2)
      end
    end
  end

  describe '#set_rate' do
    let(:new_rate) { 3 }

    it 'updates the rate' do
      bucket.set_rate(new_rate)
      expect(bucket.rate).to eq(new_rate)
    end
  end

  describe '#set_capacity' do
    let(:new_capacity) { 10 }

    it 'updates the capacity' do
      bucket.set_capacity(new_capacity)
      expect(bucket.capacity).to eq(new_capacity)
    end
  end
end
