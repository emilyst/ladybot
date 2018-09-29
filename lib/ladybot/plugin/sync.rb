require 'cinch'

module Ladybot
  module Plugin
    class Sync
      include Cinch::Plugin

      attr_reader :ongoing_syncs

      OngoingSync = Struct.new(:syncers)

      def initialize(bot)
        super(bot)
        @ongoing_syncs = {}
      end

      match /^sync/, use_prefix: false, method: :sync
      match /^rdy/,  use_prefix: false, method: :rdy
      match /^go/,   use_prefix: false, method: :go

      def sync(message, *args)
        synchronize(message.channel) do
          if !@ongoing_syncs.has_key?(message.channel)
            @ongoing_syncs[message.channel] = OngoingSync.new([message.user.nick])

            Timer(5 * 60, shots: 1) { rip(message.channel) }

            reply = "#{message.user.nick} has started a sync! Type "\
                    '"rdy" to join the sync! I will notify '\
                    'everyone in the sync when it begins. The sync '\
                    'will begin automatically in five minutes. To '\
                    'kick it off yourself, type "sync" again or '\
                    '"go" when you\'re ready.'

            message.reply reply
          else
            # if a sync is already going, just kick that one off (in an
            # instant, throwaway timer we can use like a callback so
            # that it fires outside of this thread and we can release
            # the mutex for now)
            Timer(0, shots: 1) { go(message, *args) }
          end
        end
      end

      def rdy(message, *args)
        reply = synchronize(message.channel) do
          if !@ongoing_syncs.has_key?(message.channel)
            "Sorry, #{message.user.nick}, there's no sync going. Type "\
            '"sync" to start one off!'
          elsif @ongoing_syncs[message.channel].syncers.include?(message.user.nick)
            "Sorry, #{message.user.nick}, you're already in the sync. "\
            'Just wait for it to kick off automatically, or type "go" '\
            'or "sync" to kick it off yourself when you\'re ready.'
          else
            @ongoing_syncs[message.channel].syncers << message.user.nick

            "#{message.user.nick}, you've been added to the sync! "\
            'Just wait for ohers to join, or type "go" or "sync" to '\
            'kick off the sync when you\'re ready.'
          end
        end
        message.reply reply
      end

      def go(message, *args)
        rip(message.channel)
      end

      private

      def rip(channel)
        synchronize(channel) do
          if @ongoing_syncs.has_key?(channel)
            participants = @ongoing_syncs[channel].syncers.uniq.join(', ')
            @ongoing_syncs.delete(channel)

            announce = "Hey, #{participants}, it's time to sync in five seconds!"

            Channel(channel).send announce
            sleep 5

            Channel(channel).send '3'
            sleep 1.5

            Channel(channel).send '2'
            sleep 1.5

            Channel(channel).send '1'
            sleep 1.5

            Channel(channel).send 'RIP IT'
          end
        end
      end
    end
  end
end
