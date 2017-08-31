require_relative "postqueue/ar_ext"

require_relative "postqueue/logger"
require_relative "postqueue/migrations"
require_relative "postqueue/item"
require_relative "postqueue/version"
require_relative "postqueue/queue"
require_relative "postqueue/callback"
require_relative "postqueue/availability"

module Postqueue
  DEFAULT_TABLE_NAME = ENV["POSTQUEUE_TABLE_NAME"] || "postqueue"

  class << self
    def new(table_name: nil)
      table_name = DEFAULT_TABLE_NAME if table_name.nil?
      raise ArgumentError, "Postqueue.new no longer supports block argument" if block_given?
      raise ArgumentError, "Invalid table_name parameter" unless table_name

      ::Postqueue::Queue.new(table_name: table_name)
    end

    # run all entries from \a table_name
    def run!(table_name: nil, channel: nil)
      table_name = DEFAULT_TABLE_NAME if table_name.nil?
      new(table_name: table_name).run!(channel: channel)
    end

    # process \a batch_size entries from \a table_name
    def process!(batch_size = nil, table_name: DEFAULT_TABLE_NAME, channel: nil)
      new(table_name: table_name).process(batch_size, channel: channel)
    end

    # Create or update a database table \a table_name
    def migrate!(table_name: nil)
      table_name ||= DEFAULT_TABLE_NAME
      ::Postqueue::Item::Migrations.migrate!(table_name)
    end

    # Drop database table \a table_name
    def unmigrate!(table_name: DEFAULT_TABLE_NAME)
      ::Postqueue::Item::Migrations.unmigrate!(table_name)
    end
  end
end

# require_relative 'postqueue/railtie' if defined?(Rails)
