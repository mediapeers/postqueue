module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    def run!
      name = item_class.table_name

      loop do
        Postqueue.logger.debug "[#{name}] Processing until empty"
        process_until_empty
        Postqueue.logger.debug "[#{name}] waiting"
        Postqueue::Availability.wait
        sleep 0.3
      end
    end
  end
end
