ENV["RACK_ENV"] = "test"

require "rspec"
require "pry"
require "simplecov"

SimpleCov.start do
  minimum_coverage 94
  add_filter '/vendor/'
  add_filter '/gems/'
end

require "postqueue"
require "./spec/support/configure_active_record"

logger = Logger.new(File.open("log/test.log", "a"))
logger.level = Logger::INFO

Simple::SQL.logger = Postqueue.logger = logger

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run focus: (ENV["CI"] != "true")
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = "random"

  config.before(:all) {}
  config.after {}
end
