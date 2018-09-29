# frozen_string_literal: true

describe Ladybot::Plugin::Sync do
  let(:nick)    { 'scrooge' }
  let(:channel) { '#duckberg' }
  let(:bot)     { Cinch::Bot.new }

  subject { described_class.new(bot) }

  before { bot.loggers.level = :fatal }

  context 'sync command' do
    let(:message) { Cinch::Message.new(":#{nick}!user@duckberg.org PRIVMSG #{channel} :sync", bot) }

    before do
      # allows message parsing
      allow(bot).to receive_message_chain('irc.network') { Cinch::Network.new(:unknown, :unknown) }
      allow(bot).to receive_message_chain('irc.isupport') { Cinch::ISupport.new }

      # allow these methods to call and avoid the default implementation
      allow(message).to receive(:reply)
      allow(subject).to receive(:Timer)
    end

    it 'matches a message starting with "sync" followed by whatever' do
      expect(described_class.matchers).to include(have_attributes(pattern: /^sync/, method: :sync))
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
        expect(message).to receive(:reply).with(/#{nick} has started a sync!/)
        expect(subject).to receive(:Timer).with(5 * 60, shots: 1)
        subject.sync(message, [])
      end

      it 'creates an ongoing sync' do
        subject.sync(message, [])
        expect(subject.ongoing_syncs).to include(channel => ['scrooge'])
      end
    end

    context 'when called twice' do
      it 'does not send announcement and sets up instant timer on the second call' do
        subject.sync(message, [])
        expect(message).not_to receive(:reply)
        expect(subject).to receive(:Timer).with(0, shots: 1)
        subject.sync(message, [])
      end

      it 'does not replace the ongoing sync' do
        expect(subject).to receive(:Timer).twice
        subject.sync(message, [])
        subject.ongoing_syncs[channel] << 'should_not_disappear'
        subject.sync(message, [])
        expect(subject.ongoing_syncs).to include(channel => ['scrooge', 'should_not_disappear'])
      end
    end
  end

  context 'rdy command' do
    let(:message) { Cinch::Message.new(":#{nick}!#{nick}@duckberg.org PRIVMSG #{channel} :rdy", bot) }

    before do
      # allows message parsing
      allow(bot).to receive_message_chain('irc.network') { Cinch::Network.new(:unknown, :unknown) }
      allow(bot).to receive_message_chain('irc.isupport') { Cinch::ISupport.new }

      # allow these methods to call and avoid the default implementation
      allow(message).to receive(:reply)
      allow(subject).to receive(:Timer)
    end

    it 'matches a message starting with "rdy" followed by whatever' do
      expect(described_class.matchers).to include(have_attributes(pattern: /^rdy/, method: :rdy))
    end

    it 'registers and retrieves the appropriate handler for "rdy"' do
      subject do
        expect(bot.handlers.find(:message, message)).to include(a_kind_of(Cinch::Handler))
        expect(bot.handlers.find(:message, message).first).to satisfy do |handler|
          expect(handler.pattern.pattern).to eq(/^rdy/)
        end
      end
    end

    context 'no ongoing sync for the current channel' do
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
      before { subject.ongoing_syncs[channel] = [nick] }

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
          expect(subject.ongoing_syncs).to include(channel => ['scrooge', 'huey'])
        end

        it 'tells the user they are in the sync' do
          expect(message).to receive(:reply)
            .with(/#{huey}, you've been added to the sync/)
          subject.rdy(message, [])
        end
      end
    end

    context 'with an ongoing sync for another channel' do
      before { subject.ongoing_syncs['#another_channel'] = [nick] }

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
    context 'no ongoing sync for the current channel' do
      it 'does nothing' do
        expect(subject).not_to receive(:Channel)
        expect(subject.countdown(channel)).to be(nil)
      end
    end

    context 'with an ongoing sync for the current channel' do
      let(:channel_helper) { Cinch::Channel.new(channel, bot) }

      before do
        # allows Channel#send
        allow(subject).to receive(:Channel).and_return(channel_helper)
        allow(bot).to receive_message_chain('irc.send')
        allow(bot).to receive(:mask).and_return(Cinch::Mask.new('huey!dewey?@louie'))
        allow(channel_helper).to receive(:send)

        allow(subject).to receive(:sleep).and_return(nil)

        subject.ongoing_syncs[channel] = [nick, 'huey', 'dewey', 'louie']
      end

      it 'removes the ongoing sync' do
        subject.countdown(channel)
        expect(subject.ongoing_syncs).to be_empty
      end

      it 'announces the countdown to all participants' do
        expect(channel_helper).to receive(:send)
          .with(/Hey, scrooge, huey, dewey, louie, it's time to sync/)
        subject.countdown(channel)
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
