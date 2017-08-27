require "active_record"

module Postqueue
  #
  # An item class.
  class Item < ActiveRecord::Base
    self.table_name = nil
    self.abstract_class = true

    def self.queue=(queue)
      @queue = queue
    end

    def self.queue
      @queue
    end

    def self.create_item_class(queue:, table_name:)
      klass = Class.new(self)
      klass.table_name = table_name
      klass.queue = queue

      klass.extend Postqueue::Policy::MultiOps

      # We need to give this class a name, otherwise a number of AR operations
      # are really really slow.
      Postqueue::Item.const_set(dynamic_item_class_name, klass)
      klass
    end

    def self.dynamic_item_class_name
      @dynamic_item_class_count ||= 0
      "Dynamic#{@dynamic_item_class_count += 1}"
    end
  end
end

require_relative "item/inserter"
