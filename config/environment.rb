require "byebug"

Postqueue.on "test", batch_size: 100, idempotent: true do |_op, entity_ids|
  puts "test, w/entity_ids: #{entity_ids.inspect}"
end

Postqueue.on "fail", batch_size: 100, idempotent: true do |_op, entity_ids|
  puts "going to fail, w/entity_ids: #{entity_ids.inspect}"
  raise "failing"
end

# Postqueue.on "foo", batch_size: 100, idempotent: true do |_op, entity_ids|
#   puts "going to fail, w/entity_ids: #{entity_ids.inspect}"
#   raise "failing"
# end

Postqueue.on_exception do |e, op, entity_ids|
  STDERR.puts <<-MSG
#{e}: on processing #{op.inspect} w/entity_ids: #{entity_ids.inspect}
MSG
  # Rollbar.error(e)
end

puts "Loaded #{__FILE__}"