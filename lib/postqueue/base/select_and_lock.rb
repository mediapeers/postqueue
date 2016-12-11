module Postqueue
  class Base
    # Select and lock up to \a limit unlocked items in the queue.
    def select_and_lock(relation, limit:)
      # Ordering by next_run_at and id should not strictly be necessary, but helps
      # processing entries in the passed in order when enqueued at the same time.
      relation = relation.where("failed_attempts < ? AND next_run_at < ?", MAX_ATTEMPTS, Time.now).order(:next_run_at, :id)

      # FOR UPDATE SKIP LOCKED selects and locks entries, but skips those that
      # are already locked - preventing this transaction from being locked.
      sql = relation.to_sql + " FOR UPDATE SKIP LOCKED"
      sql += " LIMIT #{limit}" if limit
      item_class.find_by_sql(sql)
    end

    # returns a batch of queue items for processing. These queue items are choosen
    # depending on the passed in entity_type:, op: and batch_size: settings (if any).
    #
    # They will all have identical entity_type and op values, and will not be more
    # (but potentially less) batch_size values. All entries will be locked in the
    # database, and locked entries will be skipped.
    def select_and_lock_batch(entity_type:, op:, batch_size:, &_block)
      relation = item_class.all
      relation = relation.where(entity_type: entity_type) if entity_type
      relation = relation.where(op: op) if op

      first_match = select_and_lock(relation, limit: 1).first
      return [] unless first_match

      op = first_match.op
      entity_type = first_match.entity_type

      # determine batch to process. Whether or not an operation can be batched is defined
      # by the Base#batch_size method. If that signals batch processing by returning a
      # number > 0, then the passed in batch_size provides an additional upper limit.
      batch_size = calculate_batch_size(op: op, entity_type: entity_type, max_batch_size: batch_size)
      return [ first_match ] if batch_size <= 1

      batch_relation = relation.where(entity_type: entity_type, op: op)
      select_and_lock(batch_relation, limit: batch_size)
    end
  end
end
