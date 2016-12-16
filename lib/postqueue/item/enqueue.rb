module Postqueue
  class Item
    # Enqueues an queue item. If the operation is duplicate, and an entry with
    # the same combination of op and entity_id exists already, no new entry will
    # be added to the queue.
    #
    # Returns the number of items that have been enqueued.
    def self.enqueue(op:, entity_id:, ignore_duplicates: false)
      if entity_id.is_a?(Enumerable)
        return enqueue_many(op: op, entity_ids: entity_id, ignore_duplicates: ignore_duplicates)
      end

      if ignore_duplicates && where(op: op, entity_id: entity_id).present?
        return 0
      end

      insert_item op: op, entity_id: entity_id
      1
    end

    def self.enqueue_many(op:, entity_ids:, ignore_duplicates:) #:nodoc:
      entity_ids.uniq! if ignore_duplicates

      transaction do
        entity_ids.each do |entity_id|
          enqueue(op: op, entity_id: entity_id, ignore_duplicates: ignore_duplicates)
        end
      end

      entity_ids.count
    end
  end
end
