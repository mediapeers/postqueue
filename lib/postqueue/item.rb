require "active_record"

module Postqueue
  class Item < ActiveRecord::Base
    # INSERTION_MODE = :active_record
    INSERTION_MODE = :fast

    self.table_name = :postqueue

    module ActiveRecordInserter
      def ar_insert_item(op:, entity_id:)
        create!(op: op, entity_id: entity_id)
      end
    end

    module RawInserter
      def prepared_inserter_statement
        @prepared_inserter_statement ||= begin
          name = "postqueue-insert-{table_name}-#{Thread.current.object_id}"
          connection.raw_connection.prepare(name, "INSERT INTO #{table_name}(op, entity_id) VALUES($1, $2)")
          name
        end
      end

      def raw_insert_item(op:, entity_id:)
        connection.raw_connection.exec_prepared(prepared_inserter_statement, [op, entity_id])
      end
    end

    extend ActiveRecordInserter
    extend RawInserter

    def self.insert_item(op:, entity_id:)
      INSERTION_MODE == :fast ? raw_insert_item(op: op, entity_id: entity_id) : ar_insert_item(op: op, entity_id: entity_id)
    end
  end

  def self.unmigrate!(table_name = "postqueue")
    Item.connection.execute <<-SQL
      DROP TABLE IF EXISTS #{table_name};
    SQL
  end

  def self.migrate!(table_name = "postqueue")
    Item.connection.execute <<-SQL
    CREATE TABLE #{table_name} (
      id          SERIAL PRIMARY KEY,
      op          VARCHAR,
      entity_id   INTEGER NOT NULL DEFAULT 0,
      created_at  timestamp without time zone NOT NULL DEFAULT (now() at time zone 'utc'),
      next_run_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'utc'),
      failed_attempts INTEGER NOT NULL DEFAULT 0
    );

    -- This index should be usable to find duplicate duplicates in the table. While
    -- we search for entries with matching op and entity_id, we assume that entity_id
    -- has a much higher cardinality.
    CREATE INDEX #{table_name}_idx1 ON #{table_name}(entity_id);

    -- This index should help picking the next entries to run. Otherwise a full tablescan
    -- would be necessary whenevr we check out items.
    CREATE INDEX #{table_name}_idx2 ON #{table_name}(next_run_at);
    SQL
  end
end
