module Postqueue
  def self.logger=(logger)
    @logger ||= logger
  end

  def self.logger
    @logger || default_logger
  end

  def self.default_logger
    defined?(Rails) ? Rails.logger : stdout_logger
  end

  def self.stdout_logger
    @stdout_logger ||= Logger.new(STDOUT)
  end
end
