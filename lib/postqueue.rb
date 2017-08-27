require_relative "postqueue/logger"
require_relative "postqueue/item"
require_relative "postqueue/version"
require_relative "postqueue/queue"
require_relative "postqueue/default_queue"
require_relative "postqueue/availability"

module Postqueue
  class << self
    DEFAULT_TABLE_NAME = 'postqueue'

    def new(table_name: DEFAULT_TABLE_NAME)
      raise ArgumentError, "Postqueue.new no longer supports block argument" if block_given?
      raise ArgumentError, "Invalid table_name parameter" unless table_name

      ::Postqueue::Queue.new(table_name: table_name)
    end
  end
end

# require_relative 'postqueue/railtie' if defined?(Rails)
