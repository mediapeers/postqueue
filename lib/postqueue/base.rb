module Postqueue
  class Base
    private

    def item_class
      Postqueue::Item
    end

    def logger
      Postqueue.logger
    end

    def on_processing(op, entity_type, entity_ids, runtime, queue_time)
      logger.info "processing '#{op}/#{entity_type}' for id(s) #{entity_ids.join(",")}: processing #{entity_ids.length} items took #{"%.3f msecs" % runtime}, queue_time: avg: #{"%.3f msecs" % queue_time.avg}/max: #{"%.3f msecs" % queue_time.max}"
    end

    def on_exception(exception, op, entity_type, entity_ids)
      logger.warn "processing '#{op}/#{entity_type}' for id(s) #{entity_ids.join(",")}: caught #{exception}"
    end
  end

  def self.logger
    Logger.new(STDERR)
  end

  def self.new
    Base.new
  end
end

require 'postqueue/base/enqueue'
require 'postqueue/base/processing'
