module Postqueue
  class Base
    # Enqueues an queue item. If the operation, as defined by op and entity_type, is idempotent
    # (as determined by the Postqueue::Base#idempotent? method), and an entry with the same
    # combination of attributes exists already, no entry will be added to the queue.
    def run_callback(op:, entity_type:, entity_ids:, &_block)
      queue_times = item_class.find_by_sql <<-SQL
        SELECT extract('epoch' from AVG(now() - created_at)) AS avg,
               extract('epoch' from MAX(now() - created_at)) AS max
        FROM #{item_class.table_name} WHERE entity_id IN (#{entity_ids.join(',')})
      SQL
      queue_time = queue_times.first

      # run callback.
      result = [ op, entity_type, entity_ids ]

      total_processing_time = Benchmark.realtime do
        result = yield(*result) if block_given?
      end

      timing = Timing.new(queue_time.avg, queue_time.max, total_processing_time, total_processing_time / entity_ids.length)

      [ result, timing ]
    end
  end
end
