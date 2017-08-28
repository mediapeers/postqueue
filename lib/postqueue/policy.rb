module Postqueue
  module Policy
    extend self

    def by_name(name)
      module_name = name.camelize
      const_get module_name
    rescue NameError
      raise ArgumentError, "No such postqueue policy: #{name.inspect}"
    end

    def detect(table_name:)
      policy = _detect(table_name: table_name)
      Postqueue.logger.info "[#{table_name}] using #{policy} policy"
      policy
    end

    private

    def _detect(table_name:)
      connection = ActiveRecord::Base.connection
      columns = connection.exec_query <<-SQL
        SELECT column_name FROM information_schema.columns
        WHERE table_name = #{connection.quote table_name};
      SQL
      column_names = columns.map(&:first).map(&:last)
      return "multi_ops" if (MultiOps::QUEUE_ATTRIBUTES.map(&:to_s) - column_names).empty?

      if column_names.empty?
        raise "Cannot detect policy for table #{table_name.inspect} (no such table)"
      else
        raise "Cannot detect policy for table #{table_name.inspect} w/columns #{column_names}"
      end
    end
  end
end

require_relative "policy/multi_ops"
