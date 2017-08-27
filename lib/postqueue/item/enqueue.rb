module Postqueue
  module Enqueue
    # Enqueues an queue item. If the operation is duplicate, and an entry with
    # the same combination of op and entity_id exists already, no new entry will
    # be added to the queue.
    #
    # Returns the number of items that have been enqueued.
    def enqueue(op:, entity_id:, ignore_duplicates: false)
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
        entity_ids.each do |entity_id|
          insert_item op: op, entity_id: entity_id
        end
      end

      entity_ids.count
    end
  end

  class Item
    extend Enqueue
  end
end
