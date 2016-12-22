module Postqueue
  Timing = Struct.new(:avg_queue_time, :max_queue_time, :processing_time)
end
