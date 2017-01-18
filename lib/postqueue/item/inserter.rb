require "active_record"

module Postqueue
  #
  # An item class.
  class Item < ActiveRecord::Base
    module ActiveRecordInserter
      def insert_item(op:, entity_id:)
        create!(op: op, entity_id: entity_id)
      end
    end

    module RawInserter
      def prepared_inserter_statement
        @prepared_inserter_statement ||= begin
          name = "postqueue-insert-#{table_name}-#{Thread.current.object_id}"
          connection.raw_connection.prepare(name, "INSERT INTO #{table_name}(op, entity_id) VALUES($1, $2)")
          name
        end
      end

      def insert_item(op:, entity_id:)
        connection.raw_connection.exec_prepared(prepared_inserter_statement, [op, entity_id])
      end
    end

    extend RawInserter
  end
end
