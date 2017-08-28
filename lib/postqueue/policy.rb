module Postqueue
  module Policy
    def self.by_name(name)
      module_name = name.camelize
      const_get module_name
    end
  end
end

require_relative "policy/multi_ops"
