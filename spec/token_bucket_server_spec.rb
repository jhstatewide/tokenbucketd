require 'rspec'
require_relative '../lib/tokenbucket_server'

RSpec.describe Server do
  subject(:server) { described_class.new(port: 5000, rate: rate, capacity: capacity, gc_interval: 60, gc_threshold: 300, max_buckets: 100) }

  let(:rate) { 1 }
  let(:capacity) { 1 }
  let(:lock_duration) { 5 } # you may need to expose lock_duration in your Server class for this test
  let(:bucket_name) { 'bucket1' }

  # we will need a mock "tcp client" to simulate a client sending commands to the server
  let(:tcp_client) { double('tcp_client') }

  after(:each) do
    server.destroy!
  end

  describe '#LOCK' do
    before do
      allow(tcp_client).to receive(:peeraddr).and_return(['AF_INET', 80, 'localhost'])
      allow(tcp_client).to receive(:puts)
      allow(tcp_client).to receive(:close)
      allow(tcp_client).to receive(:closed?).and_return(false)
      allow(tcp_client).to receive(:eof?).and_return(false)
      allow(tcp_client).to receive(:pretty_print).and_return('tcp_client')
    end

    it 'locks the bucket' do
      allow(tcp_client).to receive(:gets).and_return("LOCK #{bucket_name}", nil)

      # Start a thread to send the command and then sleep indefinitely
      thread = Thread.new do
        subject.send(:handle_client, tcp_client)
        sleep
      end

      # Wait for a short time to ensure the command is processed
      sleep(0.1)

      subject.send(:handle_client, tcp_client)
      expect(server.buckets[bucket_name][:locked_until]).to be > Time.now
    end
  end

  describe '#RELEASE' do
    before do
      allow(tcp_client).to receive(:peeraddr).and_return(['AF_INET', 80, 'localhost'])
      allow(tcp_client).to receive(:puts)
      allow(tcp_client).to receive(:close)
      allow(tcp_client).to receive(:closed?).and_return(false)
      allow(tcp_client).to receive(:eof?).and_return(false)
      allow(tcp_client).to receive(:pretty_print).and_return('tcp_client')

      # Initialize the bucket with a lock
      server.buckets[bucket_name] = { locked_until: Time.now + lock_duration, mutex: Mutex.new }

      allow(tcp_client).to receive(:gets).and_return("RELEASE #{bucket_name}", nil)
    end

    it 'releases the bucket' do
      subject.send(:handle_client, tcp_client)

      expect(server.buckets[bucket_name][:locked_until]).to be_nil
    end
  end

  describe '#CONSUME' do
    before do
      allow(tcp_client).to receive(:peeraddr).and_return(['AF_INET', 80, 'localhost'])
      allow(tcp_client).to receive(:puts)
      allow(tcp_client).to receive(:close)
      allow(tcp_client).to receive(:closed?).and_return(false)
      allow(tcp_client).to receive(:eof?).and_return(false)
      allow(tcp_client).to receive(:pretty_print).and_return('tcp_client')

      # Initialize the bucket with a lock
      server.buckets[bucket_name] = { locked_until: Time.now + lock_duration, mutex: Mutex.new, bucket: TokenBucket.new(rate: rate, capacity: capacity) }

      allow(tcp_client).to receive(:gets).and_return("CONSUME #{bucket_name}", nil)
    end

    it 'fails when bucket is locked' do
      expect(tcp_client).to receive(:puts).with(/WAIT/)

      subject.send(:handle_client, tcp_client)
    end
  end

  describe '#CONSUME' do
    before do
      allow(tcp_client).to receive(:peeraddr).and_return(['AF_INET', 80, 'localhost'])
      allow(tcp_client).to receive(:puts)
      allow(tcp_client).to receive(:close)
      allow(tcp_client).to receive(:closed?).and_return(false)
      allow(tcp_client).to receive(:eof?).and_return(false)
      allow(tcp_client).to receive(:pretty_print).and_return('tcp_client')

      # Initialize the bucket without a lock
      server.buckets[bucket_name] = { locked_until: nil, mutex: Mutex.new, bucket: TokenBucket.new(rate: rate, capacity: capacity) }

      allow(tcp_client).to receive(:gets).and_return("CONSUME #{bucket_name}", nil)
    end

    it 'succeeds when bucket is unlocked' do
      expect(tcp_client).to receive(:puts).with(/OK/)

      subject.send(:handle_client, tcp_client)
    end
  end

  describe '#LOCK' do
    before do
      allow(tcp_client).to receive(:peeraddr).and_return(['AF_INET', 80, 'localhost'])
      allow(tcp_client).to receive(:puts)
      allow(tcp_client).to receive(:close)
      allow(tcp_client).to receive(:closed?).and_return(false)
      allow(tcp_client).to receive(:eof?).and_return(false)
      allow(tcp_client).to receive(:pretty_print).and_return('tcp_client')
    end

    it 'fails when bucket is already locked' do
      allow(tcp_client).to receive(:gets).and_return("LOCK #{bucket_name}", "LOCK #{bucket_name}", nil)

      # Expect the client to receive the 'locked' message only on the second attempt to lock
      expect(tcp_client).to receive(:puts).with(/OK LOCKED/).ordered
      expect(tcp_client).to receive(:puts).with(/ERROR Bucket #{bucket_name} is already locked/).ordered

      subject.send(:handle_client, tcp_client)
    end

  end


end