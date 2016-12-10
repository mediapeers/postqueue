module Postqueue
  MAX_ATTEMPTS = 5

  class Base

    # Processes many entries
    #
    # process batch_size: 100
    def process(entity_type:nil, op:nil, batch_size:100, &block)
      status, result = item_class.transaction do
        process_inside_transaction(entity_type: entity_type, op: op, batch_size: batch_size, &block)
      end

      raise result if status == :err
      result
    end

    def process_one(entity_type:nil, op:nil, &block)
      process(entity_type: entity_type, op: op, batch_size: 1, &block)
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
      items = item_class.find_by_sql(sql)

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
    def process_inside_transaction(entity_type:, op:, batch_size:, &block)
      relation = item_class.all
      relation = relation.where(entity_type: entity_type) if entity_type
      relation = relation.where(op: op) if op

      first_match = select_and_lock(relation, limit: 1).first
      return [ :ok, nil ] unless first_match
      op, entity_type = first_match.op, first_match.entity_type

      # determine batch to process. Whether or not an operation can be batched is defined
      # by the Base#batch_size method. If that signals batch processing by returning a
      # number > 0, then the passed in batch_size provides an additional upper limit.
      batch_size = calculate_batch_size(op: op, entity_type: entity_type, batch_size: batch_size)
      if batch_size > 1
        batch_relation = relation.where(entity_type: entity_type, op: op)
        batch = select_and_lock(batch_relation, limit: batch_size)
      else
        batch = [ first_match ]
      end

      entity_ids = batch.map(&:entity_id)

      # If the current operation is idempotent we will mark additional queue items as
      # in process.
      if idempotent?(op: op, entity_type: entity_type)
        entity_ids.uniq!
        process_relations   = relation.where(entity_type: entity_type, op: op, entity_id: entity_ids)
        items_in_processing = select_and_lock(process_relations, limit: nil)
      else
        items_in_processing = batch
      end

      items_in_processing_ids = items_in_processing.map(&:id)

      queue_times = item_class.find_by_sql <<-SQL
        SELECT extract('epoch' from AVG(now() - created_at)) AS avg, 
               extract('epoch' from MAX(now() - created_at)) AS max
        FROM #{item_class.table_name} WHERE entity_id IN (#{entity_ids.join(",")})
      SQL
      queue_time = queue_times.first
      
      # run callback.
      result = [ op, entity_type, entity_ids ]

      processing_time = Benchmark.realtime do
        result = yield *result if block_given?
      end

      # Depending on the result either reprocess or delete all items
      if result == false
        postpone items_in_processing_ids
      else
        on_processing(op, entity_type, entity_ids, processing_time, queue_time)
        item_class.where(id: items_in_processing_ids).delete_all 
      end

      [ :ok, result ]
    rescue => e
      on_exception(e, op, entity_type, entity_ids)
      postpone items_in_processing_ids
      [ :err, e ]
    end

    def postpone(ids)
      item_class.connection.exec_query <<-SQL
        UPDATE #{item_class.table_name} 
          SET failed_attempts = failed_attempts+1, 
              next_run_at = next_run_at + power(failed_attempts + 1, 1.5) * interval '10 second' 
          WHERE id IN (#{ids.join(",")})
      SQL
    end
  end
end
