module Postqueue
  module Enqueue
    # Enqueues an queue item. If the operation is duplicate, and an entry with
    # the same combination of op and entity_id exists already, no new entry will
    # be added to the queue.
    #
    # Returns the number of items that have been enqueued.
    #
    # Note: this method uses Simple::SQL.insert to insert the records, since
    # this takes ~100ys per record, where ActiveRecord would clock in ~600µs
    # per record. If Simple::SQL ever introduces prepared statements this would
    # reduce the database's processing time by another 50%.
    def enqueue(op:, entity_id:, ignore_duplicates: false)
      transaction do
        entity_ids = Array(entity_id)
        entity_ids = remove_duplicates(op, entity_ids) if ignore_duplicates
        entity_ids.each do |eid|
          ::Simple::SQL.insert table_name, op: op, entity_id: eid
        end

        Postqueue::Notifications.notify! unless entity_ids.empty?

        entity_ids.count
      end
    end

    private

    def remove_duplicates(op, entity_ids)
      return entity_ids if entity_ids.empty?

      entity_ids = entity_ids.uniq

      duplicated_ids = Simple::SQL.all <<~SQL, op, entity_ids
        SELECT DISTINCT entity_id FROM #{table_name} WHERE op=$1 AND entity_id = ANY($2)
      SQL

      entity_ids - duplicated_ids
    end
  end

  class Item
    extend ::Postqueue::Enqueue
  end
end
