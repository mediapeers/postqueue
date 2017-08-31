# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Metrics/CyclomaticComplexity

# This file defines basic module for command lines.

require "shellwords"

module Postqueue::CLI
  extend self

  def run!(*args)
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

  def extract_options!(args)
    options = {}

    args.reject! do |arg|
      case arg
      when /\A--?([a-z_]+)=(.*)/  then options[$1.tr("-", "_").to_sym] = $2
      when /\A--no-?([a-z_]+)/    then options[$1.tr("-", "_").to_sym] = false
      when /\A--?([a-z_]+)/       then options[$1.tr("-", "_").to_sym] = true
      end
    end

    options
  end

  def keyword_parameters?(command)
    parameters = method(command).parameters
    parameters.any? { |mode, _name| mode == :key || mode == :keyreq }
  end

  def __run!(command, *args)
    command = command.tr(":", "_")
    help! unless commands.include?(command)

    if keyword_parameters?(command)
      options = extract_options!(args)
      args << options
    end

    method = public_instance_method(command)
    if method.arity > 0 && args.count != method.arity
      STDERR.puts "Invalid number of arguments (#{args.count}) for '#{command}', expect #{method.arity}"
      help! command
    elsif method.arity < 0 && args.count < -method.arity - 1
      STDERR.puts "Invalid number of arguments (#{args.count}) for '#{command}', expect at least #{-method.arity - 1}"
      help! command
    end

    send command, *args
  rescue ArgumentError
    if $!.to_s =~ /missing keyword: (\S+)/
      raise "Missing option: --#{$1}"
    elsif $!.to_s =~ /unknown keyword: (\S+)/
      raise "Unknown option: --#{$1}"
    else
      raise
    end
  end

  def commands
    public_instance_methods(false).map(&:to_s).grep(/\A[a-z_]*\z/).sort
  end

  def help!(specific_command = nil)
    command_name = File.basename($0)

    STDERR.puts "Usage:\n\n"
    commands.each do |subcommand|
      next if specific_command && subcommand != specific_command
      parameters = method(subcommand).parameters
      args = []
      opts = []

      parameters.each do |mode, name|
        case mode
        when :req then args << name
        when :opt then args << "[ #{name.to_s.upcase} ]"
        when :key then opts << "--#{name}"
        when :keyreq then opts << "--#{name}"
        end
      end

      msg = "#{command_name} #{subcommand.tr('_', ':')} #{args.join(" ")}"
      if opts.empty?
        STDERR.puts "    #{"%-30s" % msg}"
      else
        STDERR.puts "    #{"%-30s" % msg}      (#{opts.join(", ")})"
      end
    end
    STDERR.puts "\n"
    exit 1
  end
end
