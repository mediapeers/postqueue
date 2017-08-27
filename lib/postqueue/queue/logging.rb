module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
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

    public

    def to_s
      item_class.table_name
    end
  end
end
