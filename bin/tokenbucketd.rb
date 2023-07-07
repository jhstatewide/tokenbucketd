require_relative '../lib/tokenbucket_server'

server = Server.new(1234, (1.0/60), 1, 60, 300)
server.start