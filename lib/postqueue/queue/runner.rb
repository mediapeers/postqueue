module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    def run!
      loop do
        Postqueue.logger.debug "#{self}: Processing until empty"
        process_until_empty
        Postqueue.logger.debug "#{self}: waiting"
        Postqueue::Availability.wait
        sleep 0.3
      end
    end
  end
end
