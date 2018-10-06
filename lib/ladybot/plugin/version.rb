# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Version
      include Cinch::Plugin

      match(/^version/i, use_prefix: false, react_on: :ctcp)

      def execute(message, *args)
        message.ctcp_reply 'Ladybot version ' + Ladybot::VERSION
      end
    end
  end
end
