require 'rubygems'
require 'socket'
require 'thread'
require 'stringio'

class BackendRequest
  attr_accessor :frontend
  
  def initialize(sock)
    @socket = sock
    LOGGER.info "Backend connection to #{@socket.peeraddr[3]}:#{@socket.peeraddr[1]} opened"
  end
  
  def write(data)
    LOGGER.debug("Backend is connected, sending #{data.size} bytes of data")
    @socket.write(data)
    
    while !@socket.eof?
      @frontend.write(@socket.read_nonblock(8192)) unless @frontend.nil?
    end
  end
  
  def closed?
    @socket.closed?
  end
  
  def close
    @socket.close
    @socket = nil
    LOGGER.info("Backend connection closed")
    
    LOGGER.debug("Closing Browser connection if it's not already closed")
    @frontend.close unless @frontend.closed?
    @frontend = nil
  end
end

class BrowserRequest
  attr_reader :backend
  
  def initialize(sock)
    @operator = Operator.new
    
    @socket = sock
    LOGGER.info "#{@socket.peeraddr[3]}:#{@socket.peeraddr[1]} connected"
    
    read_data(@socket.read_nonblock(8192))
  end
  
  def read_data(data)
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
      @backend = BackendRequest.new(TCPSocket.new(jack[:host], jack[:port]))
      
      @backend.frontend = self
    end
    
    @backend.write(data) unless @backend.closed?
    
    data = nil
  end
  
  def write(data)
    @socket.write(data)
  end
  
  def close
    LOGGER.info "#{@socket.peeraddr[3]}:#{@socket.peeraddr[1]} disconnected"
    @socket.close
    
    if @backend
      @backend.close unless @backend.closed?
      @backend = nil
    end
    
    # we probably don't want to do this...
    GC.start
  end
end

class Panel
  def self.start(options)
    server = TCPServer.new(options['port'])
    LOGGER.info "Threaded panel listening on #{options['host']}:#{options['port']}"
    while true
      begin
        sock = server.accept_nonblock
        thread = Thread.start {
          BrowserRequest.new(sock)
        }
        thread.join
      rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
        IO.select([server])
        retry
      end
    end
  end
end