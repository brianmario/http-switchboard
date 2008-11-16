require 'rubygems'
require 'rev'
# require 'rev/ssl'

class BackendRequest < Rev::TCPSocket
  attr_accessor :read_callback
  
  def initialize(*args)
    super
    @buffer = Rev::Buffer.new
    @connected = false
  end
  
  def on_connect
    LOGGER.info "Backend connection to #{remote_addr}:#{remote_port} opened"
    @connected = true
    super
    
    write(@buffer.read) if @buffer.size > 0
  end
  
  def on_close
    LOGGER.info("Backend connection closed")
    @connected = false
    
    @buffer.clear
    @buffer = nil
  end

  def on_read(data)
    LOGGER.debug("Received #{data.size} bytes back from the backend")
    #@raw_response << data
    read_callback.call(data) unless read_callback.nil?
    super
  end
  
  def write(data)
    if @connected
      LOGGER.debug("Backend is connected, sending #{data.size} bytes of data")
      super(data)
    else
      LOGGER.debug("Backend isn't connected yet, buffering #{data.size} bytes of data until it is.")
      @buffer << data
    end
  end
end

class BrowserRequest < Rev::TCPSocket
  attr_reader :backend
  
  def initialize(*args)
    @operator = Operator.new
    super
  end
  
  def on_connect
    LOGGER.info "#{remote_addr}:#{remote_port} connected"
    # @buffer = Rev::Buffer.new
  end

  def on_close
    LOGGER.info "#{remote_addr}:#{remote_port} disconnected"
    
    if @backend
      @backend.close unless @backend.closed?
      @backend = nil
    end
  end

  def on_read(data)
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
      @backend = BackendRequest.connect(jack[:host], jack[:port]).attach(Rev::Loop.default)
      
      @backend.read_callback = proc { |d|
        LOGGER.debug("Writing #{d.size} bytes back to the browser")
        write(d)
      }
    end
    
    @backend.write(data) unless @backend.closed?
    
    data = nil
  end
end

# NOTE: this doesn't work yet
# class SslBrowserRequest < Rev::SSLSocket
#   def on_connect
#     LOGGER.debug('new ssl connection')
#   end
#   
#   def on_ssl_connect
#     LOGGER.debug('ssl connection established')
#   end
#   
#   def on_peer_cert(peer_cert)
#     LOGGER.debug('ssl peer cert received: '+peer_cert.inspect)
#   end
#   
#   def on_ssl_result(result)
#     LOGGER.debug('ssl handshaking completed successfully: '+result.inspect)
#   end
#   
#   def on_ssl_error(exception)
#     LOGGER.debug('ssl error: '+exception.inspect)
#   end
# end

class Panel
  def self.start(options)
    server = Rev::TCPServer.new(options['host'], options['port'], BrowserRequest)
    #server = Rev::TCPServer.new('localhost', PORT, SslBrowserRequest)
    server.attach(Rev::Loop.default)

    LOGGER.info "Rev panel listening on #{options['host']}:#{options['port']}"
    Rev::Loop.default.run
  end
end