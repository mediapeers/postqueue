require "active_record"
require_relative "item/inserter"
require_relative "item/enqueue"
require_relative "item/processing"
require_relative "item/migrations"

module Postqueue
  #
  # An item class.
  class Item < ActiveRecord::Base
    self.table_name = nil
    self.abstract_class = true

    def self.channel_support?
      @channel_support = column_names.include?("channel") if @channel_support.nil?
      @channel_support
    end

    def self.create_item_class(table_name:)
      klass = Class.new(self)
      klass.table_name = table_name
      klass
    end

    extend Inserter
    extend Processing
    extend Enqueue
  end
end
