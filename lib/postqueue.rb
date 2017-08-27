require_relative "postqueue/logger"
require_relative "postqueue/item"
require_relative "postqueue/version"
require_relative "postqueue/queue"
require_relative "postqueue/default_queue"
require_relative "postqueue/availability"

module Postqueue
  class << self
    def new(*args)
      raise ArgumentError, "Postqueue.new no longer supports block argument" if block_given?

      ::Postqueue::Queue.new(*args)
    end
  end
end

# require_relative 'postqueue/railtie' if defined?(Rails)
