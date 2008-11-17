class Operator
  def initialize
    @address_book = AddressBook.new
  end
  
  # the purpose of this method is to return a *single* host for the backend connection
  # which is determined by this operators method of load-balancing
  def lookup_jack(data)
    addresses = @address_book.lookup_addresses(data)
    return addresses[rand(addresses.size)] unless addresses.nil?
    return nil
  end
end