module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    def run!
      name = item_class.table_name

      loop do
        Postqueue.logger.debug "[#{name}] Processing until empty"
        process_until_empty
        Postqueue.logger.debug "[#{name}] waiting"
        # [FIXME] - a previously failed job is not running if we are waiting  
        # [FIXME] - after a job failed we are waiting even if there are good jobs
        # Postqueue::Availability.wait; sleep 0.3
        sleep 1
      end
    end
  end
end
