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
          MIN(now() - created_at) AS min_age,
          MAX(now() - created_at) AS max_age,
          AVG(now() - created_at) AS avg_age
        FROM #{Postqueue.item_class.table_name} GROUP BY op
        SQL

        recs = Postqueue.item_class.find_by_sql(sql)
        tp recs, :op, :count, :avg_age, :min_age, :max_age
      end

      def peek(_options)
        require "table_print"
        tp Postqueue.default_queue.upcoming(subselect: false).limit(100).all
      end
    end
  end
end
