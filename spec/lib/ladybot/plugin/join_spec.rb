# frozen_string_literal: true

describe Ladybot::Plugin::Join do
  include_context 'plugin context'

  context 'join command' do
    let(:message) do
      Cinch::Message.new(":#{nick}!user@duckberg.org PRIVMSG #{channel} :#{bot.nick}: join #channel", bot)
    end

    before do
      # allows message parsing
      allow(bot).to receive_message_chain('irc.network') { Cinch::Network.new(:unknown, :unknown) }
      allow(bot).to receive_message_chain('irc.isupport') { Cinch::ISupport.new }
    end

    it 'matches a message telling the bot to leave' do
      expect(described_class.matchers)
        .to include(have_attributes(pattern: /join\s+([&#+!][\S]{1,50})/i))
    end

    it 'registers and retrieves the appropriate handler for jointing' do
      subject do
        expect(bot.handlers.find(:message, message)).to include(a_kind_of(Cinch::Handler))
        expect(bot.handlers.find(:message, message).first).to satisfy do |handler|
          expect(handler.pattern.pattern).to eq(/join\s+([&#+!][\S]{1,50})/i)
        end
      end
    end

    it 'joins' do
      expect(bot).to receive(:join).with('#channel')
      subject.execute(message, '#channel')
    end
  end
end

