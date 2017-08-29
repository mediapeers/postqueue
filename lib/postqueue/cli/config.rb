module Postqueue::CLI
  private

  def connect_to_app!
    connect_to_database!
    load "config/environment.rb"
    Postqueue.logger.info "Loaded #{Dir.getwd}/config/environment.rb"
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
