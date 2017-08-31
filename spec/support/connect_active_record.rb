require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql",
                                        database: "postqueue_test")
