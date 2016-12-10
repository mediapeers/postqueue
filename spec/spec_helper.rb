path = File.expand_path('../../mpx/lib', __FILE__)
$LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)

ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'pry'
require 'simplecov'

SimpleCov.start do
  minimum_coverage 94
end

require 'postqueue'
require './spec/support/configure_active_record'

$logger = Logger.new(File.open("log/test.log", "a"))

module Postqueue
  def self.logger
    $logger
  end
end

def items
  Postqueue::Item.all
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run focus: (ENV['CI'] != 'true')
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = 'random'

  config.before(:all) { }
  config.after { }
end
