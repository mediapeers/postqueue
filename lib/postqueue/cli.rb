# rubocop:disable Metrics/MethodLength

Dir.glob(__FILE__.sub(/\.rb$/, "/**/*.rb")).sort.each { |file| load file }

module Postqueue::CLI
  def migrate(table:)
    connect_to_database!
    Postqueue.migrate! table_name: table
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
end
