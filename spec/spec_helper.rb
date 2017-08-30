ENV["RACK_ENV"] = "test"

require "rspec"
require "pry"
require "simplecov"

SimpleCov.start do
  minimum_coverage 94
end

require "postqueue"
require "./spec/support/configure_active_record"

Postqueue.logger = Logger.new(File.open("log/test.log", "a"))

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run focus: (ENV["CI"] != "true")
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = "random"

  config.before { 
    Postqueue.reset!
    ActiveRecord::Base.connection.execute <<-SQL
      DELETE FROM postqueue;
      DELETE FROM postqueue_subscriptions;
    SQL
  }
  config.after  {}
end
