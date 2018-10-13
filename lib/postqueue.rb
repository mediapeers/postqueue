require "simple-sql"

require_relative "postqueue/logger"
require_relative "postqueue/notifications"
require_relative "postqueue/item"
require_relative "postqueue/version"
require_relative "postqueue/queue"
require_relative "postqueue/default_queue"

module Postqueue
  class << self
    def new(*args, &block)
      ::Postqueue::Queue.new(*args, &block)
    end
  end
end

# require_relative 'postqueue/railtie' if defined?(Rails)
