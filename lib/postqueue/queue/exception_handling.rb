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

  module ExceptionHandling
    private

    def log_exception(exception, op, entity_ids)
      Postqueue.logger.warn "processing '#{op}' for id(s) #{entity_ids.inspect}: caught #{exception}"
    end

    def on_exception(&block)
      raise ArgumentError, "on_exception expects a block argument" unless block
      raise ArgumentError, "on_exception expects a block accepting 3 or more arguments" if block.arity > -3 && block.arity != 3

      @on_exception = block
      self
    end
  end

  class Queue
    include ExceptionHandling
  end
end
