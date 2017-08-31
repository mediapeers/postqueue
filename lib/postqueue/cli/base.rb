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
      parameters = method(subcommand).parameters.each_with_object({}) do |(mode, name), hsh|
        hsh[mode] ||= []
        hsh[mode] << name
      end

      parameters.default = []

      # req     #required argument
      # opt     #optional argument
      # rest    #rest of arguments as array
      # keyreq  #reguired key argument (2.1+)
      # key     #key argument
      # keyrest #rest of key arguments as Hash
      # block   #block parameter

      req     = parameters[:req].map { |name| "<#{name}>" }.join(" ")
      opt     = parameters[:opt].map { |name| "[ <#{name}> ]" }.join(" ")
      rest    = parameters[:rest].map { |name| "[ <#{name.to_s.singularize}> .. ]" }.join(" ")
      keyreq  = parameters[:keyreq].map { |name| "--#{name}=<#{name}>" }.join(" ")
      key     = parameters[:key].map { |name| "--#{name}=<#{name}>" }.join(" ")

      msg = "    #{command_name} #{subcommand.tr('_', ':')}"
      msg += " #{keyreq}" unless keyreq.empty?
      msg += " [ #{key} ]" unless key.empty?
      msg += " #{req}" unless req.empty?
      msg += " #{opt}" unless opt.empty?
      msg += " #{rest}" unless rest.empty?

      STDERR.puts msg
    end
    STDERR.puts "\n"
    exit 1
  end
end
