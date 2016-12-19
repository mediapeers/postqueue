require "forwardable"

module Postqueue
  module DefaultQueue
    def default_queue
      @default_queue ||= new
    end
  end

  extend DefaultQueue

  extend SingleForwardable

  def_delegators :default_queue, :enqueue
  def_delegators :default_queue, :item_class, :batch_sizes, :on
  def_delegators :default_queue, :process, :process_one
  def_delegators :default_queue, :processing
  def_delegators :default_queue, :run, :run!
end
