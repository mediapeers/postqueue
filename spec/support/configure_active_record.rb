require_relative "./connect_active_record"

Postqueue.unmigrate!
Postqueue.migrate!

RSpec.configure do |config|
  config.around(:each) do |example|
    unless example.metadata[:transactions] == false
      ActiveRecord::Base.connection.transaction do
        example.run
        raise ActiveRecord::Rollback, "Clean up"
      end
    else
      example.run
    end
  end
end
