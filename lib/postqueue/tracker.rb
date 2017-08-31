module Postqueue
  module Tracker
    extend self

    include Postqueue::Migrations

    def track!(fq_table_name, tracked_table:)
      Postqueue.validate_identifier!(fq_table_name)
      Postqueue.validate_identifier!(tracked_table)

      pk = connection.primary_key_column table_name: tracked_table
      raise "Only support for tables with integer types" unless %w(integer bigint).include?(pk.type)

      _, table_name = connection.parse_fq_name(fq_table_name)
      trigger_name = "#{table_name}_tracker_trigger"
      fq_trigger_name = "#{fq_table_name}_tracker_trigger"
      connection.ask <<-SQL
        DROP TRIGGER IF EXISTS #{trigger_name} ON #{tracked_table};
        CREATE TRIGGER #{trigger_name}
          AFTER INSERT OR UPDATE OR DELETE
          ON #{tracked_table}
          FOR EACH ROW EXECUTE PROCEDURE #{fq_trigger_name}('#{pk.name}');
      SQL
    end

    def migrate!(table_name)
      Postqueue.validate_identifier!(table_name)

      create_schema! table_name
      create_postqueue_table! table_name
      change_postqueue_entity_id_type! table_name
      create_tracker_table! table_name
    end

    private

    def create_tracker_table!(fq_table_name)
      Postqueue.validate_identifier!(fq_table_name)

      fq_trigger_name = "#{fq_table_name}_tracker_trigger"

      unless connection.has_column?(table_name: fq_table_name, column: "old_fields")
        Postqueue.logger.info "[#{fq_table_name}] Add 'old_fields' tracker column"
        connection.ask "ALTER TABLE #{fq_table_name} ADD COLUMN old_fields JSONB"
      end

      unless connection.has_column?(table_name: fq_table_name, column: "new_fields")
        Postqueue.logger.info "[#{fq_table_name}] Add 'new_fields' tracker column"
        connection.ask "ALTER TABLE #{fq_table_name} ADD COLUMN new_fields JSONB"
      end

      Postqueue.logger.info "[#{fq_table_name}] Create #{fq_table_name}_tracker_trigger()"

      connection.ask <<-SQL
      CREATE OR REPLACE FUNCTION #{fq_trigger_name}() RETURNS TRIGGER AS $body$
      DECLARE
        entity_pkey_name text;
        item fq_table_name;
      BEGIN
        -- determine op -------------------------------------------------------

        IF (TG_TABLE_SCHEMA = 'public') THEN
          item.op = TG_TABLE_NAME || '/' || lower(TG_OP);
        ELSE
          item.op = TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME || '/' || lower(TG_OP);
        END IF;

        -- determine entries for postqueue table ------------------------------

        entity_pkey_name = TG_ARGV[0];

        IF (TG_OP = 'UPDATE') THEN
          item.new_fields = row_to_json(NEW.*);
          item.old_fields = row_to_json(OLD.*);
          item.entity_id  = item.new_fields->entity_pkey_name;
        ELSIF (TG_OP = 'DELETE') THEN
          item.old_fields = row_to_json(OLD.*);
          item.entity_id  = item.old_fields->entity_pkey_name;
        ELSIF (TG_OP = 'INSERT') THEN
          item.new_fields = row_to_json(NEW.*);
          item.entity_id  = item.new_fields->entity_pkey_name;
        -- ELSIF (TG_OP = 'TRUNCATE') THEN
        --
        END IF;

        INSERT INTO #{fq_table_name}(op, old_fields, new_fields, entity_id) 
              VALUES(item.op, item.old_fields, item.new_fields, item.entity_id);

        RETURN NULL;
      END;
      $body$
      LANGUAGE plpgsql
      SECURITY DEFINER;
      SQL
    end
  end
end
