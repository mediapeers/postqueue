module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    # Processes up to batch_size entries
    #
    # process batch_size: 100
    def process(channel: nil, batch_size: 100)
      item_class.transaction do
        # fetch one or more entries from the postqueue table. This will only
        # return items with the same "op" value.
        items = select_and_lock_batch(channel: channel, max_batch_size: batch_size)
        frontrunner = items.first
        return 0 unless frontrunner

        process_batch channel: channel, op: frontrunner.op, items: items

        items.length
      end
    end

    # processes a single entry
    def process_one(channel: nil)
      process(channel: channel, batch_size: 1)
    end

    def process_until_empty(channel: nil, batch_size: 100)
      count = 0
      loop do
        processed_items = process(channel: channel, batch_size: batch_size)
        break if processed_items == 0
        count += processed_items
      end
      count
    end

    private

    def process_batch(channel:, op:, items:)
      item_ids   = items.map(&:id)
      entity_ids = items.map(&:entity_id)

      timing = queueing_time(channel: channel, op: op, entity_ids: entity_ids)
      timing.processing = Benchmark.realtime do
        Postqueue.run_callback(op: op, entity_ids: entity_ids)
        item_class.where(id: item_ids).delete_all
      end

      log_processing(op: op, entity_ids: entity_ids, timing: timing)

      # even though we try not to enqueue duplicates we cannot guarantee that,
      # since concurrent enqueue transactions might still insert duplicates.
      # That's why we explicitely remove all non-failed duplicates here.
      if Postqueue.callback(op: op).idempotent?
        duplicates = select_and_lock_duplicates(channel: channel, op: op, entity_ids: entity_ids)
        item_class.where(id: duplicates.map(&:id)).delete_all unless duplicates.empty?
      end
    rescue RuntimeError => e
      item_class.postpone item_ids
      Postqueue.log_exception(e, op, entity_ids)
      @on_exception.call(e, op, entity_ids) if @on_exception
      e.send :raise
    end

    class Timing
      attr_accessor :avg, :max, :processing

      def initialize(avg:, max:, processing: 0)
        @avg, @max, @processing = avg, max, processing
      end
    end

    def queueing_time(channel:, op:, entity_ids:)
      scope = item_class.where(entity_id: entity_ids, op: op)
      scope = scope.where(channel: channel) if channel

      queue_times = item_class.find_by_sql <<-SQL
        SELECT extract('epoch' from AVG(now() - created_at)) AS avg,
               extract('epoch' from MAX(now() - created_at)) AS max
        FROM (#{scope.to_sql}) sq
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
