require "active_record"

module Postqueue
  class Item < ActiveRecord::Base
    module Inserter
      # Inserter modules.
      #
      # This module provides a fast method to insert items
      def postqueue_attribute_names
        @postqueue_attribute_names ||= channel_support? ? [ :op, :entity_id, :channel ] : [ :op, :entity_id ]
      end

      def insert_item(attrs)
        values = attrs.values_at(*postqueue_attribute_names)
        connection.raw_connection.exec_params(insert_sql, values)
      end

      private

      def insert_sql
        @insert_sql ||= begin
          columns = postqueue_attribute_names
          placeholders = 1.upto(columns.count).map { |i| "$#{i}" }
          "INSERT INTO #{table_name}(#{columns.join(", ")}) VALUES(#{placeholders.join(", ")})"
        end
      end
    end
  end
end
