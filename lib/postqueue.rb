require_relative "postqueue/logger"
require_relative "postqueue/item"
require_relative "postqueue/version"
require_relative "postqueue/queue"
require_relative "postqueue/default_queue"

module Postqueue
  def self.new(*args, &block)
    ::Postqueue::Queue.new(*args, &block)
  end

  def self.async_processing=(async_processing)
    @async_processing = async_processing
  end

  def self.async_processing?
    @async_processing
  end

  self.async_processing = true
end

# require_relative 'postqueue/railtie' if defined?(Rails)
