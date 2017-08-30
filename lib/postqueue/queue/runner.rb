module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    def run!(channel:)
      check_channel_support!(channel)

      loop do
        Postqueue.logger.debug "[#{self}] Processing until empty"
        process_until_empty(channel: channel)
        Postqueue.logger.debug "[#{self}] waiting"
        # [FIXME] - a previously failed job is not running if we are waiting
        # [FIXME] - after a job failed we are waiting even if there are good jobs
        # Postqueue::Availability.wait; sleep 0.3
        sleep 1
      end
    end
  end
end
