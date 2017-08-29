# rubocop:disable Style/PredicateName

require "active_record"
require "active_record/connection_adapters/postgresql_adapter"

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def quote_identifier(identifier)
    identifier = identifier.split(".").last
    quote_table_name identifier
  end

  def quote_fq_identifier(identifier)
    quote_table_name identifier
  end

  def column_type(table_name:, column:)
    schema, table_name = parse_fq_name(table_name)
    schema = "public" if schema.nil?

    result = exec_query <<-SQL
      SELECT data_type FROM information_schema.columns
      WHERE table_name = #{quote(table_name)}
        AND table_schema = #{quote(schema || 'public')}
        AND column_name = #{quote(column)}
    SQL

    result.rows.first&.first
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
