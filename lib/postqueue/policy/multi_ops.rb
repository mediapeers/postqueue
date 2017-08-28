module Postqueue
  module Policy
    module MultiOps
      module Migrations
        def unmigrate!
          connection.execute <<-SQL
            DROP TABLE IF EXISTS #{quoted_table_name};
          SQL
        end

        def migrate!
          if connection.tables.include?(table_name)
            upgrade_table!
            return
          end

          Postqueue.logger.info "Create table #{quoted_table_name}"

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
          CREATE INDEX #{quote_table_name "#{table_name}_idx1"} ON #{quoted_table_name}(entity_id);

          -- This index should help picking the next entries to run. Otherwise a full tablescan
          -- would be necessary whenevr we check out items.
          CREATE INDEX #{quote_table_name "#{table_name}_idx2"} ON #{quoted_table_name}(next_run_at);
          SQL
        end
        
        private

        def quote_table_name(name)
          connection.quote_table_name name
        end

        def quoted_table_name
          quote_table_name table_name
        end

        def upgrade_table!
          result = connection.exec_query <<-SQL
            SELECT data_type FROM information_schema.columns
            WHERE table_name = '#{table_name}' AND column_name = 'id';
          SQL

          data_type = result.rows.first.first
          return if data_type == 'bigint'

          Postqueue.logger.info "Changing type of #{quoted_table_name}.id column to BIGINT"
          connection.execute "ALTER TABLE #{quoted_table_name} ALTER COLUMN id TYPE BIGINT"
          connection.execute "ALTER SEQUENCE #{quote_table_name "#{table_name}_seq"} RESTART WITH 2147483649"
          reset_column_information
        end
      end

      include Migrations

      def queue_attribute_names
        [ :op, :entity_id ]
      end

      # Enqueues an queue item. If the operation is duplicate, and an entry with
      # the same combination of op and entity_id exists already, no new entry will
      # be added to the queue.
      #
      # Returns the number of items that have been enqueued.
      def enqueue(op:, entity_id:)
        ignore_duplicates = queue.idempotent_operation?(op)

        # extract array of entity ids to enqueue.
        entity_ids = entity_id.is_a?(Enumerable) ? entity_id.to_a : [ entity_id ]

        transaction do
          # when ignoring duplicates we
          #
          # - ignore duplicates within the passed in entity_ids;
          # - ignore entity ids that are already in the queue
          if ignore_duplicates
            entity_ids.uniq!
            entity_ids -= where(op: op, entity_id: entity_ids).select("DISTINCT entity_id").pluck(:entity_id)
          end

          # Insert all remaining entity_ids
          entity_ids.each do |entity_id|
            insert_item op: op, entity_id: entity_id
          end
        end

        entity_ids.count
      end

      def postpone(ids)
        connection.exec_query <<-SQL
          UPDATE #{quoted_table_name}
            SET failed_attempts = failed_attempts+1,
                next_run_at = next_run_at + power(failed_attempts + 1, 1.5) * interval '10 second'
            WHERE id IN (#{ids.join(',')})
        SQL
      end
    end
  end
end
