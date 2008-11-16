require 'rubygems'
require 'eventmachine'
require 'stringio'

class BackendRequest < EventMachine::Connection
  include EM::Deferrable
  
  attr_accessor :read_callback

  def initialize(*args)
    super
    @buffer = StringIO.new
    @connected = false
  end

  def connection_completed
    peername = self.get_peername[2,6].unpack("nC4") #http://nhw.pl/wp/2007/12/07/eventmachine-how-to-get-clients-ip-address
    peerport = peername.shift
    @peername = peername.join(".")+":"+peerport.to_s
    
    LOGGER.info "Backend connection to #{@peername} opened"
    @connected = true
    super
    
    if @buffer.size > 0
      @buffer.rewind
      send_data(@buffer.read)
    end
  end

  def receive_data(data)
    LOGGER.debug("Received #{data.size} bytes back from the backend")
    #@raw_response << data
    read_callback.call(data) unless read_callback.nil?
    super
  end
  
  def send_data(data)
    if @connected
      LOGGER.debug("Backend is connected, sending #{data.size} bytes of data")
      super(data)
    else
      LOGGER.debug("Backend isn't connected yet, buffering #{data.size} bytes of data until it is.")
      @buffer << data
    end
  end
  
  def unbind
    LOGGER.info("Backend connection closed")
    @connected = false
    
    @buffer.truncate(@buffer.size) unless @buffer.closed?
    @buffer.close unless @buffer.closed?
    @buffer = nil
  end
end

class BrowserRequest < EventMachine::Connection

  def initialize
    @operator = Operator.new
    super
  end
  
  def connection_completed
    peername = self.get_peername[2,6].unpack("nC4") #http://nhw.pl/wp/2007/12/07/eventmachine-how-to-get-clients-ip-address
    peerport = peername.shift
    @peername = peername.join(".")+":"+peerport.to_s
    
    LOGGER.info "#{@peername} connected"
  end
  
  def receive_data(data)
    LOGGER.debug("#{data.size} bytes of data received from browser")
    
    if @backend.nil?
      LOGGER.debug("Asking Operator for a jack")
      jack = @operator.lookup_jack(data)
      if jack.nil?
        # TODO: tell browser there was a problem with proper response
        LOGGER.debug("No jack found, closing browser connection (FIXME).")
        close
        return
      end
      
      LOGGER.debug("Found jack: #{jack.inspect}. Establishing a connecting to it.")
      @backend = EM.connect(jack[:host], jack[:port], BackendRequest)
      
      @backend.read_callback = proc { |d|
        LOGGER.debug("Writing #{d.size} bytes back to the browser")
        send_data(d)
      }
    end
    
    @backend.send_data(data)
    
    data = nil
  end

  def unbind
    LOGGER.info "#{@peername} disconnected"
  end
end

class Panel
  def self.start(options)
    EM::run {
      EM.epoll
      EM.start_server(options['addr'], options['port'], BrowserRequest)
      
      LOGGER.info "Eventmachine panel listening on #{options['host']}:#{options['port']}"
    }
  end
end