module Postqueue
  MAX_ATTEMPTS = 5

  class Base
    # Processes many entries
    #
    # process batch_size: 100
    def process(op: nil, batch_size: 100, &block)
      status, result = item_class.transaction do
        process_inside_transaction(op: op, batch_size: batch_size, &block)
      end

      raise result if status == :err
      result
    end

    def process_one(op: nil, &block)
      process(op: op, batch_size: 1, &block)
    end

    private

    # The actual processing. Returns [ :ok, number-of-items ] or  [ :err, exception ]
    def process_inside_transaction(op:, batch_size:, &block)
      batch = select_and_lock_batch(op: op, batch_size: batch_size)

      match = batch.first
      return [ :ok, nil ] unless match

      entity_ids = batch.map(&:entity_id)
      result, timing = run_callback(op: match.op, entity_ids: entity_ids, &block)

      # Depending on the result either reprocess or delete all items
      if result == false
        postpone batch.map(&:id)
      else
        on_processing(match.op, entity_ids, timing)
        item_class.where(id: batch.map(&:id)).delete_all
      end

      [ :ok, result ]
    rescue => e
      on_exception(e, match.op, entity_ids)
      postpone batch.map(&:id)
      [ :err, e ]
    end

    def postpone(ids)
      item_class.connection.exec_query <<-SQL
        UPDATE #{item_class.table_name}
          SET failed_attempts = failed_attempts+1,
              next_run_at = next_run_at + power(failed_attempts + 1, 1.5) * interval '10 second'
          WHERE id IN (#{ids.join(',')})
      SQL
    end
  end
end
