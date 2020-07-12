# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Quit
      include Cinch::Plugin

      EXPRESSIONS = [
        "be gone",
        "go home",
        "quit",
      ].freeze

      match(/(#{EXPRESSIONS.join('|')})/i, use_prefix: true)

      def execute(*)
        bot.quit('Ladybot version ' + Ladybot::VERSION)
      end
    end
  end
end
