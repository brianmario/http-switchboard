require 'rubygems'
require 'rev' # gem install rev

class BackendRequest < Rev::TCPSocket
  attr_accessor :frontend
  
  def initialize(*args)
    super
    @buffer = Rev::Buffer.new
    @connected = false
  end
  
  def on_connect
    LOGGER.info "Backend connection to #{remote_addr}:#{remote_port} opened"
    @connected = true
    super
    
    write(@buffer.read) if @buffer.size > 0 and !closed?
  end
  
  def on_close
    LOGGER.info("Backend connection closed")
    @connected = false
    
    @buffer.clear
    @buffer = nil
    
    LOGGER.debug("Closing Browser connection if it's not already closed")
    @frontend.close unless @frontend.closed?
    @frontend = nil
  end

  def on_read(data)
    LOGGER.debug("Received #{data.size} bytes back from the backend, writing back to the browser")
    @frontend.write(data) unless @frontend.closed?
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
    @operator = Operator.instance
    super
  end
  
  def on_connect
    LOGGER.info "#{remote_addr}:#{remote_port} connected"
  end

  def on_close
    LOGGER.info "#{remote_addr}:#{remote_port} disconnected"
    
    if @backend
      @backend.close unless @backend.closed?
      @backend = nil
    end
    
    # we probably don't want to do this...
    GC.start
  end

  def on_read(data)
    LOGGER.debug("#{data.size} bytes of data received from browser")
    
    if @backend.nil? || (!@backend.nil? && @backend.closed?)
      LOGGER.info("Asking Operator for a jack")
      jack = @operator.lookup_jack(data)
      if jack.nil?
        # TODO: tell browser there was a problem with proper response code
        LOGGER.error("No jack found, closing browser connection (FIXME).")
        close
        return
      end
      
      LOGGER.info("Found jack: #{jack.inspect}. Connecting to it.")
      @backend = BackendRequest.connect(jack[:host], jack[:port]).attach(Panel.rev_loop)
      
      @backend.frontend = self
    end
    
    @backend.write(data) unless @backend.closed?
    
    data = nil
  end
end

class Panel
  def self.rev_loop
    @@rev_loop
  end
  
  def self.start(options)
    @@rev_loop = Rev::Loop.new(:backend => [:epoll, :kqueue])
    
    trap('INT') {
      LOGGER.warn "ctrl+c caught, stopping server"
      @@rev_loop.stop unless @@rev_loop.nil? # in case ctrl+c happens twice before we're exited
      @@rev_loop = nil
      return;
    }
    
    trap ('SIGHUP') {
      LOGGER.warn 'Hangup caught, restarting'
      # TODO: reload config
      # tell AddressBook and Operator to reconfigure themselves based on the "new" config
    }
    
    server = Rev::TCPServer.new(options['host'], options['port'], BrowserRequest)
    server.attach(@@rev_loop)
    
    # timer = Rev::TimerWatcher.new(5, true)
    # timer.instance_eval do
    #   def on_timer
    #     LOGGER.info("This will check for failed backends, and attempt to bring them back online")
    #   end
    # end
    # timer.attach(@@rev_loop)
    
    LOGGER.info "Rev panel listening on #{options['host']}:#{options['port']}"
    @@rev_loop.run
  end
end