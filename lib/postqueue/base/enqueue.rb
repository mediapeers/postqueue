module Postqueue
  class Base
    # Enqueues an queue item. If the operation, as defined by op and entity_type, is idempotent
    # (as determined by the Postqueue::Base#idempotent? method), and an entry with the same
    # combination of attributes exists already, no entry will be added to the queue.
    def enqueue(op:, entity_type:, entity_id:)
      if entity_id.is_a?(Array)
        enqueue_many(op: op, entity_type: entity_type, entity_ids: entity_id)
      end

      # An optimized code path, talking directly to PG, might be faster by a factor of 4 to 5 or so.
      if idempotent?(op: op, entity_type: entity_type)
        return if item_class.where(op: op, entity_type: entity_type, entity_id: entity_id).present?
      end

      item_class.create!(op: op, entity_type: entity_type, entity_id: entity_id)
    end

    private

    def enqueue_many(op:, entity_type:, entity_ids:) #:nodoc:
      item_class.transaction do
        entity_ids.each do |entity_id|
          enqueue(op: op, entity_type: entity_type, entity_id: entity_id)
        end
      end
    end
  end
end
