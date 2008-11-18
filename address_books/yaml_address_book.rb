require 'singleton'
require 'thread'
require 'yaml'

class AddressBook
  include Singleton
  
  def initialize
    @servers = []
    @mutex = Mutex.new
  end
  
  def configure(config)
    servers = YAML.load_file(config['file'])
    servers.each do |server|
      @servers << server
    end
  end
  
  # this method should return an array of hosts which this request is qualified to connect to.
  # which is determined based on the contents of the data passed
  def lookup_addresses(data)
    return @servers
  end
end