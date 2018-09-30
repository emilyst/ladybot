# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Quit
      include Cinch::Plugin

      EXPRESSIONS = ["be gone",
                     "go home",
                     "quit"].freeze

      # force match to begin with bot's nick, e.g., "ladybot: leave"
      set :prefix, lambda { |m| Regexp.new('^' + Regexp.escape(m.bot.nick) + '[,:]?\s+') }

      match(/(#{EXPRESSIONS.join('|')})/i)

      def execute(message, *args)
        bot.quit('Ladybot version ' + Ladybot::VERSION)
      end
    end
  end
end
