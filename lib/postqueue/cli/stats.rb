module Postqueue::CLI
  def stats(table: Postqueue::DEFAULT_TABLE_NAME)
    Postqueue.validate_identifier!(table)

    connect_to_database!

    item_class = Postqueue.new(table_name: table_name).item_class
    recs = item_class.find_by_sql <<-SQL
      SELECT op,
        COUNT(*) AS count,
        failed_attempts,
        CASE
          WHEN failed_attempts >= 5 THEN 'FAILED'
          WHEN failed_attempts > 0 THEN 'RETRY'
          WHEN next_run_at < now() THEN 'READY'
          ELSE 'WAIT'
        END AS status,
        MIN(now() - created_at) AS min_age,
        MAX(now() - created_at) AS max_age,
        AVG(now() - created_at) AS avg_age
      FROM #{table}
      GROUP BY op, failed_attempts, status
    SQL

    require "table_print"
    tp recs, :status, :op, :failed_attempts, :count, :avg_age, :min_age, :max_age
  end

  def peek(table: Postqueue::DEFAULT_TABLE_NAME)
    connect_to_database!

    require "table_print"
    tp Postqueue.new(table_name: table).upcoming.limit(100).all
  end
end
