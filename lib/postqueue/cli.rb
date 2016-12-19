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
        connect_to_database!
        sql = "SELECT * FROM #{Postqueue.item_class.table_name}"
        tp Postqueue.item_class.find_by_sql(sql)
      when "enqueue"
        connect_to_database!
        count = Postqueue.enqueue op: options.op, entity_id: options.entity_ids
        puts "returned #{count.inspect}"
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
