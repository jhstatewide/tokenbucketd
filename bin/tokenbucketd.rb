require_relative '../lib/tokenbucket_server'

require 'getoptlong'

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  # port is an optional argument, defaults to 1234
  [ '--port', '-p', GetoptLong::OPTIONAL_ARGUMENT ],
  # rate is an optional argument, defaults to 1.0
  [ '--rate', '-r', GetoptLong::OPTIONAL_ARGUMENT ],
  # capacity is an optional argument, defaults to 1
  [ '--capacity', '-c', GetoptLong::OPTIONAL_ARGUMENT ],
  # gc_interval is an optional argument, defaults to 60
  [ '--gc_interval', '-i', GetoptLong::OPTIONAL_ARGUMENT ],
  # gc_threshold is an optional argument, defaults to 300
  [ '--gc_threshold', '-t', GetoptLong::OPTIONAL_ARGUMENT ]
)

port = 4444
rate = 1.0
capacity = 1
gc_interval = 60
gc_threshold = 300


opts.each do |opt, arg|
  case opt
  when '--help'
    puts <<-EOF
Usage: tokenbucketd [OPTION]...

  -h, --help:
    show help

  -p, --port:
    port to listen on (default: 4444)

  -r, --rate:
    rate of tokens per second (default: 1.0)

  -c, --capacity:
    maximum number of tokens (default: 1)

  -i, --gc_interval:
    garbage collection interval in seconds (default: 60)

  -t, --gc_threshold:
    garbage collection threshold in seconds (default: 300)
    EOF
    exit 0
  when '--port'
    port = arg.to_i
  when '--rate'
    rate = arg.to_f
  when '--capacity'
    capacity = arg.to_i
  when '--gc_interval'
    gc_interval = arg.to_i
  when '--gc_threshold'
    gc_threshold = arg.to_i
  end
end

server = Server.new(port: port, rate: rate, capacity: capacity, gc_interval: gc_interval, gc_threshold: gc_threshold)
server.start