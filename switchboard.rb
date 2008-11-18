require 'rubygems'
require 'yaml'
require 'logger'

LOGGER = Logger.new(STDOUT)
LOGGER.level = Logger::DEBUG

# daemonize changes the directory to "/"
Dir.chdir(File.dirname(__FILE__))
CONFIG = YAML.load_file('config.yml')

require "panels/#{CONFIG['panel']['name']}_panel.rb"
require "operators/#{CONFIG['operator']['name']}_operator.rb"
require "address_books/#{CONFIG['address_book']['name']}_address_book.rb"

LOGGER.debug("Attempting to set max connections to: #{CONFIG['panel']['max_connections'].to_i}")
Process.setrlimit(Process::RLIMIT_NOFILE, CONFIG['panel']['max_connections'].to_i, Process::RLIM_INFINITY)
LOGGER.info("Max connections to: #{CONFIG['panel']['max_connections'].to_i}")

begin
  AddressBook.instance.configure(CONFIG['address_book']['options'])
  Operator.instance.configure(CONFIG['operator']['options'])
  Panel.start(CONFIG['panel']['options'])
rescue Exception => e
  LOGGER.fatal e.inspect
  LOGGER.fatal e.backtrace.join("\r\n")
end
