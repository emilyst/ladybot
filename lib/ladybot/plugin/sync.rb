# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Sync
      include Cinch::Plugin

      CALLS_TO_ACTION = ["BLAST OFF",
                         "DYN-O-MITE!",
                         "ENGAGE",
                         "GO",
                         "GOGOGOGO",
                         "GOGOGOGOGO",
                         "GOGOGOGOGOGO",
                         "GOOOO",
                         "GOOOOOOO",
                         "GOOOOOOOOOOOOO",
                         "GOOOOOOOOOOOOOOOOOOOOOO",
                         "HIDDIT",
                         "HIT IT",
                         "IT'S MORPHIN' TIME",
                         "MAKE IT SO",
                         "RIP IT",
                         "YABBA DABBA DOO!",
                         "BANG, ZOOM, TO THE MOON, ALICE!"].freeze

      attr_reader :ongoing_syncs

      def initialize(bot)
        super(bot)
        @ongoing_syncs = {}
      end

      match(/^sync/, use_prefix: false, method: :sync)
      match(/^rdy/,  use_prefix: false, method: :rdy)
      match(/^go/,   use_prefix: false, method: :go)

      def sync(message, *args)
        synchronize(message.channel.name) do
          if !@ongoing_syncs.has_key?(message.channel.name)
            @ongoing_syncs[message.channel.name] = [message.user.nick]

            # schedule a sync five minutes out
            Timer(5 * 60, shots: 1) { countdown(message.channel.name) }

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
            Timer(0, shots: 1) { countdown(message.channel.name) }
          end
        end
      end

      def rdy(message, *args)
        reply = synchronize(message.channel) do
          if !@ongoing_syncs.has_key?(message.channel.name)
            "Sorry, #{message.user.nick}, there's no sync going. Type "\
            '"sync" to start one off!'
          elsif @ongoing_syncs.has_key?(message.channel.name) &&
                @ongoing_syncs[message.channel.name].include?(message.user.nick)
            "Sorry, #{message.user.nick}, you're already in the sync. "\
            'Just wait for it to kick off automatically, or type "go" '\
            'or "sync" to kick it off yourself when you\'re ready.'
          else
            @ongoing_syncs[message.channel.name] << message.user.nick

            "#{message.user.nick}, you've been added to the sync! "\
            'Just wait for others to join, or type "go" or "sync" to '\
            'kick off the sync when you\'re ready.'
          end
        end
        message.reply reply
      end

      def go(message, *args)
        countdown(message.channel.name)
      end

      def countdown(channel)
        synchronize(channel) do
          if @ongoing_syncs.has_key?(channel)
            participants = @ongoing_syncs[channel].uniq.join(', ')

            # deletes an existing ongoing sync so that we can begin
            # a new one after
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

            Channel(channel).send CALLS_TO_ACTION.sample
          end
        end
      end
    end
  end
end
