require "ostruct"

module Postqueue
  module CLI
    module Stats
      module_function

      def stats(_options)
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
        FROM #{Postqueue.item_class.table_name}
        GROUP BY op, failed_attempts, status
        SQL

        recs = Postqueue.item_class.find_by_sql(sql)
        tp recs, :status, :op, :failed_attempts, :count, :avg_age, :min_age, :max_age
      end

      def peek(_options)
        require "table_print"
        tp Postqueue.default_queue.upcoming.limit(100).all
      end
    end
  end
end
