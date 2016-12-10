require "active_record"
require_relative "./models"

$LOAD_PATH << File.dirname(__FILE__)

ActiveRecord::Base.establish_connection(adapter: "postgresql",
                                        database: "postqueue_test",
                                        username: "postqueue",
                                        password: "postqueue")

require_relative "schema.rb"
require_relative "models.rb"

Postqueue.unmigrate!
Postqueue.migrate!

RSpec.configure do |config|
  config.around(:each) do |example|
    ActiveRecord::Base.connection.transaction do
      example.run
      raise ActiveRecord::Rollback, "Clean up"
    end
  end
end
