module Postqueue
  Timing = Struct.new(:avg_queue_time, :max_queue_time, :total_processing_time, :processing_time)

  class Base
    private

    def idempotent?(op:)
      _ = op
      false
    end

    def batch_size(op:)
      _ = op
      10
    end

    def item_class
      Postqueue::Item
    end

    def logger
      Postqueue.logger
    end

    def on_processing(op, entity_ids, timing)
      msg = "processing '#{op}' for id(s) #{entity_ids.join(',')}: "
      msg += "processing #{entity_ids.length} items took #{'%.3f msecs' % timing.total_processing_time}"

      msg += ", queue_time: avg: #{'%.3f msecs' % timing.avg_queue_time}/max: #{'%.3f msecs' % timing.max_queue_time}"
      logger.info msg
    end

    def on_exception(exception, op, entity_ids)
      logger.warn "processing '#{op}' for id(s) #{entity_ids.inspect}: caught #{exception}"
    end
  end

  def self.logger
    Logger.new(STDERR)
  end
end

require "postqueue/base/enqueue"
require "postqueue/base/select_and_lock"
require "postqueue/base/processing"
require "postqueue/base/callback"
