module Postqueue
  module Enqueue
    # Enqueues an queue item. If the operation is duplicate, and an entry with
    # the same combination of op and entity_id exists already, no new entry will
    # be added to the queue.
    #
    # Returns the number of items that have been enqueued.
    def enqueue(op:, entity_id:, ignore_duplicates: false)
      transaction do
        r = _enqueue(op: op, entity_id: entity_id, ignore_duplicates: ignore_duplicates)
        Postqueue::Notifications.notify! if r > 0
        r
      end
    end

    private

    def _enqueue(op:, entity_id:, ignore_duplicates: false)
      if entity_id.is_a?(Enumerable)
        return enqueue_many(op: op, entity_ids: entity_id, ignore_duplicates: ignore_duplicates)
      end

      if ignore_duplicates && where(op: op, entity_id: entity_id).present?
        return 0
      end

      # In contrast to ActiveRecord, which clocks in around 600µs per item,
      # Simple::SQL's insert only takes 100µs per item. Using prepared
      # statements would further reduce the runtime to 50µs
      ::Simple::SQL.insert table_name, op: op, entity_id: entity_id

      1
    end

    def enqueue_many(op:, entity_ids:, ignore_duplicates:) #:nodoc:
      entity_ids = Array(entity_ids)
      entity_ids.uniq! if ignore_duplicates

      # [TODO] - optimization: remove duplicates with a single SQL query.
      entity_ids.each do |entity_id|
        _enqueue(op: op, entity_id: entity_id, ignore_duplicates: ignore_duplicates)
      end

      entity_ids.count
    end
  end

  class Item
    extend ::Postqueue::Enqueue
  end
end
