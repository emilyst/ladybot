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

      match(/^sync/,      use_prefix: false, method: :sync)
      match(/^r(ea)?dy/,  use_prefix: false, method: :rdy)
      match(/^go/,        use_prefix: false, method: :go)

      def sync(message, *args)
        channel = message.channel.name
        nick = message.user.nick

        synchronize(channel) do
          if !@ongoing_syncs.has_key?(channel)
            @ongoing_syncs[channel] = {}
            @ongoing_syncs[channel][:participants] = [nick]

            # schedule a sync five minutes out
            @ongoing_syncs[channel][:timers] =
              [Timer(5 * 60, shots: 1) { countdown(channel) }]

            reply = "#{nick} has started a sync! Type \"rdy\" to join "\
                    'the sync! I will notify everyone in the sync '\
                    'when it begins. The sync will begin '\
                    'automatically in five minutes. To kick it off '\
                    'yourself, type "sync" again or "go" when '\
                    'you\'re ready.'

            message.reply reply
          elsif @ongoing_syncs.has_key?(channel) &&
                !@ongoing_syncs[channel][:participants].include?(nick)
            warning = "#{nick}, there's already a sync going on. Join "\
              'in on that one by saying "rdy".'
            message.reply warning
          else
            # if a sync is already ongoing, stop its timer, throw it
            # away, and kick off the countdown in another (instant)
            # timer so that I can borrow its thread group to make a new
            # thread outside of this one, where mutex sync won't be an
            # issue
            @ongoing_syncs[channel][:timers] <<
              Timer(0, shots: 1) { countdown(channel) }
          end
        end
      end

      def rdy(message, *args)
        channel = message.channel.name
        nick = message.user.nick

        reply = synchronize(channel) do
          if !@ongoing_syncs.has_key?(channel)
            "Sorry, #{nick}, there's no sync going. Type \"sync\" to "\
            'start one off!'
          elsif @ongoing_syncs.has_key?(channel) &&
                @ongoing_syncs[channel][:participants].include?(nick)
            "Sorry, #{nick}, you're already in the sync. Just wait "\
            'for it to kick off automatically, or type "go" or sync '\
            'to kick it off yourself when you\'re ready.'
          else
            @ongoing_syncs[channel][:participants] << nick

            "#{nick}, you've been added to the sync! Just wait for "\
            'others to join, or type "go" or "sync" to kick off the '\
            'the sync when you\'re ready.'
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
            og = @ongoing_syncs[channel]

            participants = og[:participants].uniq.join(', ')
            timers = og[:timers]

            @ongoing_syncs.delete(channel)

            announce = "Hey, #{participants}, it's time to sync in five seconds!"

            Channel(channel).send announce; sleep 5
            Channel(channel).send '3';      sleep 1.5
            Channel(channel).send '2';      sleep 1.5
            Channel(channel).send '1';      sleep 1.5

            Channel(channel).send CALLS_TO_ACTION.sample

            # do this last (this kills the threads)
            timers.each { |t| t.stop if t.started? }
          end
        end
      end
    end
  end
end
