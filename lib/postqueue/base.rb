module Postqueue
  class Base
    class << self
      attr_accessor :item_class
    end

    self.item_class = Postqueue::Item
  end

  def self.new
    Base.new
  end
end

require 'postqueue/base/enqueue'
require 'postqueue/base/processing'
