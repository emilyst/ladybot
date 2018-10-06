# frozen_string_literal: true

describe Ladybot::Plugin::Version do
  include_context 'plugin context'

  context 'CTCP version' do
    context 'when the CTCP is a NOTICE' do
      let(:message) do
        Cinch::Message.new(":#{nick}!user@duckberg.org NOTICE #{bot.nick} :\u0001VERSION\u0001", bot)
      end

      it 'matches CTCP version request' do
        expect(described_class.matchers)
          .to include(have_attributes(pattern: /^version/i))
      end

      it 'registers and retrieves the appropriate handler for the CTCP' do
        subject do
          expect(bot.handlers.find(:message, message)).to eq([a_kind_of(Cinch::Handler)])
          expect(bot.handlers.find(:message, message).first).to satisfy do |handler|
            expect(handler.pattern.pattern).to eq(/^version/i)
          end
        end
      end

      it 'replies with the version' do
        expect(message.user)
          .to receive(:notice)
          .with("\u0001VERSION Ladybot version #{Ladybot::VERSION}\u0001")
        subject.execute(message, args)
      end
    end

    context 'when the CTCP is a PRIVMSG' do
      let(:message) do
        Cinch::Message.new(":#{nick}!user@duckberg.org PRIVMSG #{bot.nick} :\u0001VERSION\u0001", bot)
      end

      it 'matches CTCP version request' do
        expect(described_class.matchers)
          .to include(have_attributes(pattern: /^version/i))
      end

      it 'registers and retrieves the appropriate handler for the CTCP' do
        subject do
          expect(bot.handlers.find(:message, message)).to eq([a_kind_of(Cinch::Handler)])
          expect(bot.handlers.find(:message, message).first).to satisfy do |handler|
            expect(handler.pattern.pattern).to eq(/^version/i)
          end
        end
      end

      it 'replies with the version' do
        expect(message.user)
          .to receive(:notice)
          .with("\u0001VERSION Ladybot version #{Ladybot::VERSION}\u0001")
        subject.execute(message, args)
      end
    end
  end
end
