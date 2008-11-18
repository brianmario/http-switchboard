require 'singleton'
require 'thread'

class Operator
  include Singleton
  
  @@mutex = Mutex.new
  
  def initialize
    @address_book = AddressBook.instance
  end
  
  def configure(config)
    LOGGER.debug("Operator configured")
  end
  
  # the purpose of this method is to return a *single* host for the backend connection
  # which is determined by this operators method of load-balancing
  def lookup_jack(data)
    addresses = []
    @@mutex.synchronize {
      addresses = @address_book.lookup_addresses(data)
    }
    return addresses[rand(addresses.size)] if addresses.any?
    return nil
  end
end