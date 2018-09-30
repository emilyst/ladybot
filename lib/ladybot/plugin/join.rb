# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Join
      include Cinch::Plugin

      # force match to begin with bot's nick, e.g., "ladybot: part"
      set :prefix, lambda { |m| Regexp.new('^' + Regexp.escape(m.bot.nick) + '[,:]?\s+') }

      match(/join\s+([&#+!][\S]{1,50})/i)

      def execute(message, channel)
        bot.join(channel)
      end
    end
  end
end
