require "active_record"

module Postqueue
  class Item < ActiveRecord::Base
    module Inserter
      # Inserter modules.
      #
      # This module provides a fast method to insert items
      def queue_attribute_names
        @queue_attribute_names ||= queue_support? ? [ :op, :entity_id, :queue ] : [ :op, :entity_id ]
      end

      def insert_item(attrs)
        values = attrs.values_at(*queue_attribute_names)
        connection.raw_connection.exec_params(insert_sql, values)
      end

      private

      def insert_sql
        @insert_sql ||= begin
          columns = queue_attribute_names
          placeholders = 1.upto(columns.count).map { |i| "$#{i}" }
          quoted_table_name = connection.quote_fq_identifier table_name
          "INSERT INTO #{quoted_table_name}(#{columns.join(", ")}) VALUES(#{placeholders.join(", ")})"
        end
      end
    end
  end
end
