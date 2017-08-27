module Postqueue
  class MissingHandler < RuntimeError
    attr_reader :queue, :op, :entity_ids

    def initialize(queue:, op:, entity_ids:)
      @queue = queue
      @op = op
      @entity_ids = entity_ids
    end

    def to_s
      "#{queue.item_class.table_name}: Unknown operation #{op.inspect} with #{entity_ids.count} entities"
    end
  end

  class Queue
    def assert_valid_op!(op)
      return if op == :missing_handler
      return if op.is_a?(String)

      raise ArgumentError, "Invalid op #{op.inspect}, must be a string"
    end

    def on(op, batch_size: nil, idempotent: nil, &block)
      assert_valid_op! op
      callbacks[op] = block

      if batch_size
        raise ArgumentError, "Can't set per-op batchsize for op '*'" if op == "*"
        @batch_sizes[op] = batch_size
      end

      unless idempotent.nil?
        raise ArgumentError, "Can't idempotent for default op '*'" if op == "*"
        @idempotent_operations[op] = idempotent
      end

      self
    end

    private

    def callbacks
      @callbacks ||= {}
    end

    def callback_for(op:)
      callbacks[op] || callbacks["*"]
    end

    def run_callback(op:, entity_ids:)
      callback = callback_for(op: op) || callbacks.fetch(:missing_handler)
      callback.call(op, entity_ids)
    end
  end
end
