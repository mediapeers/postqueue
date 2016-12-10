require "active_record"

module Postqueue
  class Item < ActiveRecord::Base
    self.table_name = :postqueue
  end

  def self.unmigrate!
    Item.connection.execute <<-SQL
      DROP TABLE IF EXISTS postqueue;
    SQL
  end

  def self.migrate!
    Item.connection.execute <<-SQL
    CREATE TABLE postqueue (
      id          SERIAL PRIMARY KEY, 
      op          VARCHAR,
      entity_type VARCHAR,
      entity_id   INTEGER NOT NULL DEFAULT 0,
      created_at  timestamp without time zone NOT NULL DEFAULT (now() at time zone 'utc'),
      next_run_at timestamp without time zone NOT NULL DEFAULT (now() at time zone 'utc'),
      failed_attempts INTEGER NOT NULL DEFAULT 0
    );

    CREATE INDEX postqueue_idx1 ON postqueue(entity_id);
    CREATE INDEX postqueue_idx2 ON postqueue(next_run_at);
    SQL
  end
end
