module Postqueue
  class Base
    # Enqueues an queue item. If the operation is idempotent (as determined by the
    # #idempotent? method), and an entry with the same combination of op and entity_id
    # exists already, no entry will be added to the queue.
    #
    # [TODO] An optimized code path, talking directly to PG, might be faster by a factor of 4 or so.
    def enqueue(op:, entity_id:)
      if entity_id.is_a?(Array)
        enqueue_many(op: op, entity_ids: entity_id)
        return
      end

      if idempotent?(op: op) && item_class.where(op: op, entity_id: entity_id).present?
        return
      end

      item_class.create!(op: op, entity_id: entity_id)
    end

    private

    def enqueue_many(op:, entity_ids:) #:nodoc:
      item_class.transaction do
        entity_ids.each do |entity_id|
          enqueue(op: op, entity_id: entity_id)
        end
      end
    end
  end
end
