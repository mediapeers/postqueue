module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    private

    def after_processing(&block)
      if block
        @after_processing = block
        if block.arity > -3 && block.arity != 3
          raise ArgumentError, "Invalid after_processing block: must accept 3 arguments"
        end
      end

      @after_processing
    end

    def log_exception(exception, op, entity_ids)
      logger.warn "processing '#{op}' for id(s) #{entity_ids.inspect}: caught #{exception}"
    end

    public

    def on_exception(&block)
      if block
        @on_exception = block
        if block.arity > -3 && block.arity != 3
          raise ArgumentError, "Invalid on_exception block: must accept 3 arguments"
        end
      end

      @on_exception
    end

    def logger
      Postqueue.logger
    end

    def to_s
      item_class.table_name
    end
  end
end
