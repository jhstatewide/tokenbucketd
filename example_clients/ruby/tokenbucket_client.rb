require 'socket'

# an example client of this service
class TokenBucketClient
  def initialize(hostname:, port:)
    @server = TCPSocket.new(hostname, port)
  end

  def consume(bucket_name)
    loop do
      @server.puts("CONSUME #{bucket_name}")
      response = @server.gets.chomp
      status, *rest = response.split

      case status
      when 'OK'
        return yield
      when 'WAIT'
        sleep_time, *_ = rest
        sleep(sleep_time.to_f)
      else
        raise "Unknown response from server: #{response}"
      end
    end
  ensure
    @server.close
  end
end

# Example usage:
# client = TokenBucketClient.new(hostname: 'localhost', port: 2000)
# client.consume('foo') do
#  # do something
# end