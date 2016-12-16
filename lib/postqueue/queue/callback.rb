module Postqueue
  class MissingHandler < RuntimeError
    attr_reader :queue, :op, :entity_ids

    def initialize(queue:, op:, entity_ids:)
      @queue = queue
      @op = op
      @entity_ids = entity_ids
    end

    def to_s
      "#{queue.item_class.table_name}: Unknown operation #{op} with #{entity_ids.count} entities"
    end
  end

  class Queue
    Timing = Struct.new(:avg_queue_time, :max_queue_time, :total_processing_time, :processing_time)

    def on(op, &block)
      raise ArgumentError, "Invalid op #{op.inspect}, must be a string" unless op.is_a?(String)
      callbacks[op] = block
      self
    end

    private

    def callbacks
      @callbacks ||= {}
    end

    def callback_for(op:)
      callbacks[op] || callbacks['*']
    end

    def on_missing_handler(op:, entity_ids:)
      raise MissingHandler.new(queue: self, op: op, entity_ids: entity_ids)
    end

    private

    def run_callback(op:, entity_ids:)
      queue_times = item_class.find_by_sql <<-SQL
        SELECT extract('epoch' from AVG(now() - created_at)) AS avg,
               extract('epoch' from MAX(now() - created_at)) AS max
        FROM #{item_class.table_name} WHERE entity_id IN (#{entity_ids.join(',')})
      SQL
      queue_time = queue_times.first

      total_processing_time = Benchmark.realtime do
        if callback = callback_for(op: op)
          callback.call(op, entity_ids)
        else
          on_missing_handler(op: op, entity_ids: entity_ids)
        end
      end

      Timing.new(queue_time.avg, queue_time.max, total_processing_time, total_processing_time / entity_ids.length)
    end
  end
end
