module Postqueue
  class Queue
    # The AR::Base class to use. You would only change this if you want to run
    # the queue in a different database or in a different table.
    attr_accessor :item_class

    # The default batch size. Will be used if no specific batch size is defined
    # for an operation.
    attr_accessor :default_batch_size

    # maximum number of processing attempts.
    attr_reader :max_attemps

    VALID_PROCESSING_VALUES = [ :async, :sync, :verify ]

    # sets or return the processing mode. This must be one of :async, :sync
    # or :verify
    def processing(processing = nil)
      return @processing if processing.nil?

      unless VALID_PROCESSING_VALUES.include?(processing)
        raise ArgumentError, "Invalid processing value, must be one of #{VALID_PROCESSING_VALUES.inspect}"
      end
      @processing = processing
    end

    def initialize(table_name:)
      @batch_sizes = {}
      @item_class = ::Postqueue::Item.create_item_class(table_name: table_name)
      @default_batch_size = 1
      @max_attemps = 5
      @idempotent_operations = {}
      @batch_sizes = {}
      @processing = :async

      set_default_callbacks
    end

    def set_default_callbacks
      on :missing_handler do |op, entity_ids|
        raise MissingHandler, queue: self, op: op, entity_ids: entity_ids
      end

      on_exception do |e, _, _|
        e.send :raise
      end
    end

    def batch_size(op:)
      @batch_sizes[op] || default_batch_size || 1
    end

    def idempotent_operation?(op)
      @idempotent_operations.fetch(op) { @idempotent_operations.fetch("*", false) }
    end

    def enqueue(op:, entity_id:)
      enqueued_items = item_class.enqueue op: op, entity_id: entity_id, ignore_duplicates: idempotent_operation?(op)
      return enqueued_items unless enqueued_items > 0

      case processing
      when :async
        ::Postqueue::Availability.notify
        :nop
      when :sync
        process_until_empty(op: op)
      when :verify
        raise(MissingHandler, queue: self, op: op, entity_ids: [entity_id]) unless callback_for(op: op)
      end

      enqueued_items
    end
  end
end

require_relative "queue/select_and_lock"
require_relative "queue/processing"
require_relative "queue/callback"
require_relative "queue/logging"
require_relative "queue/runner"
