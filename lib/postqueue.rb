require_relative "postqueue/logger"
require_relative "postqueue/item"
require_relative "postqueue/version"
require_relative "postqueue/queue"

module Postqueue
  def self.new(*args, &block)
    ::Postqueue::Queue.new(*args, &block)
  end
end

# require_relative 'postqueue/railtie' if defined?(Rails)
