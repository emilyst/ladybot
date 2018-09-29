require 'cinch'

module Ladybot
  module Plugin
    class Sync
      include Cinch::Plugin

      match /^sync/, use_prefix: false, method: :sync

      def sync(message, *args)
        message.reply <<~ANNOUNCE
          #{message.user.nick} has started a sync! Type 'rdy' to join the sync! I will notify
          you when the sync begins. If no one else joins the sync in five minutes,
          the sync will expire.
        ANNOUNCE
      end
    end
  end
end
