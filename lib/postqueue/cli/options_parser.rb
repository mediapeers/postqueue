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
        options = OpenStruct.new
        options.sub_command = argv.shift || "stats"

        usage! unless SUB_COMMANDS.include?(options.sub_command)

        case options.sub_command
        when "enqueue"
          options.op = next_arg!
          options.entity_ids = next_arg!.split(",").map { |s| Integer(s) }
        end
        options
      end

      private

      def next_arg!
        argv.shift || usage!
      end

      def usage
        STDERR.puts <<-USAGE
This is postqueue #{Postqueue::VERSION}. Usage examples:

  postqueue [ stats ]
  postqueue peek
  postqueue enqueue op entity_id,entity_id,entity_id
  postqueue run
  postqueue help
  postqueue process
  postqueue migrate

USAGE
      end

      def usage!
        usage
        exit 1
      end
    end
  end
end
