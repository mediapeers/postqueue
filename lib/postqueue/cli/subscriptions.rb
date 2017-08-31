module Postqueue::CLI
  def subscriptions(table: Postqueue::DEFAULT_TABLE_NAME)
    require "table_print"

    connect_to_database!
    queue = Postqueue.new table_name: table
    tp queue.subscriptions
  end

  def subscriptions_add(channel, op, *ops, table: Postqueue::DEFAULT_TABLE_NAME)
    connect_to_database!
    queue = Postqueue.new table_name: table

    ActiveRecord::Base.transaction do
      ops = [ op ] + ops
      ops.each do |o|
        queue.subscribe channel: channel, op: o
      end
    end
  end

  def subscriptions_rm(channel, *ops)
    connect_to_database!
    queue = Postqueue.new table_name: table

    ActiveRecord::Base.transaction do
      if ops.empty?
        queue.unsubscribe channel: channel
      else
        ops.each do |op|
          queue.unsubscribe channel: channel, op: op
        end
      end
    end
  end
end
