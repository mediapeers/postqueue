require "active_record"
abcd = YAML.load_file("config/database.yml")
ActiveRecord::Base.establish_connection(abcd.fetch("test"))

Postqueue.unmigrate!
Postqueue.migrate!

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
