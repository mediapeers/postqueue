module Postqueue
  class Queue
    # The AR::Base class to use. You would only change this if you want to run
    # the queue in a different database or in a different table.
    attr_accessor :item_class

    # The default batch size. Will be used if no specific batch size is defined
    # for an operation.
    attr_accessor :default_batch_size

    # batch size for a given op
    attr_reader :batch_sizes

    # maximum number of processing attempts.
    attr_reader :max_attemps

    def async_processing?
      @async_processing
    end

    attr_writer :async_processing

    def initialize(&block)
      @batch_sizes = {}
      @item_class = ::Postqueue::Item
      @default_batch_size = 1
      @max_attemps = 5
      @async_processing = Postqueue.async_processing?

      yield self if block
    end

    def batch_size(op:)
      batch_sizes[op] || default_batch_size || 1
    end

    def idempotent_operations
      @idempotent_operations ||= {}
    end

    def idempotent_operation?(op)
      idempotent_operations.fetch(op) { idempotent_operations.fetch("*", false) }
    end

    def idempotent_operation(op, flag = true)
      idempotent_operations[op] = flag
    end

    def enqueue(op:, entity_id:)
      enqueued_items = item_class.enqueue op: op, entity_id: entity_id, ignore_duplicates: idempotent_operation?(op)
      return unless enqueued_items > 0

      process_until_empty(op: op) unless async_processing?
    end
  end
end

require_relative "queue/select_and_lock"
require_relative "queue/processing"
require_relative "queue/callback"
require_relative "queue/logging"
