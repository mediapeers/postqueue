module Postqueue
  # The Postqueue processor processes items in a single Postqueue table.
  class Queue
    # Processes up to batch_size entries
    #
    # process batch_size: 100
    def process(op: nil, batch_size: nil)
      item_class.transaction do
        process_inside_transaction(op: op, batch_size: batch_size)
      end
    end

    # processes a single entry
    def process_one(op: nil)
      process(op: op, batch_size: 1)
    end

    def process_until_empty(op: nil, batch_size: nil)
      count = 0
      loop do
        processed_items = process(op: op, batch_size: batch_size)
        break if processed_items == 0

        count += processed_items
      end
      count
    end

    private

    # The actual processing. Returns [ op, [ ids-of-processed-items ] ] or nil
    # rubocop:disable Style/RescueStandardError
    def process_inside_transaction(op:, batch_size:)
      items = select_and_lock_batch(op: op, max_batch_size: batch_size)
      match = items.first
      return 0 unless match

      entity_ids = items.map(&:entity_id)
      timing = run_callback(op: match.op, entity_ids: entity_ids)

      after_processing.call(match.op, entity_ids, timing)
      item_class.where(id: items.map(&:id)).delete_all

      # even though we try not to enqueue duplicates we cannot guarantee that,
      # since concurrent enqueue transactions might still insert duplicates.
      # That's why we explicitely remove all non-failed duplicates here.
      if idempotent_operation?(match.op)
        duplicates = select_and_lock_duplicates(op: match.op, entity_ids: entity_ids)
        item_class.where(id: duplicates.map(&:id)).delete_all unless duplicates.empty?
      end

      entity_ids.length
    rescue => e
      item_class.postpone items.map(&:id)
      log_exception(e, match.op, entity_ids)
      on_exception.call(e, match.op, entity_ids)
      0
    end
    # rubocop:enable Style/RescueStandardError
  end
end
