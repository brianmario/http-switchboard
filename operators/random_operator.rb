require 'singleton'
require 'thread'

class Operator
  include Singleton
  
  def initialize
    @address_book = AddressBook.instance
    @mutex = Mutex.new
  end
  
  def configure(config)
  end
  
  # the purpose of this method is to return a *single* host for the backend connection
  # which is determined by this operators method of load-balancing
  def lookup_jack(data)
    @mutex.synchronize {
      addresses = @address_book.lookup_addresses(data)
    }
    return addresses[rand(addresses.size)] unless addresses.nil?
    return nil
  end
end