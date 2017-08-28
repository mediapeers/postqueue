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
  end

  extend Logging
end
