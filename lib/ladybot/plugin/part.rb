# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Part
      include Cinch::Plugin

      EXPRESSIONS = [
        "depart",
        "leave",
        "part",
      ].freeze

      match(/(#{EXPRESSIONS.join('|')})/i)

      def execute(message, *args)
        bot.part(message.channel.name, 'Ladybot version ' + Ladybot::VERSION)
      end
    end
  end
end
