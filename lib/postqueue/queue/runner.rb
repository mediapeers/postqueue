module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    def run!
      loop do
        queue.logger.debug "#{queue}: Processing until empty"
        queue.process_until_empty
        queue.logger.debug "#{queue}: waiting"
        Postqueue::Availability.wait
        sleep 0.3
      end
    end
  end
end
