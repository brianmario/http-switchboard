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

Panel.start(CONFIG['panel']['options'])
