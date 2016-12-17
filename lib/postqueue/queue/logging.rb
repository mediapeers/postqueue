module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    private

    def on_processing(op, entity_ids, timing)
      msg = "processing '#{op}' for id(s) #{entity_ids.join(',')}: "
      msg += "processing #{entity_ids.length} items took #{'%.3f secs' % timing.total_processing_time}"

      msg += ", queue_time: avg: #{'%.3f secs' % timing.avg_queue_time}/max: #{'%.3f secs' % timing.max_queue_time}"
      logger.info msg
    end

    def log_exception(exception, op, entity_ids)
      logger.warn "processing '#{op}' for id(s) #{entity_ids.inspect}: caught #{exception}"
    end

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
  end
end
