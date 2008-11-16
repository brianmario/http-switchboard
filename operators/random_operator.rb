class Operator
  def initialize
    @address_book = AddressBook.new
  end
  
  def lookup_jack(data)
    addresses = @address_book.lookup_addresses(data)
    return addresses[rand(addresses.size)] unless addresses.nil?
    return nil
  end
end