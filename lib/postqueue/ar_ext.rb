# rubocop:disable Style/PredicateName

require "active_record"
require "active_record/connection_adapters/postgresql_adapter"

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def ask(sql)
    result = execute sql
    row = result.each_row.first
    row.is_a?(Array) ? row.first : row
  end

  def validate_identifier!(identifier)
    return if identifier =~ /\A([0-9a-zA-Z_]+)(\.([0-9a-zA-Z_]+))?\z/
    raise "Invalid SQL identifier: #{identifier.inspect}"
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

  def parse_fq_name(fq_table_name)
    schema, table_name = fq_table_name.split(".")
    table_name ? [ schema, table_name ] : [ nil, fq_table_name ]
  end
end
