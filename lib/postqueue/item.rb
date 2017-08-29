require "active_record"
require_relative "item/inserter"
require_relative "item/policy"
require_relative "item/migrations"

module Postqueue
  #
  # An item class.
  class Item < ActiveRecord::Base
    self.table_name = nil
    self.abstract_class = true

    def self.queue_support?
      @queue_support = column_names.include?("queue") if @queue_support.nil?
      @queue_support
    end

    def self.create_item_class(table_name:)
      klass = Class.new(self)
      klass.table_name = table_name
      klass
    end

    def self.dynamic_item_class_name
      @dynamic_item_class_count ||= 0
      "Dynamic#{@dynamic_item_class_count += 1}"
    end

    extend Inserter
    extend Policy
  end
end
