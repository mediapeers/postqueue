require_relative "multi_ops/migrations"

module Postqueue
  module Policy
    module MultiOps
      QUEUE_ATTRIBUTES = [ :op, :entity_id ]

      def queue_attribute_names
        QUEUE_ATTRIBUTES
      end

      # Enqueues an queue item. If the operation is duplicate, and an entry with
      # the same combination of op and entity_id exists already, no new entry will
      # be added to the queue.
      #
      # Returns the number of items that have been enqueued.
      def enqueue(op:, entity_id:)
        ignore_duplicates = queue.idempotent_operation?(op)

        # extract array of entity ids to enqueue.
        entity_ids = entity_id.is_a?(Enumerable) ? entity_id.to_a : [ entity_id ]

        transaction do
          # when ignoring duplicates we
          #
          # - ignore duplicates within the passed in entity_ids;
          # - ignore entity ids that are already in the queue
          if ignore_duplicates
            entity_ids.uniq!
            entity_ids -= where(op: op, entity_id: entity_ids).select("DISTINCT entity_id").pluck(:entity_id)
          end

          # Insert all remaining entity_ids
          entity_ids.each do |eid|
            insert_item op: op, entity_id: eid
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
