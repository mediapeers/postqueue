# rubocop:disable Metrics/MethodLength

Dir.glob(__FILE__.sub(/\.rb$/, "/**/*.rb")).sort.each { |file| load file }

module Postqueue::CLI
  def migrate(policy = nil)
    raise "Missing table option; use --table=tablename" unless options.table

    connect_to_database!
    Postqueue.migrate! table_name: options.table, policy: policy
  end

  def enqueue(op, entity_id, *entity_ids)
    connect_to_database!
    queue = Postqueue.new table_name: options.table
    count = queue.enqueue op: op, entity_id: [ entity_id ] + entity_ids, queue: options.queue
    Postqueue.logger.info "Enqueued #{count} queue items"
  end

  def run(*queues)
    connect_to_app!
    Postqueue.run! table_name: options.table, queue: (queues.empty? ? nil : queues)
  end

  def stats
    connect_to_database!
    table_name = options.table
    connection = ActiveRecord::Base.connection

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
    FROM #{connection.quote_table_name table_name}
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
