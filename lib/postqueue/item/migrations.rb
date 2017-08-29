module Postqueue
  class Item < ActiveRecord::Base
    module Migrations
      include Postqueue::Migrations

      extend self

      def migrate!(table_name)
        create_postqueue_table! table_name
        change_postqueue_id_type! table_name
        add_postqueue_queue_column! table_name
      end

      def unmigrate!(table_name)
        connection.execute <<-SQL
          DROP TABLE IF EXISTS #{connection.quote_table_name table_name};
        SQL
      end
    end
  end
end
