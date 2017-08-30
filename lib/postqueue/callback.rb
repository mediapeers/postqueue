module Postqueue
  module Callback
    class Callback
      attr_reader :op, :batch_size

      def initialize(op, batch_size, idempotent, block)
        raise ArgumentError, "Invalid batch_size, must be > 0" if batch_size < 0

        @op, @batch_size, @idempotent = op, batch_size, idempotent
        @block = block
      end

      def idempotent?
        @idempotent
      end

      def call(op, entity_ids)
        @block.call op, entity_ids if @block
      end
    end

    def on(op, batch_size: nil, idempotent: nil, &block)
      raise ArgumentError, "Invalid op #{op.inspect}, must be a string" if op != :missing_handler && !op.is_a?(String)
      raise ArgumentError, "Can't set per-op batchsize for op '*'" if op == "*" && batch_size
      raise ArgumentError, "Can't idempotent for default op '*'" if op == "*" && idempotent

      batch_size ||= 1
      idempotent ||= false
      callbacks[op] = Callback.new(op, batch_size, idempotent, block)
      self
    end

    def run_callback(op:, entity_ids:)
      c = callback(op: op)
      c ||= callback(op: :missing_handler)
      if c
        c.call(op, entity_ids)
      else
        raise MissingHandler, op: op, entity_ids: entity_ids
      end
    end

    def reset!
      @callbacks = nil
    end

    def callbacks
      @callbacks ||= {}
    end

    def callback(op:)
      callbacks.fetch(op) { callbacks["*"] }
    end
  end

  extend Callback

  on_exception do |e, _, _|
    next if e.is_a?(MissingHandler)
    e.send :raise
  end
end
