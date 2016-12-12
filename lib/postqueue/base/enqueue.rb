module Postqueue
  class Base
    # Enqueues an queue item. If the operation is duplicate, and an entry with
    # the same combination of op and entity_id exists already, no new entry will
    # be added to the queue.
    #
    # [TODO] An optimized code path, talking directly to PG, might be faster by a factor of 4 or so.
    def enqueue(op:, entity_id:, ignore_duplicates: false)
      if entity_id.is_a?(Enumerable)
        enqueue_many(op: op, entity_ids: entity_id, ignore_duplicates: ignore_duplicates)
        return
      end

      if ignore_duplicates && item_class.where(op: op, entity_id: entity_id).present?
        return
      end

      item_class.insert_item op: op, entity_id: entity_id
    end

    def enqueue_many(op:, entity_ids:, ignore_duplicates:) #:nodoc:
      entity_ids.uniq! if ignore_duplicates

      item_class.transaction do
        entity_ids.each do |entity_id|
          enqueue(op: op, entity_id: entity_id, ignore_duplicates: ignore_duplicates)
        end
      end
    end
  end
end
