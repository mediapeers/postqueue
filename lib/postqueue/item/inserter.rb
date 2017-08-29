require "active_record"

module Postqueue
  #
  # Postqueue::Item inserter modules.
  #
  # This source file provides multiple implementations to insert Postqueue::Items.
  # Which one will be used depends on the "extend XXXInserter" line below.
  class Item < ActiveRecord::Base
    module RawInserter
      def queue_support?
        @queue_support = column_names.include?("queue") if @queue_support.nil?
        @queue_support
      end

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
          "INSERT INTO #{table_name}(#{columns.join(", ")}) VALUES(#{placeholders.join(", ")})"
        end
      end
    end

    extend RawInserter # 200µs per item
  end
end
