# rubocop:disable Metrics/CyclomaticComplexity

module Postqueue
  class Queue
    def enqueue(op:, entity_id:, channel: nil)
      check_channel_support!(channel)

      # enqueue items. If the operation is idempotent, we can ignore any operation
      # that is already queued, since in that case the new operation's effect will
      # only replicate what the already queued operation is doing, without any
      # discernible effect.
      enqueued_item_count = item_class.enqueue op: op, entity_id: entity_id, channel: channel,
                                               ignore_if_exists: Postqueue.callback(op: op)&.idempotent?
      return 0 if enqueued_item_count == 0

      if channel.nil?
        subscriptions(op: op).each do |subscription|
          item_class.enqueue op: op, entity_id: entity_id, channel: subscription, ignore_if_exists: false
        end
      end

      case processing
      when :async
        ::Postqueue::Availability.notify
      when :sync
        process_until_empty(channel: channel)
      when :verify
        raise(MissingHandler, op: op, entity_ids: [entity_id]) unless Postqueue.callback(op: op)
      end

      enqueued_item_count
    end
  end
end
