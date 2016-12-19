module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    def run(&block)
      @run = block if block
      @run
    end

    def run!
      if !run
        run do |queue|
          while true do
            queue.logger.debug "#{queue}: Processing until empty"
            queue.process_until_empty
            queue.logger.debug "#{queue}: sleeping"
            sleep 1
          end
        end
      end

      run.call(self)
    end
  end
end
