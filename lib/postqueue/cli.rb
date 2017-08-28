require "ostruct"

require_relative "cli/options_parser"
require_relative "cli/stats"

module Postqueue
  module CLI
    extend self

    attr_reader :options

    def run(argv)
      @options = OptionsParser.parse_args(argv)

      connect_to_database!

      case options.sub_command
      when "migrate"  then Postqueue.migrate! table_name: options.table_name, policy: options.policy
      when "stats"    then Stats.stats table_name: options.table_name
      when "peek"     then Stats.peek table_name: options.table_name
      when "enqueue"
        queue = Postqueue.new table_name: options.table_name
        count = queue.enqueue op: options.op, entity_id: options.entity_ids
        Postqueue.logger.info "Enqueued #{count} queue items"
      when "process"
        connect_to_app!
        Postqueue.process! table_name: options.table_name, batch_size: 1
      when "run"
        connect_to_app!
        Postqueue.run! table_name: options.table_name
      # when "reprocess"
      #   connect_to_app!
      #   Postqueue.process batch_size: 1
      end
    end

    private

    def connect_to_app!
      load "config/environment.rb"
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
