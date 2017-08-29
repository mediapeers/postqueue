module Postqueue
  class Queue
    # The AR::Base class to use; this class is automatically created by
    # <tt>Queue#initialize</tt>.
    attr_accessor :item_class

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

    def initialize(table_name:, policy:)
      @item_class = ::Postqueue::Item.create_item_class(queue: self, table_name: table_name, policy: policy)
      @max_attemps = 5
      @idempotent_operations = {}
      @batch_sizes = {}
      @processing = :async

      set_default_callbacks
    end

    def enqueue(op:, entity_id:, queue: nil)
      check_queue_support!(queue)
      enqueued_items = item_class.enqueue op: op, entity_id: entity_id, queue: queue
      return enqueued_items unless enqueued_items > 0

      case processing
      when :async
        ::Postqueue::Availability.notify
      when :sync
        process_until_empty(queue: queue)
      when :verify
        raise(MissingHandler, queue: self, op: op, entity_ids: [entity_id]) unless callback_for(op: op)
      end

      enqueued_items
    end

    def to_s
      "#{item_class.table_name}"
    end

    private

    def check_queue_support!(queue_name)
      return if queue_name.nil?
      return if item_class.queue_support?
      raise "No queue support configured: #{self}"
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
      @batch_sizes.fetch(op, 1)
    end

    public

    # returns true if op is a idempotent operation
    def idempotent_operation?(op)
      @idempotent_operations.fetch(op) { @idempotent_operations.fetch("*", false) }
    end
  end
end

require_relative "queue/select_and_lock"
require_relative "queue/processing"
require_relative "queue/callback"
require_relative "queue/exception_handling"
require_relative "queue/runner"
