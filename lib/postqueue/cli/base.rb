# This file defines basic module for command lines.

require "shellwords"

module Postqueue::CLI
  extend self

  def run!(*args)
    extract_options!(args)
    help! if args.empty?
    __run!(*args)
  rescue RuntimeError => e
    msg = e.to_s
    msg += " (#{e.class.name})" unless $!.class.name == "RuntimeError"
    STDERR.puts msg
    raise unless %w(RuntimeError Expectation::Matcher::Mismatch).include? $!.class.name
    exit 2
  end

  private

  attr_reader :options

  def extract_options!(args)
    @options = OpenStruct.new

    args.reject! do |arg|
      case arg
      when /\A--?([a-z_]+)=(.*)/  then @options[Regexp.last_match(1).to_sym] = Regexp.last_match(2)
      when /\A--?([a-z_]+)/       then @options[Regexp.last_match(1).to_sym] = true
      end
    end
  end

  def __run!(command, *args)
    command = command.tr(":", "_")
    help! unless commands.include?(command)
    send command, *args
  end

  def commands
    public_instance_methods(false).map(&:to_s).grep(/\A[a-z_]*\z/).sort
  end

  def help!
    command_name = File.basename($0)

    STDERR.puts "Usage:\n\n"
    commands.each do |command|
      parameters = method(command).parameters
      args = parameters.map do |mode, name|
        name = name.to_s.upcase
        mode != :req ? "[ #{name} ]" : name
      end

      STDERR.puts "    #{command_name} #{command.tr('_', ':')} #{args.join(" ")}"
    end
    STDERR.puts "\n"
    exit 1
  end

  def sys(cmd, *args)
    System.run(cmd, *args)
  end

  def sys!(cmd, *args)
    System.run!(cmd, *args)
  end

  class System
    def self.run(cmd, *args)
      command_line = new(cmd, *args)
      command_line.run
      $?.success?
    end

    def self.run!(cmd, *args)
      command_line = new(cmd, *args)
      command_line.run
      raise "failed with #{$?.exitstatus}: #{command_line}" unless $?.success?
    end

    def initialize(*args)
      @args = args
    end

    def run
      UI.info to_s
      if @args.length > 1
        system(to_s)
      else
        system(*@args)
      end
    end

    def to_s
      escaped_args = @args.map do |arg|
        escaped = Shellwords.escape(arg)
        next arg if escaped == arg
        next escaped if arg.include?("'")
        "'#{arg}'"
      end
      escaped_args.join(" ")
    end
  end
end
