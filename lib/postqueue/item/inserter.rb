require "active_record"
require "simple/sql"

module Postqueue
  #
  # Postqueue::Item inserter modules.
  #
  # This source file provides multiple implementations to insert Postqueue::Items.
  # Which one will be used depends on the "extend XXXInserter" line below.
  class Item < ActiveRecord::Base
    def self.insert_item(op:, entity_id:)
      # In contrast to ActiveRecord, which clocks in around 600µs per item,
      # Simple::SQL's insert only takes 100µs per item. Using prepared
      # statements would further reduce the runtime to 50µs
      ::Simple::SQL.insert table_name, op: op, entity_id: entity_id
    end
  end
end
