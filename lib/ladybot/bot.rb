# frozen_string_literal: true

require 'cinch'
require 'optparse'

module Ladybot
  class Bot
    attr_reader :bot
    def initialize
      options = parse(ARGV)
      @bot = cinch_bot(options[:server],
                       options[:port],
                       options[:ssl],
                       options[:nick],
                       options[:user],
                       options[:channels])
    end

    def parse(args)
      options = {}

      parser = OptionParser.new do |p|
        p.banner = 'Usage: ladybot [options]'
        p.separator ''
        p.separator 'Options:'

        p.on('-sSERVER', '--server=SERVER', 'Host to connect to') do |o|
          options[:server] = o
        end

        p.on('-pPORT', '--port=PORT', Integer, 'Server port to use') do |o|
          options[:port] = o
        end

        p.on('-S', '--[no-]ssl', FalseClass, 'Use SSL') do |o|
          options[:ssl] = o
        end

        p.on('-nNICK', '--nick=NICK', 'Nick for the bot') do |o|
          options[:nick] = o
        end

        p.on('-nUSER', '--user=USER', 'Username for the bot') do |o|
          options[:user] = o
        end

        p.on('-cCHANNEL', '--channel=CHANNEL', 'Channel to join (use more than once if needed)') do |o|
          options[:channels] = [] if options[:channels].nil?
          options[:channels] << o
        end

        p.on_tail('-h', '--help', 'Show this message') do
          puts p
          exit
        end

        p.parse!(args)
      end

      parser.parse!

      if options[:server].nil?
        puts 'Require a server to which to connect!'
        puts p
        exit false
      end
      options[:port]     = 6667      if options[:port].nil?
      options[:ssl]      = false     if options[:ssl].nil?
      options[:nick]     = 'ladybot' if options[:nick].nil?
      options[:user]     = 'ladybot' if options[:user].nil?
      options[:channels] = []        if options[:channels].nil?

      options
    end

    def discover_plugins
      Ladybot::Plugin.constants
                     .map { |c| Ladybot::Plugin.const_get(c) }
                     .select { |c| c.included_modules.include?(Cinch::Plugin) }
    end

    def cinch_bot(server   = '',
                  port     = 6667,
                  ssl      = false,
                  nick     = 'ladybot',
                  user     = 'ladybot',
                  channels = [])
      plugins = discover_plugins

      Cinch::Bot.new do
        configure do |c|
          c.server          = server
          c.nick            = nick
          c.user            = user
          c.channels        = channels
          c.plugins.plugins = plugins
        end
      end
    end

    def start!
      @bot.start
    end
  end
end
