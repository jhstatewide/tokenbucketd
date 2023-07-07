require_relative '../lib/tokenbucket_server'

server = Server.new(port: 1234, rate: 1.0/60.0, capacity: 1, gc_interval: 60, gc_threshold: 300)
server.start