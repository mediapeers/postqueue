module Postqueue
  class Queue
    Timing = Struct.new(:avg_queue_time, :max_queue_time, :total_processing_time, :processing_time)

    def run_callback(op:, entity_ids:, &_block)
      queue_times = item_class.find_by_sql <<-SQL
        SELECT extract('epoch' from AVG(now() - created_at)) AS avg,
               extract('epoch' from MAX(now() - created_at)) AS max
        FROM #{item_class.table_name} WHERE entity_id IN (#{entity_ids.join(',')})
      SQL
      queue_time = queue_times.first

      total_processing_time = Benchmark.realtime do
        yield([ op, entity_ids ]) if block_given?
      end

      Timing.new(queue_time.avg, queue_time.max, total_processing_time, total_processing_time / entity_ids.length)
    end
  end
end
