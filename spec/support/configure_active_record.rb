require_relative "./connect_active_record"

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
