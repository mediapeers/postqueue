# Example postqueue.rb

Postqueue.on 'op', batch_size: 100, idempotent: true do |op, entity_ids|
  STDERR.puts "Operation #{op.inspect}: entity_ids: #{entity_ids.inspect}"
end
