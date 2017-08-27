module Postqueue::Availability
  extend self

  def notify
    connection.execute "NOTIFY #{channel}"
  end

  def listen
    connection.execute "LISTEN #{channel}"
  end

  def unlisten
    connection.execute "UNLISTEN #{channel}"
  end

  def wait
    listen
    connection.raw_connection.wait_for_notify
  end

  private

  def channel
    channel = "postqueue.availability.#{Postqueue::Item.table_name}"
    connection.raw_connection.quote_ident channel
  end

  def connection
    Postqueue::Item.connection
  end
end
