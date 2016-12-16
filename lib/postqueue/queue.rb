module Postqueue
  class Queue
    # The AR::Base class to use. You would only change this if you want to run
    # the queue in a different database or in a different table.
    attr_accessor :item_class

    # The default batch size. Will be used if no specific batch size is defined
    # for an operation.
    attr_accessor :default_batch_size

    # batch size for a given op
    attr_reader :batch_sizes

    # maximum number of processing attempts.
    attr_reader :max_attemps

    def initialize(&block)
      @batch_sizes = {}
      @item_class = ::Postqueue::Item
      @default_batch_size = 1
      @max_attemps = 5

      yield self if block
    end

    def batch_size(op:)
      batch_sizes[op] || default_batch_size || 1
    end

    def _skip_duplicates
      @_skip_duplicates ||= {}
    end

    def ignore_duplicates?(op)
      _skip_duplicates[op] || _skip_duplicates['*'] || false
    end

    def skip_duplicates(op, flag = true)
      _skip_duplicates[op] = flag
    end

    def enqueue(op:, entity_id:)
      item_class.enqueue op: op, entity_id: entity_id, ignore_duplicates: ignore_duplicates?(op)
    end
  end
end

require_relative "queue/select_and_lock"
require_relative "queue/processing"
require_relative "queue/callback"
require_relative "queue/logging"
