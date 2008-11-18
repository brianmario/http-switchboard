require 'singleton'
require 'thread'

class Operator
  include Singleton
  
  @@mutex = Mutex.new
  
  def initialize
    @address_book = AddressBook.instance
    @addresses = []
  end
  
  def configure(config)
    LOGGER.debug("Operator configured")
  end
  
  # the purpose of this method is to return a *single* host for the backend connection
  # which is determined by this operators method of load-balancing
  def lookup_jack(data)
    jack = nil
    
    @@mutex.synchronize {
      addresses = @address_book.lookup_addresses(data)
      
      # union the arrays, removing duplicates
      @addresses = @addresses | addresses
      LOGGER.debug("Operator has #{@addresses.size} choice(s) to pick from - selecting the next one in round-robin order.")
      # perform our robin
      @addresses.push(jack = @addresses.shift)
    }
    return jack
  end
end