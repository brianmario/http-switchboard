require 'singleton'
require 'thread'
require 'csv'

class AddressBook
  include Singleton
  
  @@mutex = Mutex.new
  
  def initialize
    @servers = []
  end
  
  def configure(config)
    @@mutex.synchronize {
      CSV.open(config['file'], 'r') do |row|
        @servers << {:host => row[1], :port => row[2].to_i}
      end
    }
    LOGGER.debug("AddressBook configured: #{@servers.size} server(s)")
  end
  
  # this method should return an array of hosts which this request is qualified to connect to.
  # which is determined based on the contents of the data passed
  def lookup_addresses(data)
    return @servers
  end
end