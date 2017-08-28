module Postqueue
  module Policy
    extend self

    def determine(table_name: table_name)
      "multi_ops"
    end

    def by_name(name)
      module_name = name.camelize
      const_get module_name
    rescue NameError
      raise ArgumentError, "No such postqueue policy: #{name.inspect}"
    end
  end
end

require_relative "policy/multi_ops"
