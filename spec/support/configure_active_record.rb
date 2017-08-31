# --- connect to database -----------------------------------------------------

def connect_to_database!
  require "yaml"
  database_config = YAML.load_file "config/database.yml"
  env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "test"
  abc = database_config.fetch(env)
  username, host, database = abc.values_at "username", "host", "database"
  Postqueue.logger.info "Connecting to postgres:#{username}@#{host}/#{database}"

  ActiveRecord::Base.establish_connection(abc)
end

connect_to_database!

# --- run migrations ----------------------------------------------------------

Postqueue.unmigrate!
Postqueue.migrate!

# --- configure RSpec ---------------------------------------------------------

RSpec.configure do |config|
  config.around(:each) do |example|
    if example.metadata[:transactions] == false
      example.run
    else
      ActiveRecord::Base.connection.transaction do
        example.run
        raise ActiveRecord::Rollback, "Clean up"
      end
    end
  end
end
