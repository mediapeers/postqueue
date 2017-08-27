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

    def initialize(&block)
      @batch_sizes = {}
      @item_class = ::Postqueue::Item
      @default_batch_size = 1
      @max_attemps = 5
      @idempotent_operations = {}
      @batch_sizes = {}
      @processing = :async

      on "test" do |_op, entity_ids|
        Postqueue.logger.info "[test] processing entity_ids: #{entity_ids.inspect}"
      end

      on "fail" do |_op, entity_ids|
        raise "Postqueue test failure, w/entity_ids: #{entity_ids.inspect}"
      end

      on :missing_handler do |op, entity_ids|
        raise MissingHandler, queue: self, op: op, entity_ids: entity_ids
      end

      set_default_callbacks

      yield self if block
    end

    def set_default_callbacks
      on_exception do |e, _, _|
        e.send :raise
      end

      after_processing do |op, entity_ids, timing|
        processing_time = timing.processing_time
        avg_queue_time  = timing.avg_queue_time
        max_queue_time  = timing.max_queue_time

        msg = "processing '#{op}' for id(s) #{entity_ids.join(',')}: "
        msg += "processing #{entity_ids.length} items took #{'%.3f secs' % processing_time}"
        msg += ", queue_time: #{'%.3f secs (avg)' % avg_queue_time}/#{'%.3f secs (max)' % max_queue_time}"

        Postqueue.logger.info msg
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
require_relative "queue/timing"
