require 'rubygems'
require 'eventmachine' # gem install eventmachine
require 'stringio'

class BackendRequest < EventMachine::Connection
  include EM::Deferrable
  
  attr_accessor :frontend

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

  def unbind
    LOGGER.info("Backend connection closed")
    @connected = false
    
    @buffer.truncate(0) unless @buffer.closed?
    @buffer.close unless @buffer.closed?
    @buffer = nil
    
    LOGGER.debug("Closing Browser connection if it's not already closed")
    @frontend.close_connection_after_writing
    @frontend = nil
  end
  
  def receive_data(data)
    LOGGER.debug("Received #{data.size} bytes back from the backend, writing back to the browser")
    @frontend.send_data(data)
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

end

class BrowserRequest < EventMachine::Connection
  attr_reader :backend
  
  def initialize
    @operator = Operator.instance
    super
  end
  
  def connection_completed
    peername = self.get_peername[2,6].unpack("nC4") #http://nhw.pl/wp/2007/12/07/eventmachine-how-to-get-clients-ip-address
    peerport = peername.shift
    @peername = peername.join(".")+":"+peerport.to_s
    
    LOGGER.info "#{@peername} connected"
  end
  
  def unbind
    LOGGER.info "#{@peername} disconnected"
    
    if @backend
      @backend.close_connection_after_writing
      @backend = nil
    end
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
      
      @backend.frontend = self
    end
    
    @backend.send_data(data)
    
    data = nil
  end

end

class Panel
  def self.start(options)
    EM::run {
      trap('INT') {
        LOGGER.warn "ctrl+c caught, stopping server"
        EM.stop_event_loop
      }

      trap ('SIGHUP') {
        LOGGER.warn 'Hangup caught, restarting'
      }
      
      EM.epoll
      EM.start_server(options['addr'], options['port'], BrowserRequest)
      
      LOGGER.info "Eventmachine panel listening on #{options['host']}:#{options['port']}"
    }
  end
end