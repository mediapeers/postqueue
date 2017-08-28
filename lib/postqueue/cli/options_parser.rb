require "ostruct"

module Postqueue
  module CLI
    class OptionsParser
      SUB_COMMANDS = %w(stats peek enqueue run process migrate)

      def self.parse_args(argv)
        new(argv).parse_args
      end

      attr_reader :argv

      def initialize(argv)
        @argv = argv
      end

      def parse_args
        require "optparse"
        options = OpenStruct.new(table_name: "postqueue")

        read_global_options!(options)
        options.sub_command = argv.shift || "stats"

        unless SUB_COMMANDS.include?(options.sub_command)
          STDERR.puts "Unknown sub_command #{options.sub_command.inspect}\n\n"
          usage!
        end

        case options.sub_command
        when "enqueue"
          options.op = next_arg!
          options.entity_ids = next_arg!.split(",").map { |s| Integer(s) }
        when "migrate"
          options.policy = next_arg
        end
        options
      end

      private

      def read_global_options!(options)
        while argv.first && argv.first[0,1] == "-" do
          case next_arg
          when "-t" then options.table_name = next_arg!
          else      usage!
          end
        end
      end

      def next_arg
        argv.shift
      end

      def next_arg!
        argv.shift || usage!
      end

      def usage
        STDERR.puts <<-USAGE
This is postqueue #{Postqueue::VERSION}. Usage examples:

  postqueue [ options ] [ stats ]
  postqueue [ options ] peek
  postqueue [ options ] enqueue op entity_id,entity_id,entity_id
  postqueue [ options ] run
  postqueue [ options ] help
  postqueue [ options ] process
  postqueue [ options ] migrate [ policy ]

where options are

  -t tablename  .. name of database table

USAGE
      end

      def usage!
        usage
        exit 1
      end
    end
  end
end
