# rubocop:disable  Metrics/AbcSize

module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    # Processes up to batch_size entries
    #
    # process batch_size: 100
    def process(queue: nil, batch_size: nil)
      item_class.transaction do
        process_inside_transaction(queue: queue, batch_size: batch_size)
      end
    end

    # processes a single entry
    def process_one(queue: nil)
      process(queue: queue, batch_size: 1)
    end

    def process_until_empty(queue: nil, batch_size: nil)
      count = 0
      loop do
        processed_items = process(queue: queue, batch_size: batch_size)
        break if processed_items == 0
        count += processed_items
      end
      count
    end

    private

    # The actual processing. Returns the number of processed entries.
    def process_inside_transaction(queue:, batch_size:)
      # returns one or more entries from the postqueue table. This
      # implementation makes sure to return only items with the
      # same "op" value.
      items = select_and_lock_batch(queue: queue, max_batch_size: batch_size)
      next_item = items.first
      return 0 unless next_item

      entity_ids = items.map(&:entity_id)

      timing = queueing_time(op: next_item.op, entity_ids: entity_ids)
      timing.processing = Benchmark.realtime do
        run_callback(op: next_item.op, entity_ids: entity_ids)
        item_class.where(id: items.map(&:id)).delete_all
      end

      log_processing(op: next_item.op, entity_ids: entity_ids, timing: timing)

      # even though we try not to enqueue duplicates we cannot guarantee that,
      # since concurrent enqueue transactions might still insert duplicates.
      # That's why we explicitely remove all non-failed duplicates here.
      if idempotent_operation?(next_item.op)
        duplicates = select_and_lock_duplicates(queue: queue, op: next_item.op, entity_ids: entity_ids)
        item_class.where(id: duplicates.map(&:id)).delete_all unless duplicates.empty?
      end

      entity_ids.length
    rescue RuntimeError => e
      item_class.postpone items.map(&:id)
      log_exception(e, next_item.op, entity_ids)
      @on_exception.call(e, next_item.op, entity_ids)
      entity_ids.length
    end

    class Timing
      attr_accessor :avg, :max, :processing

      def initialize(avg:, max:, processing: 0)
        @avg, @max, @processing = avg, max, processing
      end
    end

    def queueing_time(op:, entity_ids:)
      queue_times = item_class.find_by_sql <<-SQL
        SELECT extract('epoch' from AVG(now() - created_at)) AS avg,
               extract('epoch' from MAX(now() - created_at)) AS max
        FROM #{item_class.table_name}
        WHERE entity_id IN (#{entity_ids.join(',')})
          AND op = '#{item_class.connection.quote_string op}'
      SQL

      queue_time = queue_times.first
      Timing.new(avg: queue_time.avg, max: queue_time.max)
    end

    # called after processing: this logs the processing results.
    def log_processing(op:, entity_ids:, timing:)
      msg = "processing '#{op}' for id(s) #{entity_ids.join(',')}: "
      msg += "processing #{entity_ids.length} items took #{'%.3f secs' % timing.processing}"
      msg += ", queue_time: #{'%.3f secs (avg)' % timing.avg}/#{'%.3f secs (max)' % timing.max}"

      Postqueue.logger.info msg
    end
  end
end
