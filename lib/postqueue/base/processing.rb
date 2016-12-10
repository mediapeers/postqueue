module Postqueue
  MAX_ATTEMPTS = 3

  class Base

    # Processes many entries
    #
    # process batch_size: 100
    def process(options = {}, &block)
      batch_size        = options.fetch(:batch_size, 100)
      options.delete :batch_size

      status, result = Item.transaction do
        process_inside_transaction options, batch_size: batch_size, &block
      end

      raise result if status == :err
      result
    end

    def process_one(options = {}, &block)
      process(options.merge(batch_size: 1), &block)
    end

    def idempotent?(entity_type:, op:)
      false
    end

    def batch_size(entity_type:, op:)
      10
    end

    private

    # Select and lock up to \a limit unlocked items in the queue.
    def select_and_lock(relation, limit:)
      relation = relation.where("failed_attempts < ? AND next_run_at < ?", MAX_ATTEMPTS, Time.now).order(:next_run_at, :id)

      sql = relation.to_sql + " FOR UPDATE SKIP LOCKED"
      sql += " LIMIT #{limit}" if limit
      items = Item.find_by_sql(sql)

      items
    end

    def calculate_batch_size(op:, entity_type:, batch_size:)
      processor_batch_size = self.batch_size(op: op, entity_type: entity_type)
      if !processor_batch_size || processor_batch_size < 2
        1
      elsif(!batch_size)
        processor_batch_size
      else
        [ processor_batch_size, batch_size ].min
      end
    end

    # The actual processing. Returns [ :ok, number-of-items ] or  [ :err, exception ]
    def process_inside_transaction(options, batch_size: nil, &block)
      relation = item_class.all
      relation = relation.where(options[:where]) if options[:where]

      first_match = select_and_lock(relation, limit: 1).first
      return [ :ok, nil ] unless first_match

      # determine batch to process. Whether or not an operation can be batched is defined
      # by the Base#batch_size method. If that signals batch processing by returning a
      # number > 0, then the passed in batch_size provides an additional upper limit.
      batch_size = calculate_batch_size(op: first_match.op, entity_type: first_match.entity_type, batch_size: batch_size)
      if batch_size > 1
        batch_relation = relation.where(entity_type: first_match.entity_type, op: first_match.op)
        batch = select_and_lock(batch_relation, limit: batch_size)
      else
        batch = [ first_match ]
      end

      batch_ids = batch.map(&:entity_id)

      # If the current operation is idempotent we will mark additional queue items as
      # in process.
      if idempotent?(op: first_match.op, entity_type: first_match.entity_type)
        batch_ids.uniq!
        process_relations   = relation.where(entity_type: first_match.entity_type, op: first_match.op, entity_id: batch_ids)
        items_in_processing = select_and_lock(process_relations, limit: nil)
      else
        items_in_processing = batch
      end

      # run callback.
      result = [ first_match.op, first_match.entity_type, batch_ids ]
      result = yield *result if block_given?

      # Depending on the result either reprocess or delete all items
      if result == false
        postpone items_in_processing
      else
        Item.where(id: items_in_processing.map(&:id)).delete_all 
      end

      [ :ok, result ]
    rescue => e
      puts e
      postpone items_in_processing
      [ :err, e ]
    end

    def postpone(items)
      ids = items.map(&:id)
      sql = "UPDATE postqueue SET failed_attempts = failed_attempts+1, next_run_at = next_run_at + interval '10 second' WHERE id IN (#{ids.join(",")})"
      Item.connection.exec_query(sql)
    end
  end
end
