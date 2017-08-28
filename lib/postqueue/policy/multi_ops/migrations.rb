module Postqueue
  module Policy
    module MultiOps
      module Migrations
        extend self

        def connection
          ActiveRecord::Base.connection
        end

        def unmigrate!(table_name)
          quoted_table_name = connection.quote_table_name table_name

          connection.execute <<-SQL
            DROP TABLE IF EXISTS #{quoted_table_name};
          SQL
        end

        def migrate!(table_name)
          if connection.tables.include?(table_name)
            upgrade_table!(table_name)
            return
          end

          Postqueue.logger.info "Create table #{table_name}"

          quoted_table_name = connection.quote_table_name table_name

          connection.execute <<-SQL
            CREATE TABLE #{quoted_table_name} (
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
            CREATE INDEX #{connection.quote_table_name "#{table_name}_idx1"} ON #{quoted_table_name}(entity_id);
            
            -- This index should help picking the next entries to run. Otherwise a full tablescan
            -- would be necessary whenevr we check out items.
            CREATE INDEX #{connection.quote_table_name "#{table_name}_idx2"} ON #{quoted_table_name}(next_run_at);
          SQL
        end

        private

        def upgrade_table!(table_name)
          result = connection.exec_query <<-SQL
            SELECT data_type FROM information_schema.columns
            WHERE table_name = '#{table_name}' AND column_name = 'id';
          SQL

          data_type = result.rows.first.first
          return if data_type == 'bigint'

          Postqueue.logger.info "[#{table_name}] Changing type of id column to BIGINT"
          connection.execute <<-SQL
            ALTER TABLE #{quoted_table_name} ALTER COLUMN id TYPE BIGINT;
            ALTER SEQUENCE #{connection.quote_table_name connection, "#{table_name}_seq"} RESTART WITH 2147483649
          SQL
        end
      end
    end
  end
end
