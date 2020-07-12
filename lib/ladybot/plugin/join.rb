# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Join
      include Cinch::Plugin

      match(/join\s+([&#+!][\S]{1,50})/i)

      def execute(_, channel)
        bot.join(channel)
      end
    end
  end
end
