module Postqueue
  class Queue
    def ops
      callbacks.keys.select { |op| op.is_a?(String) }
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

    def assert_valid_op!(op)
      return if op == :missing_handler
      return if op.is_a?(String)

      raise ArgumentError, "Invalid op #{op.inspect}, must be a string"
    end

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
