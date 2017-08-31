module Postqueue
  class MissingHandler < RuntimeError
    attr_reader :op, :entity_ids

    def initialize(op:, entity_ids:)
      @op = op
      @entity_ids = entity_ids
    end

    def to_s
      "Unknown operation #{op.inspect} with #{entity_ids.count} entities"
    end
  end

  module ExceptionHandling
    def on_exception(&block)
      raise ArgumentError, "on_exception expects a block argument" unless block
      raise ArgumentError, "on_exception expects a block accepting 3 or more arguments" if block.arity > -3 && block.arity != 3

      @on_exception = block
      self
    end
  end

  extend ExceptionHandling
end
