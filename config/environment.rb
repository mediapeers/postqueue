require "byebug"

queue = Postqueue.new

queue.on "test", batch_size: 100, idempotent: true do |_op, entity_ids|
  Postqueue.logger.info "[test] processing entity_ids: #{entity_ids.inspect}"
end

queue.on "fail", batch_size: 100, idempotent: true do |_op, entity_ids|
  Postqueue.logger.warn "[fail] (FAILING) processing entity_ids: #{entity_ids.inspect}"
  raise "Postqueue test failure, w/entity_ids: #{entity_ids.inspect}"
end

queue.on_exception do |e, op, entity_ids|
  STDERR.puts <<-MSG
#{e}: on processing #{op.inspect} w/entity_ids: #{entity_ids.inspect}
MSG
  # Rollbar.error(e)
end

puts "Loaded #{__FILE__}"
