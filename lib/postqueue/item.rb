require "active_record"

module Postqueue
  class Item < ActiveRecord::Base
    self.table_name = :postqueue
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
