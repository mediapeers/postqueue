module Postqueue::CLI
  def tracker_migrate(table:)
    connect_to_database!

    Postqueue::Tracker.migrate! table
  end

  def tracker_track(tracked_table, table:)
    connect_to_database!

    Postqueue::Tracker.track! table, tracked_table: tracked_table
  end
end
