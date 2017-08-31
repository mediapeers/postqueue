module Postqueue
  class Queue
    # The AR::Base class to use; this class is automatically created by
    # <tt>Queue#initialize</tt>.
    attr_accessor :item_class

    def items
      item_class
    end

    def connection
      item_class.connection
    end

    # maximum number of processing attempts.
    attr_reader :max_attemps

    VALID_PROCESSING_VALUES = [ :async, :sync, :verify ]

    # sets or return the processing mode. This can be one of :async, :sync
    # or :verify (see VALID_PROCESSING_VALUES).
    def processing(processing = nil)
      return @processing if processing.nil?

      unless VALID_PROCESSING_VALUES.include?(processing)
        raise ArgumentError, "Invalid processing value, must be one of #{VALID_PROCESSING_VALUES.inspect}"
      end
      @processing = processing
    end

    def self.item_class(table_name:)
      Item.connection.validate_identifier! table_name

      klass_name = "Item#{table_name.tr('.', '_').camelize}"
      return const_get(klass_name) if const_defined?(klass_name)

      # Note: we need to give this class a name. Not only does that help with
      # keeping cached classes around, it also speeds up certain AR operations.
      klass = ::Postqueue::Item.create_item_class(table_name: table_name)
      const_set(klass_name, klass)
      klass
    end

    def initialize(table_name:)
      @item_class = ::Postqueue::Queue.item_class(table_name: table_name)

      @max_attemps = 5
      @processing = :async
    end

    def to_s
      item_class.table_name.to_s
    end

    private

    def check_channel_support!(channel)
      return if channel.nil?
      return if item_class.channel_support?
      raise "No channel support configured: #{self}"
    end
  end
end

require_relative "queue/select_and_lock"
require_relative "queue/enqueue"
require_relative "queue/processing"
require_relative "queue/exception_handling"
require_relative "queue/runner"
require_relative "queue/subscriptions"
