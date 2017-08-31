module Postqueue
  module Migrations
    private

    def connection
      ActiveRecord::Base.connection
    end

    def create_schema!(fq_table_name)
      schema, _ = connection.parse_fq_name(fq_table_name)
      return unless schema

      connection.execute <<-SQL
        CREATE SCHEMA IF NOT EXISTS #{connection.quote_fq_identifier schema}
      SQL
    end

    def create_postqueue_table!(fq_table_name)
      return if connection.has_table?(table_name: fq_table_name)

      Postqueue.logger.info "[#{fq_table_name}] Create table"
      quoted_table_name = connection.quote_fq_identifier(fq_table_name)
      _, table_name = connection.parse_fq_name(fq_table_name)

      connection.execute <<-SQL
        CREATE TABLE #{quoted_table_name} (
          id          BIGSERIAL PRIMARY KEY,
          op          VARCHAR,
          channel     VARCHAR,
          entity_id   INTEGER NOT NULL DEFAULT 0,
          created_at  timestamp without time zone NOT NULL DEFAULT (now() at time zone 'utc'),
          next_run_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'utc'),
          failed_attempts INTEGER NOT NULL DEFAULT 0
        );

        -- This index should be usable to find duplicate duplicates in the table. While
        -- we search for entries with matching op and entity_id, we assume that entity_id
        -- has a much higher cardinality.
        CREATE INDEX #{connection.quote_identifier "#{table_name}_idx1"} ON #{quoted_table_name}(entity_id);

        -- This index should help picking the next entries to run. Otherwise a full tablescan
        -- would be necessary whenevr we check out items.
        CREATE INDEX #{connection.quote_identifier "#{table_name}_idx2"} ON #{quoted_table_name}(next_run_at);
      SQL
    end

    def create_subscriptions_table!(fq_table_name)
      subscriptions_table_name = "#{fq_table_name}_subscriptions"
      return if connection.has_table?(table_name: subscriptions_table_name)

      Postqueue.logger.info "[#{fq_table_name}] Create subscriptions table"
      quoted_table_name               = connection.quote_fq_identifier(fq_table_name)
      quoted_subscriptions_table_name = connection.quote_fq_identifier(subscriptions_table_name)
      quoted_trigger_name             = connection.quote_fq_identifier("#{fq_table_name}_trigger")

      connection.execute <<-SQL
        CREATE TABLE #{quoted_subscriptions_table_name} (
          id      BIGSERIAL PRIMARY KEY,
          op      VARCHAR,                -- items of this op with channel = NULL
          channel VARCHAR                 -- will be copied into this channel
        );

        CREATE OR REPLACE FUNCTION #{quoted_trigger_name}() RETURNS TRIGGER AS $body$
        DECLARE
          item #{quoted_table_name};
          subscription #{quoted_subscriptions_table_name};
        BEGIN
          IF NEW.channel IS NULL THEN
            FOR subscription IN
              SELECT * FROM #{quoted_subscriptions_table_name} WHERE op = NEW.op
            LOOP
              item = NEW;
              item.id = nextval('#{fq_table_name}_id_seq');
              item.channel = subscription.channel;

              INSERT INTO #{quoted_table_name} VALUES (item.*);
            END LOOP;
          END IF;

          RETURN NULL;
        END;
        $body$
        LANGUAGE plpgsql
        SECURITY DEFINER;

        CREATE TRIGGER #{quoted_trigger_name} AFTER INSERT ON #{quoted_table_name}
          FOR EACH ROW EXECUTE PROCEDURE #{quoted_trigger_name}();
      SQL
    end

    def change_postqueue_id_type!(fq_table_name)
      return if connection.column_type(table_name: fq_table_name, column: "id") == "bigint"

      Postqueue.logger.info "[#{fq_table_name}] Changing type of id column to BIGINT"
      connection.execute <<-SQL
        ALTER TABLE #{connection.quote_fq_identifier fq_table_name} ALTER COLUMN id TYPE BIGINT;
        ALTER SEQUENCE #{connection.quote_fq_identifier "#{fq_table_name}_id_seq"} RESTART WITH 2147483649
      SQL
    end

    def add_postqueue_queue_column!(fq_table_name)
      Postqueue.logger.info "[#{fq_table_name}] Adding channel column"
      connection.execute <<-SQL
        ALTER TABLE #{connection.quote_fq_identifier fq_table_name} ADD COLUMN IF NOT EXISTS channel VARCHAR;
      SQL
    end
  end
end
