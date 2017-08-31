module Postqueue
  class Item < ActiveRecord::Base
    module Processing
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
