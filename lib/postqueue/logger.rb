# Postqueue adapter for logging
module Postqueue
  module Logging
    # set logger to be used
    def logger=(logger)
      @logger = logger
    end

    def logger
      @logger || ::Postqueue::Logging.default_logger
    end

    def self.default_logger
      defined?(Rails) ? Rails.logger : stdout_logger
    end

    def self.stdout_logger
      @stdout_logger ||= Logger.new(STDERR)
    end

    def log_exception(exception, op, entity_ids)
      logger.warn "processing '#{op}' for id(s) #{entity_ids.inspect}: caught #{exception}"
    end

    # called after processing: this logs the processing results.
    def log_processing(op:, entity_ids:, timing:)
      msg = "processing '#{op}' for id(s) #{entity_ids.join(',')}: "
      msg += "processing #{entity_ids.length} items took #{'%.3f secs' % timing.processing}"
      msg += ", queue_time: #{'%.3f secs (avg)' % timing.avg}/#{'%.3f secs (max)' % timing.max}"

      logger.info msg
    end
  end

  extend Logging
end
