require 'cinch'

module Ladybot
  class Bot
    def start!
      cinch_bot.start
    end

    def cinch_bot
      plugins = discover_plugins

      Cinch::Bot.new do
        configure do |c|
          c.server   = "irc.wtfux.org"
          c.nick     = 'ladybot'
          c.user     = 'ladybot'
          c.channels = [ '#wtfux' ]

          c.plugins.plugins = plugins
        end
      end
    end

    def discover_plugins
      Ladybot::Plugin.constants
                     .map { |c| Ladybot::Plugin.const_get(c) }
                     .select { |c| c.included_modules.include?(Cinch::Plugin) }
    end
  end
end
