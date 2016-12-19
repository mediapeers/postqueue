require "ostruct"

require_relative "cli/options_parser"

module Postqueue
  module CLI
    extend self

    attr_reader :options

    def run(argv)
      @options = OptionsParser.parse_args(argv)

      case options.sub_command
      when "stats"
        require "table_print"

        connect_to_database!
        sql = <<-SQL
        SELECT op,
          COUNT(*) AS count,
          MIN(now() - created_at) AS min_age,
          MAX(now() - created_at) AS max_age,
          AVG(now() - created_at) AS avg_age
        FROM #{Postqueue.item_class.table_name} GROUP BY op
        SQL

        recs = Postqueue.item_class.find_by_sql(sql)
        recs = recs.map do |rec|
          {
            op: rec.op,
            count: rec.count,
            min_age: rec.min_age,
            max_age: rec.max_age,
            avg_age: rec.avg_age
          }
        end
        tp recs
      when "peek"
        require "table_print"

        connect_to_database!
        sql = "SELECT * FROM #{Postqueue.item_class.table_name} LIMIT 100"
        tp Postqueue.default_queue.upcoming(subselect: false).limit(100).all
      when "enqueue"
        connect_to_database!
        count = Postqueue.enqueue op: options.op, entity_id: options.entity_ids
        Postqueue.logger.info "Enqueued #{count} queue items"
      when "process"
        connect_to_instance!
        Postqueue.process batch_size: 1
      when "run"
        connect_to_instance!
        Postqueue.run!
      end
    end

    def connect_to_instance!
      path = "#{Dir.getwd}/config/postqueue.rb"
      Postqueue.logger.info "Loading postqueue configuration from #{path}"
      load path
    end

    def connect_to_database!
      abc = active_record_config
      username, host, database = abc.values_at "username", "host", "database"
      Postqueue.logger.info "Connecting to postgres:#{username}@#{host}/#{database}"

      ActiveRecord::Base.establish_connection(abc)
    end

    def active_record_config
      require "yaml"
      database_config = YAML.load_file "config/database.yml"
      env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
      database_config.fetch(env)
    end
  end
end
