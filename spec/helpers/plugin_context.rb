# frozen_string_literal: true

shared_context 'plugin context', shared_context: :metadata do
  let(:nick) { 'scrooge' }
  let(:channel) { '#duckberg' }
  let(:channel_helper_response) { Cinch::Channel.new(channel, bot) }
  let(:args) { [] }
  let(:bot) do
    Cinch::Bot.new do
      configure do |c|
        c.server   = 'localhost'
        c.nick     = 'ladytest'
        c.user     = 'ladytest'
        c.channels = ['#duckberg']
      end
    end
  end

  subject { described_class.new(bot) }

  before do
    # turn off logging
    bot.loggers.level = :fatal

    # allows message parsing
    allow(bot).to receive_message_chain('irc.network') { Cinch::Network.new(:unknown, :unknown) }
    allow(bot).to receive_message_chain('irc.isupport') { Cinch::ISupport.new }

    # allow Target#notice, Channel#send
    allow(bot).to receive(:mask).and_return(Cinch::Mask.new("#{nick}!mcduck?@duckberg.gov"))
    allow(bot).to receive_message_chain('irc.send')
    allow(subject).to receive(:Channel).and_return(channel_helper_response)
    allow(channel_helper_response).to receive(:send)

    # allow sleep to return instantly
    allow(subject).to receive(:sleep).and_return(nil)
  end
end
