module Postqueue
  class Queue
    # Select and lock up to \a limit unlocked items in the queue. Used by
    # select_and_lock_batch.
    def select_and_lock(relation, limit:)
      # Ordering by next_run_at and id should not strictly be necessary, but helps
      # processing entries in the passed in order when enqueued at the same time.
      relation = relation
                 .select(:id, :entity_id, :op)
                 .where("failed_attempts < ? AND next_run_at < ?", max_attemps, Time.now)
                 .order(:next_run_at, :id)

      # FOR UPDATE SKIP LOCKED selects and locks entries, but skips those that
      # are already locked - preventing this transaction from being locked.
      sql = relation.to_sql + " FOR UPDATE SKIP LOCKED"
      sql += " LIMIT #{limit}" if limit

      item_class.find_by_sql(sql)
    end

    # returns a batch of queue items for processing. These queue items are choosen
    # depending on the passed in op: and batch_size: settings (if any).
    #
    # All selected queue items will have the same op value. If an op: value is
    # passed in, that one is chosen as a filter condition, otherwise the op value
    # of the first queue entry is used insteatd.
    #
    # This method will at maximum select and lock \a batch_size items. 
    # If the \a batch_size configured in the queue is smaller than the value
    # passed in here that one is used instead.
    #
    # Returns an array of item objects.
    def select_and_lock_batch(op:, max_batch_size:, &_block)
      relation = item_class.all
      relation = relation.where(op: op) if op

      match = select_and_lock(relation, limit: 1).first
      return [] unless match

      batch_size = calculate_batch_size(op: match.op, max_batch_size: max_batch_size)
      return [ match ] if batch_size <= 1

      batch_relation = relation.where(op: match.op)
      select_and_lock(batch_relation, limit: batch_size)
    end

    def calculate_batch_size(op:, max_batch_size:)
      recommended_batch_size = batch_size(op: op)
      return 1 if recommended_batch_size < 2
      return recommended_batch_size unless max_batch_size
      max_batch_size < recommended_batch_size ? max_batch_size : recommended_batch_size
    end
  end
end
