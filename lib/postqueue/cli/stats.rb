require "ostruct"

module Postqueue
  module CLI
    module Stats
      module_function

      def stats(table_name:)
        connection = ActiveRecord::Base.connection

        require "table_print"
        sql = <<-SQL
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
        FROM #{connection.quote_table_name table_name}
        GROUP BY op, failed_attempts, status
        SQL

        recs = Postqueue.new(table_name: table_name).item_class.find_by_sql(sql)
        tp recs, :status, :op, :failed_attempts, :count, :avg_age, :min_age, :max_age
      end

      def peek(table_name:)
        require "table_print"
        tp Postqueue.new(table_name: table_name).upcoming.limit(100).all
      end
    end
  end
end
