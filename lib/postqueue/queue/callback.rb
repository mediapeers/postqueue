module Postqueue
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

    class UnknownOperation < RuntimeError
      attr_reader :op, :entity_ids

      def initialize(op:, entity_ids:)
        @op = op
        @entity_ids = entity_ids
      end

      def to_s
        raise "Unknown operation #{self.op} with #{entity_ids.inspect} entities"
      end
    end

    def on_unregistered_op(op:, entity_ids:)
      raise UnknownOperation.new(op: op, entity_ids: entity_ids)
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
          on_unregistered_op(op: op, entity_ids: entity_ids)
        end
      end

      Timing.new(queue_time.avg, queue_time.max, total_processing_time, total_processing_time / entity_ids.length)
    end
  end
end
