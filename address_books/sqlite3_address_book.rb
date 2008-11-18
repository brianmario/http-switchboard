require 'singleton'
require 'thread'
require 'sqlite3' # gem install sqlite3-ruby

class AddressBook
  include Singleton
  
  def initialize
    @mutex = Mutex.new
  end
  
  def configure(config)
    @db = SQLite3::Database.new(config['database'])
    @query = config['finder_sql']
  end
  
  # this method should return an array of hosts which this request is qualified to connect to.
  # which is determined based on the contents of the data passed
  def lookup_addresses(data)
    # TODO: make this use real parameters from the data payload
    # Example:
    # req_host = data['host']
    # @db.execute(@query, req_host)
    servers = []
    @mutex.synchronize {
      @db.execute(@query) do |row|
        servers << {:host => row[0], :port => row[1]}
      end
    }
    return servers if servers.any?
    return nil
  end
end