# frozen_string_literal: true

require 'cinch'

module Ladybot
  module Plugin
    class Sync
      include Cinch::Plugin

      CALLS_TO_ACTION = [
        "BANG, ZOOM, TO THE MOON, ALICE!",
        "BLAST OFF",
        "BRING IT ON HOME",
        "DOHOHO",
        "DYN-O-MITE!",
        "ENGAGE",
        "EPIC WIN",
        "GO",
        "GOGOGOGO",
        "GOGOGOGOGOGO",
        "GOOOO",
        "GOOOOOOO",
        "GOOOOOOOOOOOOO",
        "HIDDIT",
        "HIT IT",
        "IT'S MORPHIN' TIME",
        "MAKE IT SO",
        "METAL GEAR?!?!",
        "RIP IT",
        "SWEET SASSY MOLASSY",
        "YABBA DABBA DOO!",
      ].freeze

      attr_reader :ongoing_syncs, :regulars

      def initialize(bot)
        super(bot)
        @ongoing_syncs = {}
        @regulars = {}
      end

      match(/^sync/,      use_prefix: false, method: :sync)
      match(/^r(ea)?dy/,  use_prefix: false, method: :rdy)
      match(/^go/,        use_prefix: false, method: :go)

      def sync(message, *args)
        channel = message.channel.name
        nick = message.user.nick

        reply = synchronize(channel) do
          if !@ongoing_syncs.has_key?(channel)
            @ongoing_syncs[channel] = {}
            @ongoing_syncs[channel][:participants] = [nick]

            # schedule a sync five minutes out
            @ongoing_syncs[channel][:timers] =
              [Timer(5 * 60, shots: 1) { countdown(channel) }]

            <<~REPLY
              #{nick} has started a sync! Type "rdy" to join the sync! I
              will notify everyone in the sync when it begins. The sync
              will begin automatically in five minutes. To kick it off
              yourself, type "sync" again or "go" when you're ready.
            REPLY

          elsif @ongoing_syncs.has_key?(channel) &&
                !@ongoing_syncs[channel][:participants].include?(nick)
            <<~REPLY
              #{nick}, there's already a sync going on. Join in on that
              one by saying "rdy".
            REPLY
          else
            # if a sync is already ongoing, stop its timer, throw it
            # away, and kick off the countdown in another (instant)
            # timer so that I can borrow its thread group to make a new
            # thread outside of this one, where mutex sync won't be an
            # issue
            @ongoing_syncs[channel][:timers].push(Timer(0, shots: 1) { countdown(channel) })

            <<~REPLY
              #{nick}, you've kicked off the sync early!
            REPLY
          end
        end.gsub(/\n/m, ' ').strip

        message.reply reply
      end

      def rdy(message, *args)
        channel = message.channel.name
        nick = message.user.nick

        reply = synchronize(channel) do
          if !@ongoing_syncs.has_key?(channel)
            <<~REPLY
              Sorry, #{nick}, there's no sync going. Type "sync" to
              start one off!
            REPLY
          elsif @ongoing_syncs.has_key?(channel) &&
                @ongoing_syncs[channel][:participants].include?(nick)
            <<~REPLY
              Sorry, #{nick}, you're already in the sync. Just wait for
              it to kick off automatically, or type "go" or sync to kick
              it off yourself when you're ready.
            REPLY
          else
            @ongoing_syncs[channel][:participants].push(nick)

            <<~REPLY
              #{nick}, you've been added to the sync! Just wait for
              others to join, or type "go" or "sync" to kick off the
              sync when you're ready.
            REPLY
          end
        end.gsub(/\n/m, ' ').strip

        message.reply reply
      end

      def go(message, *args)
        # reuse the logic from sync method, without synchronizing
        # because it would nest synchronize scopes and because the other
        # method will synchronize anyway
        sync(message, args) if @ongoing_syncs.has_key?(channel)
      end

      def countdown(channel)
        synchronize(channel) do
          if @ongoing_syncs.has_key?(channel)
            channel_sync = @ongoing_syncs[channel]

            timers = channel_sync[:timers]
            regulars = @regulars.has_key?(channel) ? @regulars[channel] : []
            participants = channel_sync[:participants]

            @ongoing_syncs.delete(channel)

            announce = <<~ANNOUNCE
              Hey, #{(participants + regulars).uniq.join(', ')}, it's
              time to sync in five seconds! Ready?
            ANNOUNCE

            Channel(channel).send announce.gsub(/\n/m, ' ').strip; sleep 5
            Channel(channel).send '3';                             sleep 1.5
            Channel(channel).send '2';                             sleep 1.5
            Channel(channel).send '1';                             sleep 1.5

            Channel(channel).send CALLS_TO_ACTION.sample

            # do this last (this kills the threads)
            timers.each { |t| t.stop if t.started? }
          end
        end
      end
    end
  end
end
