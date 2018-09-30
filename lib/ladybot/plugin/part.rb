# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Part
      include Cinch::Plugin

      EXPRESSIONS = ["part",
                     "depart"].freeze

      # force match to begin with bot's nick, e.g., "ladybot: part"
      set :prefix, lambda { |m| Regexp.new('^' + Regexp.escape(m.bot.nick) + '[,:]?\s+') }

      match(/(#{EXPRESSIONS.join('|')})/i)

      def execute(message, *args)
        bot.part(message.channel.name, 'Ladybot version ' + Ladybot::VERSION)
      end
    end
  end
end
