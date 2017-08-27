module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    def run(&block)
      @run = block if block
      @run
    end

    def run!
      set_default_runner unless @run
      @run.call(self)
    end

    def set_default_runner
      run do |queue|
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
end
