require 'csv'

class AddressBook
  def initialize
    @servers = [
      {:host => 'localhost', :port => 80}
    ]
  end
  
  # this method should return an array of hosts which this request is qualified to connect to.
  # which is determined based on the contents of the data passed
  def lookup_addresses(data)
    return @servers
  end
end