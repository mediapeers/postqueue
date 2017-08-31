module Postqueue
  class Queue
    def subscriptions
      quoted_table_name = connection.quote_fq_identifier subscriptions_table_name

      result = connection.exec_query <<-SQL
        SELECT op, channel FROM #{quoted_table_name}
      SQL
      result.rows.map { |op, channel| { op: op, channel: channel } }
    end

    def subscribe(channel:, op:)
      raise ArgumentError, "channel argument must be a String" unless channel.is_a?(String)
      raise ArgumentError, "op argument must be a String" unless op.is_a?(String)

      ActiveRecord::Base.transaction do
        unsubscribe channel: channel, op: op

        quoted_table_name = connection.quote_fq_identifier subscriptions_table_name
        quoted_channel    = connection.quote channel
        quoted_op         = connection.quote op

        connection.execute <<-SQL
          INSERT INTO #{quoted_table_name} (channel, op)
            VALUES(#{quoted_channel}, #{quoted_op})
        SQL

        Postqueue.logger.info "Subscribed #{quoted_channel} on op #{quoted_op}"
      end
    end

    def unsubscribe(channel:, op: nil)
      raise ArgumentError, "channel argument must be a String" unless channel.is_a?(String)
      raise ArgumentError, "op argument must be a String" unless op.nil? || op.is_a?(String)

      quoted_table_name = connection.quote_fq_identifier subscriptions_table_name
      quoted_channel    = connection.quote channel
      quoted_op         = connection.quote op if op

      if op
        connection.execute "DELETE FROM #{quoted_table_name} WHERE channel=#{quoted_channel} AND op=#{quoted_op}"
        Postqueue.logger.info "Unsubscribed #{quoted_channel} from op #{quoted_op}"
      else
        connection.execute "DELETE FROM #{quoted_table_name} WHERE channel=#{quoted_channel}"
        Postqueue.logger.info "Unsubscribed #{quoted_channel} from all ops"
      end
    end

    private

    def subscriptions_table_name
      "#{item_class.table_name}_subscriptions"
    end
  end
end
