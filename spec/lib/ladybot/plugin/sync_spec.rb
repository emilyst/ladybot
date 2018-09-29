describe Ladybot::Plugin::Sync do
  let(:nick)    { 'Scrooge' }
  let(:bot)     { Cinch::Bot.new }
  let(:message) { Cinch::Message.new(":#{nick}!user@example.org PRIVMSG #channel :sync", bot) }

  before do
    # allows message parsing
    allow(bot).to receive_message_chain('irc.network') { Cinch::Network.new(:unknown, :unknown) }
    allow(bot).to receive_message_chain('irc.isupport') { Cinch::ISupport.new }
  end

  context 'sync command' do
    it 'matches a message starting with "sync" followed by whatever' do
      expect(described_class.matchers.first).to have_attributes(pattern: /^sync/, method: :sync)
    end

    it 'registers and retrieves the appropriate handler for "sync"' do
      plugin = described_class.new(bot)
      expect(bot.handlers.find(:message, message)).to include(a_kind_of(Cinch::Handler))
      expect(bot.handlers.find(:message, message).first).to satisfy do |handler|
        expect(handler.pattern.pattern).to eq(/^sync/)
      end
    end

    it 'sends sync announcement in response' do
      expect(message).to receive(:reply).with(/#{nick} has started a sync!/)
      described_class.new(bot).sync(message, [])
    end
  end
end
