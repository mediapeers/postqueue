require "active_record"

module Postqueue
  #
  # An item class.
  class Item < ActiveRecord::Base
    self.table_name = :postqueue

    def self.postpone(ids)
      connection.exec_query <<-SQL
        UPDATE #{table_name}
          SET failed_attempts = failed_attempts+1,
              next_run_at = next_run_at + power(failed_attempts + 1, 1.5) * interval '10 second'
          WHERE id IN (#{ids.join(',')})
      SQL
    end
  end

  def self.unmigrate!(table_name = "postqueue")
    Item.connection.execute <<-SQL
      DROP TABLE IF EXISTS #{table_name};
    SQL
  end

  def self.upgrade_table!(table_name)
    # upgrade id column to use BIGINT if necessary
    id_max = Item.column_types['id'].send(:range).end
    if id_max <= 2147483648
      STDERR.puts "Changing type of #{table_name}.id column to BIGINT"
      Item.connection.execute "ALTER TABLE #{table_name} ALTER COLUMN id TYPE BIGINT"
      Item.connection.execute "ALTER SEQUENCE #{table_name}_id_seq RESTART WITH 2147483649"
      Item.reset_column_information
    end
  end

  def self.migrate!(table_name = "postqueue")
    connection = Item.connection

    if connection.tables.include?(table_name)
      upgrade_table!(table_name)
      return
    end

    connection.execute <<-SQL
    CREATE TABLE #{table_name} (
      id          BIGSERIAL PRIMARY KEY,
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

require_relative "item/inserter"
require_relative "item/enqueue"
