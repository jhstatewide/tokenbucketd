# A class to manage client connections
class ClientManager
  attr_reader :clients

  def initialize
    @clients = []
  end

  def add_client(client)
    @clients << client
  end

  def remove_client(client)
    @clients.delete(client)
  end

  def close_all
    @clients.each(&:close)
  end
end