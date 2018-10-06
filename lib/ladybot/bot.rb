# frozen_string_literal: true

require 'cinch'
require 'optparse'

module Ladybot
  class Bot
    attr_reader :bot

    def initialize(args = ARGV)
      @bot = cinch_bot(parse(args))
    end

    def parse(args)
      options = {}

      parser = OptionParser.new do |p|
        p.banner = <<~BANNER
          Ladybot version #{Ladybot::VERSION}

          Usage: ladybot --server <hostname> [options]
        BANNER

        p.separator ''
        p.separator 'Options:'

        p.on('-sSERVER', '--server=SERVER', 'Host to connect to (required)') do |o|
          options[:server] = o
        end

        p.on('-pPORT', '--port=PORT', Integer, 'Server port to use') do |o|
          options[:port] = o
        end

        p.on('-S', '--[no-]ssl', TrueClass, 'Use SSL') do |o|
          options[:ssl] = o
        end

        p.on('-nNICK', '--nick=NICK', 'Nick for the bot') do |o|
          options[:nick] = o
        end

        p.on('-uUSER', '--user=USER', 'Username for the bot') do |o|
          options[:user] = o
        end

        p.on('-cCHANNEL', '--channel=CHANNEL', 'Channel to join (use more than once if needed)') do |o|
          options[:channels] = [] if options[:channels].nil?
          options[:channels] << o
        end

        p.on_tail('-v', '--version', 'Show version of Ladybot') do
          puts 'Ladybot version ' + Ladybot::VERSION
          exit
        end

        p.on_tail('-h', '--help', 'Show this message') do
          puts p
          exit
        end
      end

      parser.parse(args)

      if options[:server].nil?
        puts 'Require a server to which to connect!'
        puts parser
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

    def cinch_bot(options)
      plugins = discover_plugins

      Cinch::Bot.new do
        configure do |c|
          c.server          = options[:server]
          c.nick            = options[:nick]
          c.user            = options[:user]
          c.channels        = options[:channels]
          c.plugins.plugins = plugins

          # bot has to be addressed with its nick
          c.plugins.prefix  =
            Regexp.new('^' + Regexp.escape(options[:nick]) + '[,:]?\s+')
        end
      end
    end

    def start!
      @bot.start
    end
  end
end
