# frozen_string_literal: true

describe Ladybot::Plugin::Part do
  include_context 'plugin context'

  context 'part command' do
    let(:message) do
      Cinch::Message.new(":#{nick}!user@duckberg.org PRIVMSG #{channel} :#{bot.nick}: part", bot)
    end

    before do
      # allows message parsing
      allow(bot).to receive_message_chain('irc.network') { Cinch::Network.new(:unknown, :unknown) }
      allow(bot).to receive_message_chain('irc.isupport') { Cinch::ISupport.new }
    end

    it 'matches a message telling the bot to leave' do
      expect(described_class.matchers)
        .to include(have_attributes(pattern: /(#{described_class::EXPRESSIONS.join('|')})/i))
    end

    it 'registers and retrieves the appropriate handler for partting' do
      subject do
        expect(bot.handlers.find(:message, message)).to include(a_kind_of(Cinch::Handler))
        expect(bot.handlers.find(:message, message).first).to satisfy do |handler|
          expect(handler.pattern.pattern).to eq(/(#{described_class::EXPRESSIONS.join('|')})/i)
        end
      end
    end

    it 'parts' do
      expect(bot).to receive(:part).with(channel, a_kind_of(String))
      subject.execute(message, [])
    end
  end
end

