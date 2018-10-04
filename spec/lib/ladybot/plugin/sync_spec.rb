# frozen_string_literal: true

describe Ladybot::Plugin::Sync do
  include_context 'plugin context'

  context 'sync command' do
    let(:message) { Cinch::Message.new(":#{nick}!user@duckberg.org PRIVMSG #{channel} :sync", bot) }

    before do
      # allow message parsing
      allow(bot).to receive_message_chain('irc.network') { Cinch::Network.new(:unknown, :unknown) }
      allow(bot).to receive_message_chain('irc.isupport') { Cinch::ISupport.new }
      allow(bot).to receive_message_chain('irc.send') {  }

      # avoid the default implementation
      allow(message).to receive(:reply)
    end

    it 'matches a message starting with "sync" followed by whatever' do
      expect(described_class.matchers)
        .to include(have_attributes(pattern: /^sync/, method: :sync))
    end

    it 'registers and retrieves the appropriate handler for "sync"' do
      subject do
        expect(bot.handlers.find(:message, message)).to include(a_kind_of(Cinch::Handler))
        expect(bot.handlers.find(:message, message).first).to satisfy do |handler|
          expect(handler.pattern.pattern).to eq(/^sync/)
        end
      end
    end

    context 'when called once' do
      it 'sends announcement and sets up five-minute timer' do
        expect(message).to receive(:reply).with(/#{nick} has started a sync/)
        expect(subject).to receive(:Timer).with(5 * 60, shots: 1).and_call_original

        subject.sync(message, [])

        expect(subject.timers).to include(a_kind_of(Cinch::Timer))
      end

      it 'creates an ongoing sync' do
        subject.sync(message, [])

        expect(subject.ongoing_syncs).to include(channel => {
          participants: [nick],
          timers: [a_kind_of(Cinch::Timer)]
        })
      end
    end

    context 'when called again' do
      before { subject.sync(message, []) }  # the first call to begin the sync

      context 'by a participant' do
        it 'does not send sync announcement' do
          expect(message).not_to receive(:reply)
          subject.sync(message, [])
        end

        it 'sets up a second, instant timer on the second call' do
          expect(subject).to receive(:Timer).with(0, shots: 1).and_call_original

          subject.sync(message, [])

          # the timers exist...
          expect(subject.ongoing_syncs).to include({
            channel => hash_including(timers: [a_kind_of(Cinch::Timer),
                                               a_kind_of(Cinch::Timer)])
          })

          # ...and one is instant
          expect(subject.ongoing_syncs).to include({
            channel => hash_including(timers: [have_attributes(interval: 300),
                                               have_attributes(interval: 0)])
          })
        end

        it 'does not change the ongoing sync participants' do
          expect(subject).to receive(:Timer).and_call_original

          subject.ongoing_syncs[channel][:participants] << 'should_not_disappear'

          subject.sync(message, [])

          expect(subject.ongoing_syncs).to include({
            channel => hash_including(participants: [nick, 'should_not_disappear'])
          })
        end
      end

      context 'by a non-participant' do
        let(:huey) { 'huey' }
        let(:non_participant_message) do
          Cinch::Message.new(":#{huey}!#{huey}@duckberg.org PRIVMSG #{channel} :sync", bot)
        end

        before do
          allow(non_participant_message).to receive(:reply)
        end

        it 'does not send sync announcement' do
          expect(non_participant_message).not_to receive(:reply)
          subject.sync(message, [])
        end

        it 'does not set up a second, instant timer on the second call' do
          expect(subject).not_to receive(:Timer).with(0, shots: 1)

          subject.sync(non_participant_message, [])

          # only one timer exists...
          expect(subject.ongoing_syncs).to include({
            channel => hash_including(timers: [a_kind_of(Cinch::Timer)])
          })

          # ...and it is not instant
          expect(subject.ongoing_syncs).to include({
            channel => hash_including(timers: [have_attributes(interval: 300)])
          })
        end

        it 'does not change the ongoing sync participants' do
          subject.sync(non_participant_message, [])
          expect(subject.ongoing_syncs).to include({
            channel => hash_including(participants: [nick])
          })
        end

        it 'warns the non-participant they cannot start the sync' do
          expect(non_participant_message)
            .to receive(:reply)
            .with(/#{huey}, there's already a sync going on/)
          subject.sync(non_participant_message, [])
        end
      end
    end
  end

  context 'rdy command' do
    let(:message) { Cinch::Message.new(":#{nick}!#{nick}@duckberg.org PRIVMSG #{channel} :rdy", bot) }
    let(:ready_message) { Cinch::Message.new(":#{nick}!#{nick}@duckberg.org PRIVMSG #{channel} :ready", bot) }

    before do
      # allow message parsing
      allow(bot).to receive_message_chain('irc.network') { Cinch::Network.new(:unknown, :unknown) }
      allow(bot).to receive_message_chain('irc.isupport') { Cinch::ISupport.new }

      # avoid the default implementation
      allow(message).to receive(:reply)
    end

    it 'matches a message starting with "rdy" followed by whatever' do
      expect(described_class.matchers).to include(have_attributes(pattern: /^r(ea)?dy/, method: :rdy))
    end

    it 'registers and retrieves the appropriate handler for "rdy"' do
      subject do
        expect(bot.handlers.find(:message, message)).to include(a_kind_of(Cinch::Handler))
        expect(bot.handlers.find(:message, message).first).to satisfy do |handler|
          expect(handler.pattern.pattern).to eq(/^rdy/)
        end
      end
    end

    it 'retrieves the appropriate handler for "ready"' do
      subject do
        expect(bot.handlers.find(:message, ready_message)).to include(a_kind_of(Cinch::Handler))
        expect(bot.handlers.find(:message, ready_message).first).to satisfy do |handler|
          expect(handler.pattern.pattern).to eq(/^r(ea)?dy/)
        end
      end
    end

    context 'with no ongoing sync for the current channel' do
      it 'prompts to begin a sync' do
        expect(message).to receive(:reply).with(/Sorry, #{nick}, there's no sync/)
        subject.rdy(message, [])
      end

      it 'does not create an ongoing sync' do
        subject.rdy(message, [])
        expect(subject.ongoing_syncs).to be_empty
      end
    end

    context 'with an ongoing sync for the current channel' do
      before { subject.ongoing_syncs[channel] = { participants: [nick] } }

      context 'from the user who began the sync' do
        it 'warns the user' do
          expect(message).to receive(:reply)
            .with(/Sorry, #{nick}, you're already in the sync/)
          subject.rdy(message, [])
        end
      end

      context 'from another user in the channel' do
        let(:huey) { 'huey' }
        let(:message) { Cinch::Message.new(":#{huey}!#{huey}@duckberg.org PRIVMSG #{channel} :rdy", bot) }

        it 'adds the user to the sync' do
          subject.rdy(message, [])
          expect(subject.ongoing_syncs).to include(channel => { participants: [nick, 'huey'] })
        end

        it 'tells the user they are in the sync' do
          expect(message).to receive(:reply)
            .with(/#{huey}, you've been added to the sync/)
          subject.rdy(message, [])
        end
      end
    end

    context 'with an ongoing sync for another channel' do
      before do
        subject.ongoing_syncs['#another_channel'] = {
          participants: [nick],
          timers: [Cinch::Timer.new(bot, {}) {}]
        }
      end

      it 'prompts to begin a sync' do
        expect(message).to receive(:reply).with(/Sorry, #{nick}, there's no sync/)
        subject.ongoing_syncs['#another_channel'] = [nick]
        subject.rdy(message, [])
      end

      it 'does not create an ongoing sync in that channel' do
        subject.rdy(message, [])
        expect(subject.ongoing_syncs).not_to include(channel)
      end
    end
  end

  context '#countdown' do
    context 'with no ongoing sync for the current channel' do
      it 'does nothing' do
        expect(subject).not_to receive(:Channel)
        expect(subject.countdown(channel)).to be(nil)
      end
    end

    context 'with an ongoing sync for the current channel' do
      let(:channel_helper) { Cinch::Channel.new(channel, bot) }

      before do
        # allow Channel#send
        allow(subject).to receive(:Channel).and_return(channel_helper)
        allow(bot).to receive_message_chain('irc.send')
        allow(bot).to receive(:mask).and_return(Cinch::Mask.new('huey!dewey?@louie'))
        allow(channel_helper).to receive(:send)

        # allow sleep to return instantly
        allow(subject).to receive(:sleep).and_return(nil)
      end

      context 'when the timer has expired' do
        let(:timer) { Cinch::Timer.new(bot, {interval: 300, shots: 1}) {} }

        before do
          # add other participants to the sync
          subject.ongoing_syncs[channel] = {
            participants: [nick, 'huey', 'dewey', 'louie'],
            timers: [timer]
          }
        end

        it 'removes the ongoing sync' do
          subject.countdown(channel)
          expect(subject.ongoing_syncs).to be_empty
        end

        it 'stops the timer' do
          expect(timer.stopped?).to be(true)
        end

        it 'announces the countdown to all participants' do
          expect(channel_helper).to receive(:send)
            .with(/Hey, #{nick}, huey, dewey, louie, it's time to sync/)

          subject.countdown(channel)
        end
      end

      context 'when the timer was preempted' do
        let(:original_timer) { Cinch::Timer.new(bot, {interval: 300, shots: 1}) {} }
        let(:short_circuit_timer) { Cinch::Timer.new(bot, {interval: 0, shots: 1}) {} }

        before do
          # simulate an early sync
          subject.ongoing_syncs[channel] = {
            participants: [nick],
            timers: [original_timer, short_circuit_timer]
          }
        end

        it 'removes the ongoing sync' do
          subject.countdown(channel)
          expect(subject.ongoing_syncs).to be_empty
        end

        it 'stops the original timer' do
          expect(original_timer.stopped?).to be(true)
        end

        it 'stops the new short circuit timer' do
          expect(short_circuit_timer.stopped?).to be(true)
        end

        it 'announces the countdown to all participants' do
          expect(channel_helper).to receive(:send)
            .with(/Hey, #{nick}, it's time to sync/)

          subject.countdown(channel)
        end
      end
    end

    context 'with an ongoing sync for another channel' do
      before { subject.ongoing_syncs['#another_channel'] = [nick] }

      it 'does nothing' do
        expect(subject).not_to receive(:Channel)
        expect(subject.countdown(channel)).to be(nil)
      end
    end
  end
end
