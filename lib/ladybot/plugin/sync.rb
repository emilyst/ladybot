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

      match(/(sync )?(regular|add)( me)?/, use_prefix: true,  method: :add_regular)
      match(/(sync )?(remove)( me)?/,      use_prefix: true,  method: :remove_regular)
      match(/^sync/,                       use_prefix: false, method: :sync)
      match(/^r(ea)?dy$/,                  use_prefix: false, method: :rdy)
      match(/^go/,                         use_prefix: false, method: :go)

      def add_regular(message, *args)
        channel = message.channel.name
        nick = message.user.nick

        reply = synchronize(channel) do
          if @regulars.has_key?(channel) && @regulars[channel].include?(nick)
            <<~REPLY
              #{nick}, you're already a regular. You'll be notified
              whenever someone starts a new sync.If you don't want this
              to happen anymore, tell me so by saying, "#{bot.nick}:
              sync remove me".
            REPLY
          else
            @regulars[channel] = [] unless @regulars.has_key?(channel)
            @regulars[channel].push(nick)

            <<~REPLY
              #{nick}, you've been added to this channel's regular sync
              participants! You'll be notified whenever someone starts
              a new sync. If you don't want this to happen anymore, tell
              me so by saying, "#{bot.nick}: sync remove me".
            REPLY
          end
        end.gsub(/\n(?!$)/m, ' ')

        message.reply reply
      end

      def remove_regular(message, *args)
        channel = message.channel.name
        nick = message.user.nick

        reply = synchronize(channel) do
          if @regulars.has_key?(channel) && @regulars[channel].include?(nick)
            @regulars[channel].delete(nick)

            <<~REPLY
              #{nick}, you've been removed from this channel's regular
              sync participants!
            REPLY
          else
            <<~REPLY
              #{nick}, you weren't a regular in the first place. You can
              always add yourself as a regular by saying, "#{bot.nick}:
              sync add me"
            REPLY
          end
        end.gsub(/\n(?!$)/m, ' ')

        message.reply reply
      end

      def notify_regulars(channel, nick)
        synchronize(channel) do
          regulars = @regulars[channel]

          unless regulars.nil?
            recipients = regulars.uniq.reject { |r| r == nick }

            unless recipients.empty?
              announce = <<~ANNOUNCE
              Hey, #{recipients.join(', ')}, a new sync just started.
              Get ready. I'll notify you again at the countdown.
              ANNOUNCE

              Channel(channel).send announce.gsub(/\n(?!$)/m, ' ')
            end
          end
        end
      end

      def sync(message, *args)
        channel = message.channel.name
        nick = message.user.nick

        reply = synchronize(channel) do
          @regulars[channel]      = [] unless @regulars.has_key?(channel)
          @ongoing_syncs[channel] = {} unless @ongoing_syncs.has_key?(channel)

          from_regular            = @regulars[channel].include?(nick)
          from_participant        = if @ongoing_syncs[channel].empty?
                                      false
                                    else
                                      @ongoing_syncs[channel][:participants].include?(nick)
                                    end

          if @ongoing_syncs[channel].empty?
            @ongoing_syncs[channel][:participants] = [nick]

            # schedule a sync five minutes out
            @ongoing_syncs[channel][:timers] =
              [Timer(5 * 60, shots: 1) { countdown(channel) }]

            # notify regulars of the new sync
            unless @regulars[channel].empty?
              @ongoing_syncs[channel][:timers]
                .push(Timer(0.5, shots: 1) { notify_regulars(channel, nick) })
            end

            <<~REPLY
              #{nick} has started a sync! Type "rdy" to join the sync! I
              will notify participants in five minutes, or type "sync"
              again or "go" when you're ready.
            REPLY
          elsif !(from_participant || from_regular)
            <<~REPLY
              #{nick}, there's already a sync going on. Join in on that
              one by saying "rdy".
            REPLY
          else
            # kick off the countdown in another (instant) timer so that
            # I can borrow its thread group to make a new thread outside
            # of this one, where mutex sync won't be an issue
            @ongoing_syncs[channel][:timers]
              .push(Timer(0.5, shots: 1) { countdown(channel) })

            ''  # no reply, everyone's about to get notified anyway
          end
        end.gsub(/\n(?!$)/m, ' ')

        message.reply reply unless reply.empty?
      end

      def rdy(message, *args)
        channel = message.channel.name
        nick = message.user.nick

        reply = synchronize(channel) do
          @regulars[channel]      = [] unless @regulars.has_key?(channel)
          @ongoing_syncs[channel] = {} unless @ongoing_syncs.has_key?(channel)

          from_regular            = @regulars[channel].include?(nick)
          from_participant        = if @ongoing_syncs[channel].empty?
                                      false
                                    else
                                      @ongoing_syncs[channel][:participants].include?(nick)
                                    end

          if @ongoing_syncs[channel].empty?
            <<~REPLY
              Sorry, #{nick}, there's no sync going. Type "sync" to
              start one off! Want to be notified of all syncs? Add
              yourself as a regular by saying, "#{bot.nick}: sync
              add me".
            REPLY
          elsif (from_participant || from_regular)
            <<~REPLY
              Sorry, #{nick}, you're already in the sync. Just wait for
              it to kick off automatically, or type "go" or "sync" to
              kick it off yourself.
            REPLY
          else
            @ongoing_syncs[channel][:participants].push(nick)

            <<~REPLY
              #{nick}, you've been added to the sync! Wait for others to
              join, or type "go" or "sync" to kick off the sync when
              you're ready.
            REPLY
          end
        end.gsub(/\n(?!$)/m, ' ')

        message.reply reply
      end

      def go(message, *args)
        channel = message.channel.name

        synchronize(channel) do
          @regulars[channel]      = [] unless @regulars.has_key?(channel)
          @ongoing_syncs[channel] = {} unless @ongoing_syncs.has_key?(channel)
        end

        # reuse the logic from sync method, without synchronizing
        # because it would nest synchronize scopes and because the other
        # method will synchronize anyway
        sync(message, args) unless @ongoing_syncs[channel].empty?
      end

      def countdown(channel)
        synchronize(channel) do
          @regulars[channel]      = [] unless @regulars.has_key?(channel)
          @ongoing_syncs[channel] = {} unless @ongoing_syncs.has_key?(channel)

          unless @ongoing_syncs[channel].empty?
            timers       = @ongoing_syncs[channel][:timers]
            regulars     = @regulars[channel]
            participants = @ongoing_syncs[channel][:participants]

            @ongoing_syncs[channel] = {}

            announce = <<~ANNOUNCE
              Hey, #{(participants + regulars).uniq.join(', ')}, it's
              time to sync in five seconds! Ready?
            ANNOUNCE

            Channel(channel).send announce.gsub(/\n(?!$)/m, ' '); sleep 5
            Channel(channel).send '3';                            sleep 1.5
            Channel(channel).send '2';                            sleep 1.5
            Channel(channel).send '1';                            sleep 1.5

            Channel(channel).send CALLS_TO_ACTION.sample

            # do this last (this kills the threads)
            timers.each { |t| t.stop if t.started? }
          end
        end
      end
    end
  end
end
