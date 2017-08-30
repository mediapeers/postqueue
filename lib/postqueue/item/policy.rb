module Postqueue
  class Item < ActiveRecord::Base
    module Policy
      # Enqueues an queue item.
      #
      # Parameters:
      # - op: the op string
      # - entity_id: an entity_id or an Array of entity_ids
      # - channel: the name of the channel
      # - ignore_if_exists: when set entries that are already queued will be ignored.
      def enqueue(op:, entity_id:, channel: nil, ignore_if_exists:)
        # extract array of entity ids to enqueue.
        entity_ids = entity_id.is_a?(Enumerable) ? entity_id.to_a : [ entity_id ]

        transaction do
          if ignore_if_exists
            entity_ids.uniq!
            existing_ids = where(op: op, entity_id: entity_ids, channel: channel).select("DISTINCT entity_id").pluck(:entity_id)
            entity_ids -= existing_ids
          end

          # Insert all remaining entity_ids
          entity_ids.each do |eid|
            insert_item op: op, entity_id: eid, channel: channel
          end
        end

        entity_ids.count
      end

      def postpone(ids)
        connection.exec_query <<-SQL
          UPDATE #{quoted_table_name}
            SET failed_attempts = failed_attempts+1,
                next_run_at = next_run_at + power(failed_attempts + 1, 1.5) * interval '10 second'
            WHERE id IN (#{ids.join(',')})
        SQL
      end
    end
  end
end
