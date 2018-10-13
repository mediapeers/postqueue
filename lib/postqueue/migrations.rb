# rubocop:disable Metrics/MethodLength

module Postqueue
  module Migrations
    Item = ::Postqueue::Item

    def unmigrate!
      connection.execute <<-SQL
        DROP TABLE IF EXISTS #{table_name};
      SQL
    end

    def migrate!
      connection.execute <<-SQL
        CREATE TABLE IF NOT EXISTS #{table_name} (
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
        CREATE INDEX IF NOT EXISTS #{table_name}_idx1 ON #{table_name}(entity_id);

        -- This index should help picking the next entries to run. Otherwise a full tablescan
        -- would be necessary whenevr we check out items.
        CREATE INDEX IF NOT EXISTS #{table_name}_idx2 ON #{table_name}(next_run_at);
      SQL

      Item.reset_column_information

      # upgrade id column to use BIGINT if necessary
      id_max = Item.attribute_types['id'].send(:range).end
      if id_max <= 2147483648
        STDERR.puts "Changing type of #{table_name}.id column to BIGINT"
        connection.execute "ALTER TABLE #{table_name} ALTER COLUMN id TYPE BIGINT"
        connection.execute "ALTER SEQUENCE #{table_name}_id_seq RESTART WITH 2147483649"
      end

      Item.reset_column_information
    end

    private

    def connection
      Item.connection
    end

    def table_name
      Item.table_name
    end
  end

  extend Migrations
end
