# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Version
      include Cinch::Plugin

      match(/^version/i, use_prefix: false, method: :ctcp_version, react_on: :ctcp)
      match(/version/i,  use_prefix: true,  method: :message_version)

      def ctcp_version(message, *args)
        message.ctcp_reply 'Ladybot version ' + Ladybot::VERSION
      end

      def message_version(message, *args)
        message.reply 'Ladybot version ' + Ladybot::VERSION
      end
    end
  end
end
