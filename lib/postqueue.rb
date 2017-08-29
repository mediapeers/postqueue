require_relative "postqueue/logger"
require_relative "postqueue/item"
require_relative "postqueue/version"
require_relative "postqueue/queue"
require_relative "postqueue/policy"
require_relative "postqueue/availability"

module Postqueue
  class << self
    DEFAULT_TABLE_NAME = "postqueue"
    DEFAULT_POLICY     = "multi_ops"

    def reset!
      @queues = nil
    end

    def new(table_name: nil)
      table_name = DEFAULT_TABLE_NAME if table_name.nil?
      raise ArgumentError, "Postqueue.new no longer supports block argument" if block_given?
      raise ArgumentError, "Invalid table_name parameter" unless table_name

      policy = ::Postqueue::Policy.detect(table_name: table_name)
      @queues ||= {}
      @queues[[table_name, policy]] ||= ::Postqueue::Queue.new(table_name: table_name, policy: policy)
    end

    # run all entries from \a table_name
    def run!(table_name: nil, queue: nil)
      table_name = DEFAULT_TABLE_NAME if table_name.nil?
      new(table_name: table_name).run!(queue: queue)
    end

    # process \a batch_size entries from \a table_name
    def process!(table_name: DEFAULT_TABLE_NAME, queue: nil, batch_size: nil)
      new(table_name: table_name).process(queue: queue, batch_size: batch_size)
    end

    # Create or update a database table \a table_name to use policy \a policy
    def migrate!(table_name: nil, policy: nil)
      table_name ||= DEFAULT_TABLE_NAME
      policy     ||= DEFAULT_POLICY
      ::Postqueue::Policy.by_name(policy)::Migrations.migrate!(table_name)
    end

    # Drop database table \a table_name
    def unmigrate!(table_name: DEFAULT_TABLE_NAME)
      ::Postqueue::Policy.unmigrate!(table_name)
    end
  end
end

# require_relative 'postqueue/railtie' if defined?(Rails)
