# rubocop:disable Metrics/MethodLength

Dir.glob(__FILE__.sub(/\.rb$/, "/**/*.rb")).sort.each { |file| load file }

module Postqueue::CLI
  def migrate(table:)
    connect_to_database!
    Postqueue.migrate! table_name: table
  end

  def subscriptions(table: Postqueue::DEFAULT_TABLE_NAME)
    require "table_print"

    connect_to_database!
    queue = Postqueue.new table_name: table
    tp queue.subscriptions
  end

  def subscribe(channel, *ops, table: Postqueue::DEFAULT_TABLE_NAME)
    connect_to_database!
    queue = Postqueue.new table_name: table

    ActiveRecord::Base.transaction do
      ops.each do |op|
        queue.subscribe channel: channel, op: op
      end
    end
  end

  def unsubscribe(channel, *ops)
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

  def enqueue(op, entity_id, *entity_ids, table: Postqueue::DEFAULT_TABLE_NAME, channel: nil)
    connect_to_database!
    queue = Postqueue.new table_name: table
    count = queue.enqueue op: op, entity_id: [ entity_id ] + entity_ids, channel: channel
    Postqueue.logger.info "Enqueued #{count} queue items"
  end

  def run(*channels, table: Postqueue::DEFAULT_TABLE_NAME)
    connect_to_app!
    Postqueue.run! table_name: table, channel: (channels.empty? ? nil : channels)
  end

  def stats(table: Postqueue::DEFAULT_TABLE_NAME)
    connect_to_database!
    connection = ActiveRecord::Base.connection
    connection.validate_identifier!(table)

    require "table_print"
    sql = <<-SQL
    SELECT op,
      COUNT(*) AS count,
      failed_attempts,
      CASE
        WHEN failed_attempts >= 5 THEN 'FAILED'
        WHEN failed_attempts > 0 THEN 'RETRY'
        WHEN next_run_at < now() THEN 'READY'
        ELSE 'WAIT'
      END AS status,
      MIN(now() - created_at) AS min_age,
      MAX(now() - created_at) AS max_age,
      AVG(now() - created_at) AS avg_age
    FROM #{table}
    GROUP BY op, failed_attempts, status
    SQL

    recs = Postqueue.new(table_name: table_name).item_class.find_by_sql(sql)
    tp recs, :status, :op, :failed_attempts, :count, :avg_age, :min_age, :max_age
  end

  def peek
    connect_to_database!
    table_name = options.table

    require "table_print"
    tp Postqueue.new(table_name: table_name).upcoming.limit(100).all
  end
end
