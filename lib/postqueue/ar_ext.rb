# rubocop:disable Style/PredicateName

require "active_record"
require "active_record/connection_adapters/postgresql_adapter"

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def ask(sql)
    result = execute sql
    row = result.each_row.first
    row.is_a?(Array) ? row.first : row
  end

  def column_type(table_name:, column:)
    schema, table_name = parse_fq_name(table_name)
    schema = "public" if schema.nil?

    ask <<-SQL
      SELECT data_type, table_schema FROM information_schema.columns
      WHERE table_name = #{quote(table_name)}
        AND table_schema = #{quote(schema)}
        AND column_name = #{quote(column)}
    SQL
  end

  def has_column?(table_name:, column:)
    column_type(table_name: table_name, column: column) != nil
  end

  def has_table?(table_name:)
    has_column?(table_name: table_name, column: "id")
  end

  def primary_key_columns(table_name:)
    result = execute <<-SQL
      SELECT pg_attribute.attname AS name,
        format_type(pg_attribute.atttypid, pg_attribute.atttypmod) AS type
        FROM   pg_index
        JOIN   pg_attribute ON pg_attribute.attrelid = pg_index.indrelid AND pg_attribute.attnum = ANY(pg_index.indkey)
        WHERE  pg_index.indrelid = '#{table_name}'::regclass AND pg_index.indisprimary;
    SQL

    result.each_row.map { |row| OpenStruct.new(name: row[0], type: row[1]) }
  end

  def primary_key_column(table_name:)
    pks = connection.primary_key_columns table_name: tracked_table
    raise "#{table_name}: No support for tables with more than one primary key columns" if pks.length > 1
    raise "#{table_name}: No support for tables with no primary key column" if pks.length < 1
    pks.first
  end

  def parse_fq_name(fq_table_name)
    schema, table_name = fq_table_name.split(".")
    table_name ? [ schema, table_name ] : [ nil, fq_table_name ]
  end
end
