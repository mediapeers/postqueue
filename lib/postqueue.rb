require_relative "postqueue/logger"
require_relative "postqueue/item"
require_relative "postqueue/version"
require_relative "postqueue/queue"
require_relative "postqueue/policy"
require_relative "postqueue/availability"

module Postqueue
  class << self
    DEFAULT_TABLE_NAME = 'postqueue'
    DEFAULT_POLICY     = 'multi_ops'

    def reset!
      @queues = nil
    end

    def new(table_name: DEFAULT_TABLE_NAME, policy: DEFAULT_POLICY)
      raise ArgumentError, "Postqueue.new no longer supports block argument" if block_given?
      raise ArgumentError, "Invalid table_name parameter" unless table_name

      @queues ||= {}
      @queues[[table_name, policy]] ||= ::Postqueue::Queue.new(table_name: table_name, policy: policy)
    end

    def run!(table_name: DEFAULT_TABLE_NAME, policy: DEFAULT_POLICY)
      new(table_name: table_name, policy: policy).run!
    end

    def migrate!(table_name: DEFAULT_TABLE_NAME, policy: DEFAULT_POLICY)
      new(table_name: table_name, policy: policy).item_class.migrate!
    end

    def unmigrate!(table_name: DEFAULT_TABLE_NAME, policy: DEFAULT_POLICY)
      new(table_name: table_name, policy: policy).item_class.unmigrate!
    end
  end
end

# require_relative 'postqueue/railtie' if defined?(Rails)
