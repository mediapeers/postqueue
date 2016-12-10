module Postqueue
  class Base
    private

    def item_class
      Postqueue::Item
    end
  end

  def self.new
    Base.new
  end
end

require 'postqueue/base/enqueue'
require 'postqueue/base/processing'
