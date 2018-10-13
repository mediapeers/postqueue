require "active_record"

module Postqueue
  #
  # An item class.
  class Item < ActiveRecord::Base
    self.table_name = :postqueue

    def self.postpone(ids)
      connection.exec_query <<-SQL
        UPDATE #{table_name}
          SET failed_attempts = failed_attempts+1,
              next_run_at = next_run_at + power(failed_attempts + 1, 1.5) * interval '10 second'
          WHERE id IN (#{ids.join(',')})
      SQL
    end
  end
end

require_relative "item/enqueue"
