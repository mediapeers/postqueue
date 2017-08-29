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

    def self.item_class(table_name:)
      klass_name = "Item#{table_name.camelize}"
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
      @idempotent_operations = {}
      @batch_sizes = {}
      @processing = :async

      set_default_callbacks
    end

    def enqueue(op:, entity_id:, queue: nil)
      check_queue_support!(queue)

      # enqueue items. If the operation is idempotent, we can ignore any operation
      # that is already queued, since in that case the new operation's effect will
      # only replicate what the already queued operation is doing, without any
      # discernible effect.
      enqueued_item_count = item_class.enqueue op: op, entity_id: entity_id, queue: queue,
                                               ignore_if_exists: idempotent_operation?(op)
      return 0 if enqueued_item_count == 0

      case processing
      when :async
        ::Postqueue::Availability.notify
      when :sync
        process_until_empty(queue: queue)
      when :verify
        raise(MissingHandler, queue: self, op: op, entity_ids: [entity_id]) unless callback_for(op: op)
      end

      enqueued_item_count
    end

    def to_s
      item_class.table_name.to_s
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
