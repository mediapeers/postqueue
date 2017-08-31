module Postqueue
  class Item < ActiveRecord::Base
    module Migrations
      include Postqueue::Migrations

      extend self

      def migrate!(table_name)
        create_schema! table_name
        create_postqueue_table! table_name
        change_postqueue_entity_id_type! table_name
        create_subscriptions_table! table_name
        change_postqueue_id_type! table_name
        add_postqueue_queue_column! table_name
      end

      def unmigrate!(table_name)
        connection.execute <<-SQL
          DROP TABLE IF EXISTS #{table_name};
          DROP TABLE IF EXISTS #{table_name}_subscriptions;
        SQL
      end
    end
  end
end
