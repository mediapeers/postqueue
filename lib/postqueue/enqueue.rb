module Postqueue
  module Enqueue
    Item = ::Postqueue::Item

    def enqueue(op:, entity_type:, entity_id:)
      # An optimized code path, as laid out below, is 4 times as fast.
      # However, exec_query changed from Rails 4 to Rails 5.

      # sql = "INSERT INTO postqueue (op, entity_type, entity_id) VALUES($1, $2, $3)"
      # binds = [ ]
      #
      # binds << ActiveRecord::Attribute.from_user("name", op,  ::ActiveRecord::Type::String.new)
      # binds << ActiveRecord::Attribute.from_user("entity_type", entity_type, ::ActiveRecord::Type::String.new)
      # binds << ActiveRecord::Attribute.from_user("entity_id", entity_id, ::ActiveRecord::Type::Integer.new)
      # # Note: Rails 4 does not understand prepare: true
      # db.exec_query(sql, 'SQL', binds, prepare: true)

      Item.create!(op: op, entity_type: entity_type, entity_id: entity_id)
    end
  end

  extend Enqueue
end
