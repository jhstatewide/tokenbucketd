require 'rspec'
require_relative '../lib/token_bucket_server'

RSpec.describe TokenBucketServer do
  subject(:server) { described_class.new(port: 57777, rate: rate, capacity: capacity, gc_interval: 60, gc_threshold: 300, max_buckets: 100) }

  let(:rate) { 1 }
  let(:capacity) { 1 }
  let(:lock_duration) { 5 }
  let(:bucket_name) { 'bucket1' }
  let(:tcp_client) { double('tcp_client', peeraddr: ['AF_INET', 80, 'localhost'], close: nil, closed?: false, eof?: false, pretty_print: 'tcp_client') }

  after(:each) do
    server.destroy!
  end

  before do
    allow(tcp_client).to receive(:puts)
    server.log_level = ::Logger::ERROR
  end

  describe '#LOCK' do
    context 'when bucket is not locked' do
      it 'locks the bucket' do
        allow(tcp_client).to receive(:gets).and_return("LOCK #{bucket_name}", nil)

        thread = Thread.new { subject.send(:handle_client, tcp_client); sleep }

        sleep(0.1)

        subject.send(:handle_client, tcp_client)
        expect(server.buckets[bucket_name].locked_until).to be > Time.now
      end
    end

    context 'when bucket is already locked' do
      it 'returns an error' do
        allow(tcp_client).to receive(:gets).and_return("LOCK #{bucket_name}", "LOCK #{bucket_name}", nil)

        expect(tcp_client).to receive(:puts).with(/OK LOCKED/).ordered
        expect(tcp_client).to receive(:puts).with(/ERROR Bucket #{bucket_name} is already locked/).ordered

        subject.send(:handle_client, tcp_client)
      end
    end
  end

  describe '#RELEASE' do
    before do
      bucket_info = BucketInfo.new(bucket_name, Mutex.new, Time.now + lock_duration)
      server.buckets[bucket_name] = bucket_info
      allow(tcp_client).to receive(:gets).and_return("RELEASE #{bucket_name}", nil)
    end

    it 'releases the bucket' do
      subject.send(:handle_client, tcp_client)

      expect(server.buckets[bucket_name].locked_until).to be_nil
    end
  end

  describe '#CONSUME' do
    before do
      server.buckets[bucket_name] = BucketInfo.new(TokenBucket.new(rate: rate, capacity: capacity), Mutex.new, locked_until)
      allow(tcp_client).to receive(:gets).and_return("CONSUME #{bucket_name}", nil)
    end

    context 'when bucket is locked' do
      let(:locked_until) { Time.now + lock_duration }

      it 'returns a wait message' do
        expect(tcp_client).to receive(:puts).with(/WAIT/)

        subject.send(:handle_client, tcp_client)
      end
    end

    context 'when bucket is not locked' do
      let(:locked_until) { nil }

      it 'consumes successfully' do
        expect(tcp_client).to receive(:puts).with(/OK/)

        subject.send(:handle_client, tcp_client)
      end
    end
  end
end
