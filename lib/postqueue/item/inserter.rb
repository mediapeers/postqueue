require "active_record"

module Postqueue
  #
  # Postqueue::Item inserter modules.
  #
  # This source file provides multiple implementations to insert Postqueue::Items.
  # Which one will be used depends on the "extend XXXInserter" line below.
  class Item < ActiveRecord::Base
    module ActiveRecordInserter
      def insert_item(attrs)
        create!(attrs)
      end
    end

    module RawInserter
      def insert_item(attrs)
        values = attrs.values_at(*queue_attribute_names)
        connection.raw_connection.exec_params(insert_sql, values)
      end

      private

      def insert_sql
        @insert_sql ||= begin
          columns = queue_attribute_names.map(&:to_s)
          placeholders = 1.upto(columns.count).map { |i| "$#{i}" }
          "INSERT INTO #{table_name}(#{columns.join(", ")}) VALUES(#{placeholders.join(", ")})"
        end
      end
    end

    # extend ActiveRecordInserter   # 600µs per item
    extend RawInserter # 200µs per item
  end
end
